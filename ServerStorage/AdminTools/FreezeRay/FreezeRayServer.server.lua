--!strict
-- FreezeRayServer.server.lua
-- Server controller for the Freeze Ray / Ice Wand.
-- Fires cryo projectiles directed at mouse target that encase victims in procedural ice blocks.

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
	newHandle.Size = Vector3.new(0.4, 3.4, 0.4)
	newHandle.Material = Enum.Material.Glass
	newHandle.Color = Color3.fromRGB(224, 242, 254)
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

-- Remote for mouse-aim communication
local remote = tool:FindFirstChild("FreezeRemote") :: RemoteEvent?
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "FreezeRemote"
	remote.Parent = tool
end
local freezeRemote = remote :: RemoteEvent

-- Sounds
local function ensureSound(parent: Instance, name: string, soundId: string, volume: number, pitch: number?): Sound
	local s = parent:FindFirstChild(name) :: Sound?
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = soundId
		s.Volume = volume
		s.RollOffMaxDistance = 150
		if pitch then s.PlaybackSpeed = pitch end
		s.Parent = parent
	end
	return s
end

local shootSound = ensureSound(handle or tool, "ShootSound", "rbxassetid://169445121", 1.0, 1.4)
local freezeSound = ensureSound(handle or tool, "FreezeSound", "rbxassetid://9114223180", 1.8, 1.2)

local shootDebounce = false

-- Encase victim in procedural ice cube
local function freezeCharacter(victimChar: Model, duration: number)
	local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
	local rootPart = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not rootPart then return end

	-- Check if already frozen
	if victimChar:GetAttribute("IsFrozen") then return end
	victimChar:SetAttribute("IsFrozen", true)

	humanoid.PlatformStand = true
	local prevAnchored = rootPart.Anchored
	rootPart.Anchored = true

	-- Procedural translucent Ice Cube Block
	local iceCube = Instance.new("Part")
	iceCube.Name = "CryoIceBlock"
	iceCube.Size = Vector3.new(5.0, 6.4, 5.0)
	iceCube.CFrame = rootPart.CFrame
	iceCube.Material = Enum.Material.Glass
	iceCube.Color = Color3.fromRGB(186, 230, 253)
	iceCube.Transparency = 0.35
	iceCube.Reflectance = 0.25
	iceCube.Anchored = true
	iceCube.CanCollide = true
	iceCube.CastShadow = false

	-- Frost light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(186, 230, 253)
	light.Brightness = 3
	light.Range = 10
	light.Parent = iceCube

	-- Frost particles
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://243098098"
	emitter.Color = ColorSequence.new(Color3.fromRGB(224, 242, 254), Color3.fromRGB(56, 189, 248))
	emitter.Rate = 18
	emitter.Lifetime = NumberRange.new(1.0, 2.0)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.0)
	})
	emitter.Parent = iceCube
	iceCube.Parent = workspace

	freezeSound:Play()

	task.delay(duration, function()
		if not victimChar.Parent then
			pcall(function() iceCube:Destroy() end)
			return
		end

		-- Shatter effect
		emitter.Enabled = false
		iceCube.Transparency = 0.8
		task.wait(0.2)
		iceCube:Destroy()

		if rootPart.Parent then
			rootPart.Anchored = prevAnchored
		end
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.PlatformStand = false
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end
		victimChar:SetAttribute("IsFrozen", false)
	end)
end

-- Fire cryo projectile toward targetPos (mouse hit location)
local function fireCryoBolt(character: Model, targetPos: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local origin: Vector3
	if handle then
		origin = handle.Position
	else
		origin = root.Position + Vector3.new(0, 1.5, 0)
	end

	local target: Vector3 = targetPos or (origin + root.CFrame.LookVector * 100)
	local dir = (target - origin)
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	else
		dir = dir.Unit
	end

	-- Spawn projectile slightly ahead of origin to avoid collision with shooter
	local spawnPos = origin + (dir * 2.2)

	local projectile = Instance.new("Part")
	projectile.Name = "CryoBolt"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(1.1, 1.1, 1.1)
	projectile.CFrame = CFrame.lookAt(spawnPos, spawnPos + dir)
	projectile.Material = Enum.Material.Neon
	projectile.Color = Color3.fromRGB(56, 189, 248)
	projectile.CanCollide = false
	projectile.CastShadow = false

	local pLight = Instance.new("PointLight")
	pLight.Color = Color3.fromRGB(56, 189, 248)
	pLight.Brightness = 4
	pLight.Range = 14
	pLight.Parent = projectile

	-- Trail effect
	local trailEmitter = Instance.new("ParticleEmitter")
	trailEmitter.Texture = "rbxassetid://243098098"
	trailEmitter.Color = ColorSequence.new(Color3.fromRGB(224, 242, 254), Color3.fromRGB(56, 189, 248))
	trailEmitter.Rate = 45
	trailEmitter.Lifetime = NumberRange.new(0.3, 0.6)
	trailEmitter.Speed = NumberRange.new(1, 3)
	trailEmitter.SpreadAngle = Vector2.new(180, 180)
	trailEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.0)
	})
	trailEmitter.Parent = projectile

	-- Velocity
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Velocity = dir * 135
	bv.Parent = projectile

	projectile.Parent = workspace
	Debris:AddItem(projectile, 4.5)

	local hasHit = false
	projectile.Touched:Connect(function(hit)
		if hasHit then return end
		-- Ignore parts belonging to shooter
		if hit:IsDescendantOf(character) then return end
		if hit.Transparency >= 0.95 and not hit.CanCollide then return end

		local victimChar = hit.Parent
		if not victimChar or not victimChar:IsA("Model") then
			victimChar = hit.Parent and hit.Parent.Parent
		end

		if victimChar and victimChar:IsA("Model") and victimChar ~= character then
			local hum = victimChar:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hasHit = true
				projectile:Destroy()
				freezeCharacter(victimChar, 10)
				return
			end
		end

		-- Terrain or building impact
		if hit.CanCollide or hit:IsA("Terrain") then
			hasHit = true
			local impactEffect = Instance.new("Part")
			impactEffect.Size = Vector3.new(0.5, 0.5, 0.5)
			impactEffect.CFrame = projectile.CFrame
			impactEffect.Transparency = 1
			impactEffect.Anchored = true
			impactEffect.CanCollide = false
			local spark = trailEmitter:Clone()
			spark.Rate = 0
			spark.Parent = impactEffect
			impactEffect.Parent = workspace
			spark:Emit(15)
			Debris:AddItem(impactEffect, 1)

			projectile:Destroy()
		end
	end)
end

-- Client mouse-aim trigger
freezeRemote.OnServerEvent:Connect(function(firingPlayer: Player, targetPos: any)
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end
	local playerFromChar = Players:GetPlayerFromCharacter(character)
	if playerFromChar ~= firingPlayer then return end

	if shootDebounce then return end
	shootDebounce = true

	shootSound:Play()
	local validTarget: Vector3? = nil
	if typeof(targetPos) == "Vector3" then
		validTarget = targetPos
	end

	fireCryoBolt(character, validTarget)

	task.delay(0.6, function()
		shootDebounce = false
	end)
end)

-- Fallback for NPC or direct script activation without client script
tool.Activated:Connect(function()
	local character = tool.Parent :: Model?
	if not character or not character:IsA("Model") then return end

	-- Skip if held by a real player (since FreezeRemote handles mouse aim)
	local playerFromChar = Players:GetPlayerFromCharacter(character)
	if playerFromChar then return end

	if shootDebounce then return end
	shootDebounce = true

	shootSound:Play()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fallbackTarget = root and (root.Position + root.CFrame.LookVector * 60) or nil
	fireCryoBolt(character, fallbackTarget)

	task.delay(0.6, function()
		shootDebounce = false
	end)
end)
