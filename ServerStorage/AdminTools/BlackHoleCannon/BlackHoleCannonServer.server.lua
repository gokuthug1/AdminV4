--!strict
-- BlackHoleCannonServer.server.lua
-- Server controller for the Dark Matter Singularity Cannon.
-- Fires a singularity orb that collapses into a gravitational black hole vortex,
-- pulling props and players into an orbital accretion disk before detonating into a shockwave.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

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
	newHandle.Size = Vector3.new(0.65, 0.85, 2.2)
	newHandle.Material = Enum.Material.Metal
	newHandle.Color = Color3.fromRGB(30, 27, 75)
	newHandle.CanCollide = false
	newHandle.Anchored = false
	newHandle.Parent = tool
	handle = newHandle
end

-- Forcefully unanchor all tool parts and weld to handle
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

-- Remote for mouse-aim communication
local remote = tool:FindFirstChild("BlackHoleRemote") :: RemoteEvent?
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "BlackHoleRemote"
	remote.Parent = tool
end
local blackHoleRemote = remote :: RemoteEvent

-- Sounds
local function ensureSound(parent: Instance, name: string, soundId: string, volume: number, pitch: number?): Sound
	local s = parent:FindFirstChild(name) :: Sound?
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = soundId
		s.Volume = volume
		s.RollOffMaxDistance = 200
		if pitch then s.PlaybackSpeed = pitch end
		s.Parent = parent
	end
	return s
end

local fireSound = ensureSound(handle or tool, "FireSound", "rbxassetid://169445121", 1.2, 0.8)
local shootDebounce = false

-- Spawn and simulate the Gravitational Singularity Vortex
local function spawnSingularityVortex(centerPos: Vector3, shooterChar: Model?)
	local vortexModel = Instance.new("Model")
	vortexModel.Name = "SingularityVortex"

	-- Event Horizon Core
	local core = Instance.new("Part")
	core.Name = "EventHorizon"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(7.0, 7.0, 7.0)
	core.Position = centerPos
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.fromRGB(5, 5, 10)
	core.Anchored = true
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = vortexModel

	-- Accretion Ring
	local ring = Instance.new("Part")
	ring.Name = "AccretionDisk"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 20.0, 20.0)
	ring.CFrame = CFrame.new(centerPos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(168, 85, 247)
	ring.Transparency = 0.4
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Parent = vortexModel

	-- Glowing Light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(192, 132, 252)
	light.Brightness = 7
	light.Range = 40
	light.Parent = core

	-- Vortex Suction Particles
	local suctionEmitter = Instance.new("ParticleEmitter")
	suctionEmitter.Texture = "rbxassetid://243098098"
	suctionEmitter.Color = ColorSequence.new(Color3.fromRGB(192, 132, 252), Color3.fromRGB(30, 27, 75))
	suctionEmitter.Rate = 50
	suctionEmitter.Lifetime = NumberRange.new(0.6, 1.2)
	suctionEmitter.Speed = NumberRange.new(-18, -8) -- inward suction!
	suctionEmitter.SpreadAngle = Vector2.new(180, 180)
	suctionEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0.1)
	})
	suctionEmitter.Parent = core

	-- Suction Audio
	local humSound = Instance.new("Sound")
	humSound.SoundId = "rbxassetid://134938155899966"
	humSound.Volume = 2.0
	humSound.PlaybackSpeed = 0.55
	humSound.Looped = true
	humSound.RollOffMaxDistance = 250
	humSound.Parent = core
	humSound:Play()

	vortexModel.Parent = workspace
	Debris:AddItem(vortexModel, 8)

	-- Gravitational Physics Loop (~5.5 seconds)
	local radius = 55
	local caughtPlayers: { [Player]: boolean } = {}

	task.spawn(function()
		local startTime = os.clock()
		local duration = 5.5

		while (os.clock() - startTime) < duration and core.Parent do
			-- Rotate accretion ring
			ring.CFrame = ring.CFrame * CFrame.Angles(0.08, 0, 0)

			-- Pull unanchored parts in workspace
			for _, part in ipairs(workspace:GetPartBoundsInRadius(centerPos, radius)) do
				if not part.Anchored and part ~= core and part ~= ring and not part:IsDescendantOf(vortexModel) then
					local offset = centerPos - part.Position
					local dist = offset.Magnitude
					if dist > 1.5 then
						local pullDir = offset.Unit
						local tangent = pullDir:Cross(Vector3.new(0, 1, 0)).Unit
						local pullVel = (pullDir * math.clamp(45 - dist * 0.5, 10, 50)) + (tangent * 18)
						part.AssemblyLinearVelocity = pullVel
					end
				end
			end

			-- Pull all players
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				if char and char ~= shooterChar then
					local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 and not char:GetAttribute("GodmodeActive") then
						local offset = centerPos - hrp.Position
						local dist = offset.Magnitude
						if dist <= radius then
							hum.PlatformStand = true
							caughtPlayers[p] = true
							if dist > 2.5 then
								local pullDir = offset.Unit
								local tangent = pullDir:Cross(Vector3.new(0, 1, 0)).Unit
								local pullSpeed = math.clamp(55 - dist * 0.7, 12, 60)
								hrp.AssemblyLinearVelocity = (pullDir * pullSpeed) + (tangent * 22)
							else
								hrp.AssemblyLinearVelocity = Vector3.new(0, 5, 0)
							end
						end
					end
				end
			end

			task.wait(0.05)
		end

		-- DETONATION SEQUENCE
		if core.Parent then
			humSound:Stop()
			suctionEmitter.Enabled = false

			-- Collapse core to pinpoint
			for i = 1, 5 do
				core.Size = core.Size * 0.65
				task.wait(0.03)
			end

			-- Detonation sound
			local blastSound = Instance.new("Sound")
			blastSound.SoundId = "rbxassetid://287390459"
			blastSound.Volume = 2.5
			blastSound.PlaybackSpeed = 0.9
			blastSound.RollOffMaxDistance = 350
			blastSound.Parent = core
			blastSound:Play()

			-- Shockwave expansion
			local blast = Instance.new("Part")
			blast.Shape = Enum.PartType.Ball
			blast.Size = Vector3.new(5, 5, 5)
			blast.Position = centerPos
			blast.Material = Enum.Material.Neon
			blast.Color = Color3.fromRGB(192, 132, 252)
			blast.Anchored = true
			blast.CanCollide = false
			blast.Parent = workspace
			Debris:AddItem(blast, 0.6)

			-- Fling outwards
			for _, part in ipairs(workspace:GetPartBoundsInRadius(centerPos, radius + 10)) do
				if not part.Anchored and not part:IsDescendantOf(vortexModel) and part ~= blast then
					local flingDir = (part.Position - centerPos).Unit + Vector3.new(0, 0.4, 0)
					part.AssemblyLinearVelocity = flingDir.Unit * 85
				end
			end

			-- Restore caught players
			for p in pairs(caughtPlayers) do
				if p.Character then
					local hum = p.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						task.delay(0.6, function()
							hum.PlatformStand = false
							pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
						end)
					end
				end
			end

			-- Fade blast
			task.spawn(function()
				for i = 1, 10 do
					blast.Size = blast.Size + Vector3.new(4, 4, 4)
					blast.Transparency = i / 10
					task.wait(0.03)
				end
				blast:Destroy()
			end)

			vortexModel:Destroy()
		end
	end)
end

-- Fire Singularity Orb
local function fireSingularityOrb(character: Model, targetPos: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local origin: Vector3 = handle and handle.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local target: Vector3 = targetPos or (origin + root.CFrame.LookVector * 120)
	local dir = (target - origin)
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	else
		dir = dir.Unit
	end

	local spawnPos = origin + (dir * 3.0)

	local orb = Instance.new("Part")
	orb.Name = "SingularityOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.8, 1.8, 1.8)
	orb.CFrame = CFrame.lookAt(spawnPos, spawnPos + dir)
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(147, 51, 234)
	orb.CanCollide = false
	orb.CastShadow = false

	local orbLight = Instance.new("PointLight")
	orbLight.Color = Color3.fromRGB(192, 132, 252)
	orbLight.Brightness = 5
	orbLight.Range = 16
	orbLight.Parent = orb

	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxassetid://243098098"
	trail.Color = ColorSequence.new(Color3.fromRGB(192, 132, 252), Color3.fromRGB(30, 27, 75))
	trail.Rate = 50
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Speed = NumberRange.new(1, 3)
	trail.SpreadAngle = Vector2.new(180, 180)
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.0)
	})
	trail.Parent = orb

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Velocity = dir * 110
	bv.Parent = orb

	orb.Parent = workspace
	Debris:AddItem(orb, 4)

	local hasDetonated = false
	local function detonate()
		if hasDetonated then return end
		hasDetonated = true
		local hitPos = orb.Position
		orb:Destroy()
		spawnSingularityVortex(hitPos, character)
	end

	orb.Touched:Connect(function(hit)
		if hasDetonated then return end
		if hit:IsDescendantOf(character) then return end
		if hit.Transparency >= 0.95 and not hit.CanCollide then return end
		detonate()
	end)

	-- Detonate automatically near target destination
	task.delay(math.clamp((target - spawnPos).Magnitude / 110, 0.2, 3.5), function()
		if not hasDetonated and orb.Parent then
			detonate()
		end
	end)
end

-- Client mouse-aim trigger
blackHoleRemote.OnServerEvent:Connect(function(firingPlayer: Player, targetPos: any)
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end
	local playerFromChar = Players:GetPlayerFromCharacter(character)
	if playerFromChar ~= firingPlayer then return end

	if shootDebounce then return end
	shootDebounce = true

	fireSound:Play()
	local validTarget: Vector3? = nil
	if typeof(targetPos) == "Vector3" then
		validTarget = targetPos
	end

	fireSingularityOrb(character, validTarget)

	task.delay(1.5, function()
		shootDebounce = false
	end)
end)

-- Fallback for NPC or direct script activation
tool.Activated:Connect(function()
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end

	local playerFromChar = Players:GetPlayerFromCharacter(character)
	if playerFromChar then return end

	if shootDebounce then return end
	shootDebounce = true

	fireSound:Play()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fallbackTarget = root and (root.Position + root.CFrame.LookVector * 80) or nil
	fireSingularityOrb(character, fallbackTarget)

	task.delay(1.5, function()
		shootDebounce = false
	end)
end)
