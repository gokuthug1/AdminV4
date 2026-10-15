--!strict
-- GravityGunServer.server.lua
-- Server controller for the Zero-Point Energy Gravity Gun.
-- Features: AlignPosition & AlignOrientation physics levitation, beam effects, and high-velocity flinging.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- Resolve actual Tool and auto-flatten if nested
local actualTool: Tool
if script.Parent:IsA("Tool") then
	actualTool = script.Parent
elseif script.Parent:IsA("Model") and script.Parent.Parent and script.Parent.Parent:IsA("Tool") then
	actualTool = script.Parent.Parent :: Tool
	local innerModel = script.Parent
	for _, child in ipairs(innerModel:GetChildren()) do
		if child ~= script then child.Parent = actualTool end
	end
	script.Parent = actualTool
	task.defer(function() if innerModel.Parent then innerModel:Destroy() end end)
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

-- Ensure Handle exists
local handle = tool:FindFirstChild("Handle") :: BasePart? or tool:WaitForChild("Handle", 2) :: BasePart?
if not handle then
	local newHandle = Instance.new("Part")
	newHandle.Name = "Handle"
	newHandle.Size = Vector3.new(0.65, 0.8, 2.4)
	newHandle.Material = Enum.Material.Metal
	newHandle.Color = Color3.fromRGB(51, 65, 85)
	newHandle.CanCollide = false
	newHandle.Anchored = false
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

-- Remote for client-server physics communication
local remote = tool:FindFirstChild("GravRemote") :: RemoteEvent?
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GravRemote"
	remote.Parent = tool
end

local gravRemote = remote :: RemoteEvent

-- Sounds
local function ensureSound(parent: Instance, name: string, soundId: string, volume: number): Sound
	local s = parent:FindFirstChild(name) :: Sound?
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = soundId
		s.Volume = volume
		s.RollOffMaxDistance = 150
		s.Parent = parent
	end
	return s
end

local grabSound = ensureSound(handle or tool, "GrabSound", "rbxassetid://169445121", 1.2)
local flingSound = ensureSound(handle or tool, "FlingSound", "rbxassetid://9114223180", 1.8)

type GrabSession = {
	TargetPart: BasePart,
	TargetModel: Model?,
	VictimChar: Model?,
	HolderPart: Part,
	AlignPos: AlignPosition,
	AlignOri: AlignOrientation,
	Beam: Beam,
	Att0: Attachment,
	Att1: Attachment,
	OriginalNetworkOwner: Player?,
}

local activeSessions: { [Player]: GrabSession } = {}

local function endSession(player: Player, flingVelocity: Vector3?)
	local session = activeSessions[player]
	if not session then return end
	activeSessions[player] = nil

	if session.TargetPart and session.TargetPart.Parent then
		if flingVelocity then
			pcall(function()
				session.TargetPart.AssemblyLinearVelocity = flingVelocity
			end)
		end
	end

	if session.VictimChar and session.VictimChar.Parent then
		local hum = session.VictimChar:FindFirstChildOfClass("Humanoid")
		if hum and not flingVelocity then
			task.delay(0.5, function()
				if hum.Parent then
					hum.PlatformStand = false
					pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
				end
			end)
		end
	end

	pcall(function() session.HolderPart:Destroy() end)
	pcall(function() session.Beam:Destroy() end)
	pcall(function() session.Att0:Destroy() end)
	pcall(function() session.Att1:Destroy() end)
end

gravRemote.OnServerEvent:Connect(function(player: Player, action: string, data: any)
	local character = player.Character
	if not character or tool.Parent ~= character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	if action == "Grab" then
		if activeSessions[player] then
			endSession(player, nil)
		end

		local targetPart = data.TargetPart :: BasePart?
		if not targetPart or not targetPart:IsA("BasePart") or targetPart.Anchored then return end

		-- Check distance
		if (targetPart.Position - rootPart.Position).Magnitude > 65 then return end

		local victimChar: Model? = nil
		local parentModel = targetPart:FindFirstAncestorWhichIsA("Model")
		if parentModel and parentModel:FindFirstChildOfClass("Humanoid") then
			victimChar = parentModel
			local hum = victimChar:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.PlatformStand = true
			end
			-- Grab root or torso if available
			local vRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if vRoot then targetPart = vRoot end
		end

		-- Create holder part (client updates its position)
		local holder = Instance.new("Part")
		holder.Name = "GravGunHolder_" .. player.Name
		holder.Size = Vector3.new(0.5, 0.5, 0.5)
		holder.Transparency = 1
		holder.CanCollide = false
		holder.Anchored = true
		holder.CFrame = CFrame.new(rootPart.Position + rootPart.CFrame.LookVector * 12)
		holder.Parent = workspace

		local att0 = Instance.new("Attachment")
		att0.Name = "HolderAtt"
		att0.Parent = holder

		local att1 = Instance.new("Attachment")
		att1.Name = "TargetAtt"
		att1.Parent = targetPart

		-- Modern physics constraints
		local alignPos = Instance.new("AlignPosition")
		alignPos.Name = "GravAlignPos"
		alignPos.Attachment0 = att1
		alignPos.Attachment1 = att0
		alignPos.MaxForce = 350000
		alignPos.Responsiveness = 25
		alignPos.ApplyAtCenterOfMass = true
		alignPos.Parent = holder

		local alignOri = Instance.new("AlignOrientation")
		alignOri.Name = "GravAlignOri"
		alignOri.Attachment0 = att1
		alignOri.Attachment1 = att0
		alignOri.MaxTorque = 350000
		alignOri.Responsiveness = 20
		alignOri.Parent = holder

		-- Electric visual beam connecting muzzle to target
		local muzzleAtt = handle and handle:FindFirstChild("MuzzleAtt") :: Attachment?
		if not muzzleAtt and handle then
			muzzleAtt = Instance.new("Attachment")
			muzzleAtt.Name = "MuzzleAtt"
			muzzleAtt.Position = Vector3.new(0, 0, -1.2)
			muzzleAtt.Parent = handle
		end

		local beam = Instance.new("Beam")
		beam.Name = "GravBeam"
		beam.Attachment0 = muzzleAtt or att0
		beam.Attachment1 = att1
		beam.Width0 = 0.35
		beam.Width1 = 0.45
		beam.Color = ColorSequence.new(Color3.fromRGB(6, 182, 212), Color3.fromRGB(56, 189, 248))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Texture = "rbxassetid://446111271"
		beam.TextureSpeed = 2.5
		beam.Parent = holder

		grabSound:Play()

		activeSessions[player] = {
			TargetPart = targetPart,
			TargetModel = parentModel,
			VictimChar = victimChar,
			HolderPart = holder,
			AlignPos = alignPos,
			AlignOri = alignOri,
			Beam = beam,
			Att0 = att0,
			Att1 = att1,
			OriginalNetworkOwner = nil,
		}

	elseif action == "UpdateHolder" then
		local session = activeSessions[player]
		if session and session.HolderPart and session.HolderPart.Parent then
			local newCFrame = data.CFrame :: CFrame?
			if newCFrame then
				session.HolderPart.CFrame = newCFrame
			end
		end

	elseif action == "Release" then
		endSession(player, nil)

	elseif action == "Fling" then
		local lookDir = data.Direction :: Vector3?
		local dir = if lookDir and lookDir.Magnitude > 0.1 then lookDir.Unit else rootPart.CFrame.LookVector
		local launchVel = (dir + Vector3.new(0, 0.18, 0)).Unit * 175
		flingSound:Play()
		endSession(player, launchVel)
	end
end)

tool.Unequipped:Connect(function()
	local char = tool.Parent and tool.Parent.Parent
	local player = char and Players:GetPlayerFromCharacter(char)
	if player then
		endSession(player, nil)
	end
end)

Players.PlayerRemoving:Connect(function(leaving)
	endSession(leaving, nil)
end)
