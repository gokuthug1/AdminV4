--!strict
-- PipeServer.server.lua
-- Server controller for the Metal Pipe admin tool.
-- Features: Custom swing animations, iconic metal pipe clang sound, massive knockback force, and full ragdoll physics.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- Resolve actual Tool and auto-flatten if nested inside or underneath an intermediate Model
local actualTool: Tool
if script.Parent:IsA("Tool") then
	actualTool = script.Parent
elseif script.Parent:IsA("Model") and script.Parent.Parent and script.Parent.Parent:IsA("Tool") then
	actualTool = script.Parent.Parent :: Tool
	local innerModel = script.Parent
	for _, child in ipairs(innerModel:GetChildren()) do
		if child ~= script then
			child.Parent = actualTool
		end
	end
	script.Parent = actualTool
	task.defer(function()
		if innerModel.Parent then innerModel:Destroy() end
	end)
else
	actualTool = (script:FindFirstAncestorWhichIsA("Tool") or script.Parent) :: Tool
end

local tool = actualTool

-- Also unpack any child Model inside the Tool so Handle is a direct child of Tool
local nestedModel = tool:FindFirstChildWhichIsA("Model")
if nestedModel then
	for _, child in ipairs(nestedModel:GetChildren()) do
		child.Parent = tool
	end
	task.defer(function()
		if nestedModel.Parent then nestedModel:Destroy() end
	end)
end

-- Grip configuration for natural right-hand hold
tool.Grip = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(90), 0, 0)

-- Ensure Handle exists (creates fallback physical pipe if 3D model hasn't been generated yet)
local handle = tool:FindFirstChild("Handle") :: BasePart?
if not handle then
	handle = tool:WaitForChild("Handle", 2) :: BasePart?
end
if not handle then
	local newHandle = Instance.new("Part")
	newHandle.Name = "Handle"
	newHandle.Size = Vector3.new(0.45, 3.8, 0.45)
	newHandle.CFrame = CFrame.new(0, 0, 0)
	newHandle.Material = Enum.Material.Metal
	newHandle.Color = Color3.fromRGB(138, 144, 150)
	newHandle.CanCollide = false
	local cylMesh = Instance.new("CylinderMesh")
	cylMesh.Parent = newHandle
	newHandle.Parent = tool
	handle = newHandle
end

-- Ensure Sounds exist under Handle
local function ensureSound(parent: Instance, name: string, soundId: string, volume: number, pitch: number?): Sound
	local sound = parent:FindFirstChild(name) :: Sound?
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = soundId
		sound.Volume = volume
		sound.RollOffMaxDistance = 150
		if pitch then sound.PlaybackSpeed = pitch end
		sound.Parent = parent
	end
	return sound
end

local clangSound = ensureSound(handle, "ClangSound", "rbxassetid://9114223180", 1.8, 1.0)
local swingSound = ensureSound(handle, "SwingSound", "rbxassetid://169445121", 0.9, 0.95)

local isSwinging = false
local swingDebounce = false
local hitVictims: { [Model]: boolean } = {}

-- Ragdoll implementation supporting both R15 and R6
local function ragdollCharacter(victimChar: Model, duration: number)
	local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
	local root = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 then return end

	-- Prevent stacking ragdoll calls on the same character
	if victimChar:GetAttribute("IsRagdolled") then return end
	victimChar:SetAttribute("IsRagdolled", true)

	humanoid.PlatformStand = true
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end)

	local disabledMotors: { Motor6D } = {}
	local tempConstraints: { Instance } = {}

	for _, motor in ipairs(victimChar:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Name ~= "RootJoint" then
			local p0 = motor.Part0
			local p1 = motor.Part1
			if p0 and p1 then
				motor.Enabled = false
				table.insert(disabledMotors, motor)

				local a0 = Instance.new("Attachment")
				a0.Name = "RagdollA0"
				a0.CFrame = motor.C0
				a0.Parent = p0

				local a1 = Instance.new("Attachment")
				a1.Name = "RagdollA1"
				a1.CFrame = motor.C1
				a1.Parent = p1

				local socket = Instance.new("BallSocketConstraint")
				socket.Name = "RagdollSocket"
				socket.Attachment0 = a0
				socket.Attachment1 = a1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				socket.UpperAngle = 45
				socket.TwistLowerAngle = -45
				socket.TwistUpperAngle = 45
				socket.Parent = p1

				table.insert(tempConstraints, a0)
				table.insert(tempConstraints, a1)
				table.insert(tempConstraints, socket)
			end
		end
	end

	task.delay(duration, function()
		if not victimChar.Parent then return end

		for _, item in ipairs(tempConstraints) do
			if item.Parent then item:Destroy() end
		end
		for _, motor in ipairs(disabledMotors) do
			if motor.Parent then motor.Enabled = true end
		end
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.PlatformStand = false
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
		victimChar:SetAttribute("IsRagdolled", false)
	end)
end

-- Cache for locally registered KeyframeSequence asset IDs
local registeredKfsIds: { [KeyframeSequence]: string } = {}

local function registerKeyframeSequence(kfs: KeyframeSequence): string?
	if registeredKfsIds[kfs] then
		return registeredKfsIds[kfs]
	end
	local ok, tempId = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
	end)
	if ok and type(tempId) == "string" and tempId ~= "" then
		registeredKfsIds[kfs] = tempId
		return tempId
	end
	return nil
end

-- Procedural arm swing fallback (guarantees dynamic, responsive swing even if animation track is missing or blocked)
local function playProceduralSwing(character: Model, isR15: boolean)
	local shoulderMotor: Motor6D?
	if isR15 then
		local rUpper = character:FindFirstChild("RightUpperArm")
		if rUpper then
			shoulderMotor = rUpper:FindFirstChild("RightShoulder") :: Motor6D?
		end
	else
		local torso = character:FindFirstChild("Torso")
		if torso then
			shoulderMotor = torso:FindFirstChild("Right Shoulder") :: Motor6D?
		end
	end

	if not shoulderMotor then return end
	local origC0 = shoulderMotor.C0

	task.spawn(function()
		-- Phase 1: Windup (raise up and back)
		local windupC0 = origC0 * CFrame.Angles(math.rad(40), math.rad(25), math.rad(-20))
		-- Phase 2: Violent overhead forward strike
		local strikeC0 = origC0 * CFrame.Angles(math.rad(-85), math.rad(-20), math.rad(15))

		local start = os.clock()
		while os.clock() - start < 0.08 do
			local alpha = (os.clock() - start) / 0.08
			shoulderMotor.C0 = origC0:Lerp(windupC0, math.sin(alpha * math.pi * 0.5))
			task.wait()
		end

		local strikeStart = os.clock()
		while os.clock() - strikeStart < 0.12 do
			local alpha = (os.clock() - strikeStart) / 0.12
			shoulderMotor.C0 = windupC0:Lerp(strikeC0, alpha * alpha)
			task.wait()
		end

		local returnStart = os.clock()
		while os.clock() - returnStart < 0.15 do
			local alpha = (os.clock() - returnStart) / 0.15
			shoulderMotor.C0 = strikeC0:Lerp(origC0, math.sin(alpha * math.pi * 0.5))
			task.wait()
		end

		shoulderMotor.C0 = origC0
	end)
end

-- Play swing animation (supports local KeyframeSequence from AdminAssets or tool, with procedural fallback)
local function playSwingAnimation(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid then return end

	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local kfsName = if isR15 then "MetalPipeSwing_R15" else "MetalPipeSwing_R6"
	local played = false

	if animator then
		local adminAssets = ReplicatedStorage:FindFirstChild("AdminAssets")
		local animSource = (adminAssets and adminAssets:FindFirstChild(kfsName))
			or tool:FindFirstChild(kfsName)
			or tool:FindFirstChild(if isR15 then "R15Swing" else "R6Swing")

		local animId: string? = nil

		if animSource then
			if animSource:IsA("KeyframeSequence") then
				animId = registerKeyframeSequence(animSource)
			elseif animSource:IsA("Animation") and animSource.AnimationId ~= "" then
				animId = animSource.AnimationId
			end
		end

		if animId and animId ~= "" and not animId:find("10469498270") and not animId:find("129967390") then
			local animObj = Instance.new("Animation")
			animObj.AnimationId = animId
			local ok, track = pcall(function()
				return animator:LoadAnimation(animObj)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0.04, 1, 1.25)
				played = true
			end
		end
	end

	-- If animation asset could not be loaded or wasn't found, smoothly animate procedural swing
	if not played then
		playProceduralSwing(character, isR15)
	end
end

-- Tool Activation
tool.Activated:Connect(function()
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end
	if swingDebounce then return end

	swingDebounce = true
	isSwinging = true
	table.clear(hitVictims)

	playSwingAnimation(character)
	swingSound:Play()

	-- 0.35s damage and impact window
	task.delay(0.35, function()
		isSwinging = false
	end)

	-- 0.75s total attack cooldown
	task.delay(0.75, function()
		swingDebounce = false
	end)
end)

-- Handle Touched (Hit Detection, Knockback & Ragdoll)
handle.Touched:Connect(function(hit)
	if not isSwinging then return end
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end

	local victimChar = hit.Parent
	if not victimChar or not victimChar:IsA("Model") then
		victimChar = hit.Parent and hit.Parent.Parent
	end
	if not victimChar or not victimChar:IsA("Model") or victimChar == character then
		return
	end

	local victimHumanoid = victimChar:FindFirstChildOfClass("Humanoid")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if victimHumanoid and victimHumanoid.Health > 0 and not hitVictims[victimChar] then
		hitVictims[victimChar] = true

		-- Play iconic metal pipe clang sound
		clangSound:Play()

		-- Impact damage
		victimHumanoid:TakeDamage(35)

		-- Apply massive knockback velocity
		if victimRoot and attackerRoot then
			local delta = victimRoot.Position - attackerRoot.Position
			local horizontalDir = Vector3.new(delta.X, 0, delta.Z)
			local dir = if horizontalDir.Magnitude > 0.1 then horizontalDir.Unit else attackerRoot.CFrame.LookVector
			local launchForce = (dir + Vector3.new(0, 0.42, 0)).Unit * 85
			victimRoot.AssemblyLinearVelocity = launchForce
		end

		-- Apply physics ragdoll
		ragdollCharacter(victimChar, 2.5)
	end
end)
