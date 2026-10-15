--!strict
-- HammerServer.server.lua
-- Server controller for the mythical Ban Hammer.
-- Restricted to HeadAdmin rank. Hitting a player triggers a lightning strike, thunderclap,
-- ragdoll explosion, security audit log, and instant server kick/ban.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- Resolve Tool and auto-flatten if nested under an intermediate Model
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

-- Unpack any child Model inside the Tool so Handle is a direct child of Tool
local nestedModel = tool:FindFirstChildWhichIsA("Model")
if nestedModel then
	for _, child in ipairs(nestedModel:GetChildren()) do
		child.Parent = tool
	end
	task.defer(function()
		if nestedModel.Parent then nestedModel:Destroy() end
	end)
end

-- Natural two-handed grip
tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(90), 0, 0)

-- Ensure Handle exists (creates fallback physical warhammer if 3D model hasn't been imported yet)
local handle = tool:FindFirstChild("Handle") :: BasePart?
if not handle then
	handle = tool:WaitForChild("Handle", 2) :: BasePart?
end
if not handle then
	local newHandle = Instance.new("Part")
	newHandle.Name = "Handle"
	newHandle.Size = Vector3.new(0.45, 4.2, 0.45)
	newHandle.CFrame = CFrame.new(0, 0, 0)
	newHandle.Material = Enum.Material.Metal
	newHandle.Color = Color3.fromRGB(30, 41, 59)
	newHandle.CanCollide = false
	local cyl = Instance.new("CylinderMesh")
	cyl.Parent = newHandle

	local head = Instance.new("Part")
	head.Name = "HammerHead"
	head.Size = Vector3.new(1.8, 1.4, 2.6)
	head.CFrame = CFrame.new(0, 1.8, 0)
	head.Material = Enum.Material.DiamondPlate
	head.Color = Color3.fromRGB(15, 23, 42)
	head.CanCollide = false
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = newHandle
	weld.Part1 = head
	weld.Parent = newHandle

	newHandle.Parent = tool
	handle = newHandle
end

-- Forcefully unanchor all tool parts and weld to handle so character can move freely
for _, p in ipairs(tool:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Anchored = false
		p.CanCollide = false
		if p ~= handle and handle then
			local w = p:FindFirstChildWhichIsA("WeldConstraint")
			if not w then
				w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = p
				w.Parent = p
			end
		end
	end
end

-- Sounds
local function ensureSound(parent: Instance, name: string, soundId: string, volume: number, pitch: number?): Sound
	local sound = parent:FindFirstChild(name) :: Sound?
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = soundId
		sound.Volume = volume
		sound.RollOffMaxDistance = 250
		if pitch then sound.PlaybackSpeed = pitch end
		sound.Parent = parent
	end
	return sound
end

local thunderSound = ensureSound(handle, "ThunderSound", "rbxassetid://130861051", 2.5, 1.0)
local swingSound = ensureSound(handle, "SwingSound", "rbxassetid://169445121", 1.2, 0.75)
local sizzleSound = ensureSound(handle, "SizzleSound", "rbxassetid://130861051", 1.0, 1.8)

local isSwinging = false
local swingDebounce = false
local hitVictims: { [Model]: boolean } = {}

-- Verification helper for HeadAdmin rank
local function isHeadAdmin(player: Player): boolean
	local Settings = nil
	pcall(function()
		Settings = require(ReplicatedStorage:WaitForChild("AdminSettings", 2))
	end)
	if not Settings or not Settings.Ranks then return true end

	local requiredRank = Settings.Ranks["HeadAdmin"] or 4
	local playerRankName = Settings.PlayerRanks[player.Name] or "Player"
	local playerRankValue = Settings.Ranks[playerRankName] or 0
	return playerRankValue >= requiredRank
end

-- KeyframeSequence registration cache
local registeredAnimIds: { [KeyframeSequence]: string } = {}
local function registerKfs(kfs: KeyframeSequence): string?
	if registeredAnimIds[kfs] then return registeredAnimIds[kfs] end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
	end)
	if ok and type(id) == "string" and id ~= "" then
		registeredAnimIds[kfs] = id
		return id
	end
	return nil
end

-- Procedural heavy two-handed overhead slam fallback
local function playProceduralSlam(character: Model, isR15: boolean)
	local rShoulder: Motor6D?
	local lShoulder: Motor6D?

	if isR15 then
		local rArm = character:FindFirstChild("RightUpperArm")
		local lArm = character:FindFirstChild("LeftUpperArm")
		if rArm then rShoulder = rArm:FindFirstChild("RightShoulder") :: Motor6D? end
		if lArm then lShoulder = lArm:FindFirstChild("LeftShoulder") :: Motor6D? end
	else
		local torso = character:FindFirstChild("Torso")
		if torso then
			rShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
			lShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D?
		end
	end

	if not rShoulder then return end
	local origR = rShoulder.C0
	local origL = lShoulder and lShoulder.C0

	task.spawn(function()
		-- Windup: raise high over head
		local windupR = origR * CFrame.Angles(math.rad(85), math.rad(-15), math.rad(25))
		local windupL = origL and (origL * CFrame.Angles(math.rad(85), math.rad(15), math.rad(-25)))

		local t0 = os.clock()
		while os.clock() - t0 < 0.12 do
			local alpha = (os.clock() - t0) / 0.12
			rShoulder.C0 = origR:Lerp(windupR, math.sin(alpha * math.pi * 0.5))
			if lShoulder and origL and windupL then
				lShoulder.C0 = origL:Lerp(windupL, math.sin(alpha * math.pi * 0.5))
			end
			task.wait()
		end

		-- Slam down with massive force
		local slamR = origR * CFrame.Angles(math.rad(-90), math.rad(15), math.rad(-10))
		local slamL = origL and (origL * CFrame.Angles(math.rad(-90), math.rad(-15), math.rad(10)))

		local t1 = os.clock()
		while os.clock() - t1 < 0.14 do
			local alpha = (os.clock() - t1) / 0.14
			rShoulder.C0 = windupR:Lerp(slamR, alpha * alpha)
			if lShoulder and origL and windupL and slamL then
				lShoulder.C0 = windupL:Lerp(slamL, alpha * alpha)
			end
			task.wait()
		end

		-- Recovery
		local t2 = os.clock()
		while os.clock() - t2 < 0.24 do
			local alpha = (os.clock() - t2) / 0.24
			rShoulder.C0 = slamR:Lerp(origR, math.sin(alpha * math.pi * 0.5))
			if lShoulder and origL and slamL then
				lShoulder.C0 = slamL:Lerp(origL, math.sin(alpha * math.pi * 0.5))
			end
			task.wait()
		end

		rShoulder.C0 = origR
		if lShoulder and origL then lShoulder.C0 = origL end
	end)
end

-- Play swing animation
local function playSwingAnimation(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid then return end

	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local kfsName = if isR15 then "BanHammerSwing_R15" else "BanHammerSwing_R6"
	local played = false

	if animator then
		local adminAssets = ReplicatedStorage:FindFirstChild("AdminAssets")
		local animSource = (adminAssets and adminAssets:FindFirstChild(kfsName))
			or tool:FindFirstChild(kfsName)

		local animId: string? = nil
		if animSource and animSource:IsA("KeyframeSequence") then
			animId = registerKfs(animSource)
		end

		if animId and animId ~= "" then
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0.04, 1, 1.1)
				played = true
			end
		end
	end

	if not played then
		playProceduralSlam(character, isR15)
	end
end

-- Create dramatic lightning strike from sky to victim
local function spawnLightningStrike(targetPos: Vector3)
	local skyOrigin = targetPos + Vector3.new(math.random(-5, 5), 120, math.random(-5, 5))
	local bolt = Instance.new("Part")
	bolt.Name = "BanLightning"
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(254, 240, 138)

	local delta = targetPos - skyOrigin
	bolt.Size = Vector3.new(1.2, delta.Magnitude, 1.2)
	bolt.CFrame = CFrame.new(skyOrigin + delta * 0.5, targetPos) * CFrame.Angles(math.rad(90), 0, 0)
	bolt.Parent = workspace

	-- Flash light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(254, 240, 138)
	light.Brightness = 15
	light.Range = 40
	light.Parent = bolt

	-- Shockwave ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, 3, 3)
	ring.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(245, 158, 11)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = workspace

	task.spawn(function()
		for i = 1, 10 do
			local scale = 1 + i * 2.5
			ring.Size = Vector3.new(0.3, scale, scale)
			ring.Transparency = i / 10
			bolt.Transparency = i / 10
			light.Brightness = 15 * (1 - i / 10)
			task.wait(0.02)
		end
		bolt:Destroy()
		ring:Destroy()
	end)
end

-- Tool Activation
tool.Activated:Connect(function()
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Enforce HeadAdmin rank requirement
	if not isHeadAdmin(player) then
		sizzleSound:Play()
		return
	end

	if swingDebounce then return end
	swingDebounce = true
	isSwinging = true
	table.clear(hitVictims)

	playSwingAnimation(character)
	swingSound:Play()

	task.delay(0.35, function()
		isSwinging = false
	end)

	task.delay(0.9, function()
		swingDebounce = false
	end)
end)

-- Strike impact detection
handle.Touched:Connect(function(hit)
	if not isSwinging then return end
	local attackerChar = tool.Parent :: Model?
	if not attackerChar or not attackerChar:IsA("Model") then return end
	local attackerPlayer = Players:GetPlayerFromCharacter(attackerChar)
	if not attackerPlayer or not isHeadAdmin(attackerPlayer) then return end

	local victimChar = hit.Parent
	if not victimChar or not victimChar:IsA("Model") then
		victimChar = hit.Parent and hit.Parent.Parent
	end
	if not victimChar or not victimChar:IsA("Model") or victimChar == attackerChar then
		return
	end

	local victimHumanoid = victimChar:FindFirstChildOfClass("Humanoid")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local victimPlayer = Players:GetPlayerFromCharacter(victimChar)

	if victimHumanoid and victimHumanoid.Health > 0 and not hitVictims[victimChar] then
		hitVictims[victimChar] = true

		-- Thunder strike and audio
		thunderSound:Play()
		local strikePos = if victimRoot then victimRoot.Position else hit.Position
		spawnLightningStrike(strikePos)

		-- Violent ragdoll knockback
		if victimRoot and attackerRoot then
			local delta = victimRoot.Position - attackerRoot.Position
			local dir = if delta.Magnitude > 0.1 then delta.Unit else attackerRoot.CFrame.LookVector
			victimRoot.AssemblyLinearVelocity = (dir + Vector3.new(0, 0.7, 0)).Unit * 160
		end

		victimHumanoid:TakeDamage(1000)

		-- Audit log & Kick/Ban if victim is a live player
		if victimPlayer then
			task.delay(0.2, function()
				-- Security webhook / audit trigger
				pcall(function()
					local sss = game:GetService("ServerScriptService")
					local loader = sss:FindFirstChild("AdminLoader")
					local logger = loader and loader:FindFirstChild("AuditLogger")
					if logger and logger:IsA("ModuleScript") then
						require(logger).LogModeration(attackerPlayer, "banhammer", victimPlayer, "Struck down by the Ban Hammer")
					end
				end)

				victimPlayer:Kick(string.format(
					"\n🔨 [ADMIN BAN HAMMER]\nYou have been struck down by the Ban Hammer!\nWielder: %s\nStatus: Session Terminated",
					attackerPlayer.Name
				))
			end)
		end
	end
end)
