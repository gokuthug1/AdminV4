local Commands = {}
Commands.BannedPlayers = {} 
local ControlCache = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local TeamsService = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ChatService = game:GetService("Chat")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local TextService = game:GetService("TextService")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) or ReplicatedStorage:FindFirstChild("Remotes")
local ClientAction = Remotes and (Remotes:WaitForChild("ClientAction", 10) or Remotes:FindFirstChild("ClientAction"))
local AdminAssets = ReplicatedStorage:FindFirstChild("AdminAssets") or ReplicatedStorage:WaitForChild("AdminAssets", 5)
local AdminUiAssets = ReplicatedStorage:FindFirstChild("AdminUiAssets") or ReplicatedStorage:WaitForChild("AdminUiAssets", 5)

local settingsModule = ReplicatedStorage:WaitForChild("AdminSettings", 10)
if not settingsModule then
	error("AdminSettings could not be found in ReplicatedStorage.")
end
local Settings = require(settingsModule)

local function resolveSiblingModule(name)
	local child = script:FindFirstChild(name)
	if child and child:IsA("ModuleScript") then
		return child
	end
	local sibling = script.Parent and script.Parent:FindFirstChild(name)
	if sibling and sibling:IsA("ModuleScript") then
		return sibling
	end
	return (script.Parent and script.Parent:WaitForChild(name, 5)) or script:WaitForChild(name, 5)
end
local utilModule = resolveSiblingModule("Util")
if not utilModule then
	error("Util module could not be found in AdminLoader hierarchy.")
end
local Util = require(utilModule)

local auditLoggerModule = nil
pcall(function() auditLoggerModule = resolveSiblingModule("AuditLogger") end)
local AuditLogger = nil
if auditLoggerModule then
	pcall(function()
		AuditLogger = require(auditLoggerModule)
	end)
end

local function logAudit(executor, action, target, reason, extra)
	if AuditLogger and AuditLogger.LogModeration then
		pcall(function()
			AuditLogger.LogModeration(executor, action, target, reason, extra)
		end)
	end
end

Commands.SessionState = Commands.SessionState or {
	CommandLogs = {},
	GlobalCommandLock = false,
	LockedCommands = {},
	NextLogId = 1,
}

local AppearanceCache = {}
local HumanoidStateCache = {}
local PoseCache = {}
local SlipperyMomentumCache = {}
local WorldLoops = {}
local LightingDefaults = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
	GlobalShadows = Lighting.GlobalShadows,
}

function Commands.SetSessionState(state)
	Commands.SessionState = state
end

local function getSessionState()
	return Commands.SessionState
end

local function getCharacter(target)
	return Util.GetCharacter(target)
end

local function getHumanoid(target)
	return Util.GetHumanoid(target)
end

local function getRoot(target)
	return Util.GetRootPart(target)
end

local function ensureWorkspaceFolder(name)
	local rootFolder = Workspace:FindFirstChild("AdminGenerated")
	if not rootFolder then
		rootFolder = Instance.new("Folder")
		rootFolder.Name = "AdminGenerated"
		rootFolder.Parent = Workspace
	end

	local folder = rootFolder:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = rootFolder
	end
	return folder
end

local function cacheAppearance(target, key)
	local character = getCharacter(target)
	if not character then
		return nil
	end

	local cacheKey = target.UserId
	AppearanceCache[cacheKey] = AppearanceCache[cacheKey] or {}
	local existing = AppearanceCache[cacheKey][key]
	if existing and existing.Character == character then
		return existing
	end

	local snapshot = {Character = character, Parts = {}, Decals = {}}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			snapshot.Parts[descendant] = {
				Color = descendant.Color,
				Material = descendant.Material,
				Transparency = descendant.Transparency,
				CanCollide = descendant.CanCollide,
			}
		elseif descendant:IsA("Decal") then
			snapshot.Decals[descendant] = {Transparency = descendant.Transparency}
		end
	end

	AppearanceCache[cacheKey][key] = snapshot
	return snapshot
end

local function restoreAppearance(target, key)
	local cacheKey = target.UserId
	local snapshot = AppearanceCache[cacheKey] and AppearanceCache[cacheKey][key]
	if not snapshot then
		return
	end

	for part, state in pairs(snapshot.Parts) do
		if part and part.Parent then
			part.Color = state.Color
			part.Material = state.Material
			part.Transparency = state.Transparency
			part.CanCollide = state.CanCollide
		end
	end

	for decal, state in pairs(snapshot.Decals) do
		if decal and decal.Parent then
			decal.Transparency = state.Transparency
		end
	end

	AppearanceCache[cacheKey][key] = nil
end

local function cacheHumanoidState(target, key)
	local humanoid = getHumanoid(target)
	if not humanoid then
		return nil
	end

	local cacheKey = target.UserId
	HumanoidStateCache[cacheKey] = HumanoidStateCache[cacheKey] or {}
	local existing = HumanoidStateCache[cacheKey][key]
	if existing and existing.Humanoid == humanoid then
		return existing
	end

	local snapshot = {
		Humanoid = humanoid,
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		PlatformStand = humanoid.PlatformStand,
		AutoRotate = humanoid.AutoRotate,
	}
	HumanoidStateCache[cacheKey][key] = snapshot
	return snapshot
end

local function restoreHumanoidState(target, key)
	local cacheKey = target.UserId
	local snapshot = HumanoidStateCache[cacheKey] and HumanoidStateCache[cacheKey][key]
	if not snapshot then
		return
	end

	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid.WalkSpeed = snapshot.WalkSpeed
		humanoid.JumpPower = snapshot.JumpPower
		humanoid.PlatformStand = snapshot.PlatformStand
		humanoid.AutoRotate = snapshot.AutoRotate
	end

	HumanoidStateCache[cacheKey][key] = nil
end

local function runTargetLoop(target, key, interval, stepFn, cleanupFn)
	local token = Util.BeginLoop(target, key, cleanupFn)
	task.spawn(function()
		while Util.IsLoopActive(target, key, token) do
			stepFn(token)
			task.wait(interval)
		end
	end)
	return token
end

local function stopWorldLoop(key)
	local worldToken = WorldLoops[key]
	if not worldToken then
		return
	end
	worldToken.Active = false
	WorldLoops[key] = nil
	if worldToken.Cleanup then
		pcall(worldToken.Cleanup)
	end
end

local function runWorldLoop(key, interval, stepFn, cleanupFn)
	stopWorldLoop(key)
	local token = {Active = true, Cleanup = cleanupFn}
	WorldLoops[key] = token
	task.spawn(function()
		while token.Active do
			stepFn(token)
			task.wait(interval)
		end
	end)
	return token
end

local function teleportTarget(target, destination)
	local character = getCharacter(target)
	if not character then
		return
	end
	character:PivotTo(destination)
end

local function ensureLightingEffect(name, className)
	local effect = Lighting:FindFirstChild(name)
	if not effect then
		effect = Instance.new(className)
		effect.Name = name
		effect.Parent = Lighting
	end
	return effect
end

local function getAsset(name)
	if not AdminAssets then
		AdminAssets = ReplicatedStorage:FindFirstChild("AdminAssets") or ReplicatedStorage:WaitForChild("AdminAssets", 5)
	end
	if not AdminAssets then return nil end
	local asset = AdminAssets:FindFirstChild(name)
	if asset then return asset:Clone() end
	return nil
end

local function getUiAsset(name, className)
	if not AdminUiAssets then
		AdminUiAssets = ReplicatedStorage:FindFirstChild("AdminUiAssets") or ReplicatedStorage:WaitForChild("AdminUiAssets", 5)
	end
	if not AdminUiAssets then
		warn(string.format("AdminUiAssets was not found in ReplicatedStorage."))
		return nil
	end

	local asset = AdminUiAssets:FindFirstChild(name) or AdminUiAssets:WaitForChild(name, 5)
	if not asset then
		warn(string.format("Admin UI asset '%s' was not found in AdminUiAssets.", name))
		return nil
	end
	if className and not asset:IsA(className) then
		warn(string.format("Admin UI asset '%s' must be a %s.", name, className))
		return nil
	end
	return asset:Clone()
end

local function findElement(parent, targetName, className)
	for _, v in pairs(parent:GetDescendants()) do
		if (v.Name == targetName) or (className and v:IsA(className) and v.Name == targetName) then return v end
	end
	return nil
end

local function getTorso(target)
	local character = getCharacter(target)
	if not character then
		return nil
	end
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function getDefaultColor(colorName, fallback)
	local resolvedName, resolvedColor = Util.ResolveColorName(colorName)
	if resolvedColor then
		return resolvedName, resolvedColor
	end
	return fallback, Settings.Colors[fallback] or Color3.new(1, 1, 1)
end

local function consumeColorArgs(args, startIndex, maxWords)
	startIndex = startIndex or 1
	maxWords = maxWords or 3
	local finalIndex = math.min(#args, startIndex + maxWords - 1)
	for lastIndex = finalIndex, startIndex, -1 do
		local candidate = table.concat(args, " ", startIndex, lastIndex)
		local colorName, color = Util.ResolveColorName(candidate)
		if color then
			return colorName, color, lastIndex - startIndex + 1
		end
	end
	return nil, nil, 0
end

local function mixColor(colorA, colorB, alpha)
	return Color3.new(
		colorA.R + ((colorB.R - colorA.R) * alpha),
		colorA.G + ((colorB.G - colorA.G) * alpha),
		colorA.B + ((colorB.B - colorA.B) * alpha)
	)
end

local function getHorizontalDirection(cf)
	local candidates = {
		Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z),
		Vector3.new(-cf.UpVector.X, 0, -cf.UpVector.Z),
		Vector3.new(cf.UpVector.X, 0, cf.UpVector.Z),
		Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z),
		Vector3.new(-cf.RightVector.X, 0, -cf.RightVector.Z),
	}
	local best = Vector3.new(0, 0, -1)
	local bestMagnitude = 0
	for _, candidate in ipairs(candidates) do
		local magnitude = candidate.Magnitude
		if magnitude > bestMagnitude then
			best = candidate
			bestMagnitude = magnitude
		end
	end
	if bestMagnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return best.Unit
end

local function cachePose(target, key)
	local root = getRoot(target)
	if not root then
		return nil
	end

	local cacheKey = target.UserId
	PoseCache[cacheKey] = PoseCache[cacheKey] or {}
	local snapshot = {
		Root = root,
		CFrame = root.CFrame,
	}
	PoseCache[cacheKey][key] = snapshot
	return snapshot
end

local function restorePose(target, key)
	local cacheKey = target.UserId
	local snapshot = PoseCache[cacheKey] and PoseCache[cacheKey][key]
	if not snapshot then
		return
	end

	local root = getRoot(target)
	if root then
		local forward = getHorizontalDirection(snapshot.CFrame)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + forward)
	end

	PoseCache[cacheKey][key] = nil
end

local function createWeldedPart(parent, className, name, attachTo, properties)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.CanCollide = false
	part.Anchored = false
	part.Massless = true
	part.CastShadow = false
	for propertyName, value in pairs(properties or {}) do
		part[propertyName] = value
	end
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = attachTo
	weld.Parent = part
	return part
end

-- // COMMANDS //

Commands.clean = function(sender, target, args)
	local count = 0
	for key in pairs(WorldLoops) do
		stopWorldLoop(key)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		Util.StopAllLoops(player)
	end
	for _, v in pairs(Workspace:GetDescendants()) do
		if v.Name == "JailFolder" or v.Name == "AdminSpike" or v.Name == "AdminLight" or v.Name:match("^KillAura_") or v.Name:match("^Admin") then
			v:Destroy()
			count += 1
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = getCharacter(player)
		if character then
			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant.Name:match("^Admin") then
					descendant:Destroy()
					count += 1
				end
			end
		end
	end
	for _, v in pairs(Workspace:GetChildren()) do
		if v:IsA("Tool") or v:IsA("BackpackItem") then
			v:Destroy()
			count += 1
		end
	end
	Commands.notify(sender, sender, {"Cleaned " .. count .. " items."})
end

Commands.rank = function(sender, target, args)
	local rankInput = args[1]
	if target and rankInput then
		local properRankName = nil
		for key, _ in pairs(Settings.Ranks) do if key:lower() == rankInput:lower() then properRankName = key; break end end
		if properRankName then
			Settings.PlayerRanks[target.Name] = properRankName
			Commands.notify(sender, sender, {"Set " .. target.Name .. " to rank: " .. properRankName})
		end
	end
end

Commands.unrank = function(sender, target, args)
	if target then Settings.PlayerRanks[target.Name] = nil; Commands.notify(sender, sender, {"Unranked " .. target.Name}) end
end

Commands.kick = function(sender, target, args)
	if target then
		local reason = table.concat(args, " ")
		if reason == "" then reason = "You have been kicked." end
		logAudit(sender, "kick", target, reason)
		target:Kick(reason)
	end
end

Commands.shutdown = function(sender, target, args)
	logAudit(sender, "shutdown", nil, "Server shutdown initiated by " .. sender.Name)
	for _, p in ipairs(Players:GetPlayers()) do
		local gui = getUiAsset("Shutdown", "ScreenGui")
		if gui then
			gui.Parent = p:FindFirstChild("PlayerGui")
			local frame = findElement(gui, "BackgroundFrame", "Frame") or gui:FindFirstChildOfClass("Frame")
			local label = findElement(gui, "MessageLabel", "TextLabel") or (frame and frame:FindFirstChildOfClass("TextLabel"))
			if frame then TweenService:Create(frame, TweenInfo.new(2), {BackgroundTransparency = 0}):Play() end
			if label then TweenService:Create(label, TweenInfo.new(2), {TextTransparency = 0}):Play() end
		else warn("Shutdown UI not found in AdminUiAssets!") end
	end
	task.wait(3)
	for _, p in ipairs(Players:GetPlayers()) do p:Kick("Server shutdown by " .. sender.Name) end
end

Commands.rejoin = function(sender, target, args) if sender then TeleportService:Teleport(game.PlaceId, sender) end end

Commands.kill = function(sender, target, args)
	if target.Character then target.Character:BreakJoints(); local humanoid = target.Character:FindFirstChildOfClass("Humanoid"); if humanoid and humanoid.Health > 0 then humanoid.Health = 0 end end
end

Commands.tkill = function(sender, target, args)
	local delayTime = tonumber(args[1]) or 1
	if target.Character then task.delay(delayTime, function() if target.Character then target.Character:BreakJoints(); local humanoid = target.Character:FindFirstChildOfClass("Humanoid"); if humanoid and humanoid.Health > 0 then humanoid.Health = 0 end end end) end
end

Commands.loopkill = function(sender, target, args)
	if target:GetAttribute("LoopKillActive") then return end
	target:SetAttribute("LoopKillActive", true)
	task.spawn(function()
		while target:GetAttribute("LoopKillActive") and target.Parent do
			if target.Character then target.Character:BreakJoints(); local hum = target.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.Health = 0 end end
			task.wait(0.8)
		end
	end)
end
Commands.unloopkill = function(sender, target, args) target:SetAttribute("LoopKillActive", false) end

Commands.damage = function(sender, target, args) local amt = tonumber(args[1]) or 10; local hum = getHumanoid(target); if hum then hum:TakeDamage(amt) end end
Commands.heal = function(sender, target, args) local hum = getHumanoid(target); if hum then hum.Health = hum.MaxHealth end end
Commands.health = function(sender, target, args) local amt = tonumber(args[1]); local hum = getHumanoid(target); if hum and amt then hum.MaxHealth = amt; hum.Health = amt end end
Commands.god = function(sender, target, args) local hum = getHumanoid(target); if hum then hum.MaxHealth = math.huge; hum.Health = math.huge end end
Commands.ungod = function(sender, target, args) local hum = getHumanoid(target); if hum then hum.MaxHealth = 100; hum.Health = 100 end end
Commands.speed = function(sender, target, args) local hum = getHumanoid(target); if hum then hum.WalkSpeed = tonumber(args[1]) or 16 end end
Commands.jump = function(sender, target, args) local hum = getHumanoid(target); if hum then hum.Jump = true end end
Commands.sit = function(sender, target, args) local hum = getHumanoid(target); if hum then hum.Sit = true end end

Commands.freeze = function(sender, target, args)
	if target.Character and target.Character.PrimaryPart then
		target.Character.PrimaryPart.Anchored = true
		local hum = target.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
	end
end
Commands.unfreeze = function(sender, target, args)
	if target.Character and target.Character.PrimaryPart then
		target.Character.PrimaryPart.Anchored = false
		local hum = target.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
		for _,p in pairs(target.Character:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = false end end
	end
end

Commands.char = function(sender, target, args)
	local userStr = args[1]
	if not userStr then return end
	if target.Character and target.Character:FindFirstChild("Humanoid") then
		local targetUserId = nil
		if tonumber(userStr) then targetUserId = tonumber(userStr) else
			local lowerStr = userStr:lower()
			for _, p in ipairs(Players:GetPlayers()) do if p.Name:lower():sub(1, #lowerStr) == lowerStr or p.DisplayName:lower():sub(1, #lowerStr) == lowerStr then targetUserId = p.UserId; break end end
			if not targetUserId then pcall(function() targetUserId = Players:GetUserIdFromNameAsync(userStr) end) end
		end
		if targetUserId then
			local success, err = pcall(function() local desc = Players:GetHumanoidDescriptionFromUserId(targetUserId); target.Character.Humanoid:ApplyDescription(desc) end)
			if not success then Commands.notify(sender, sender, {"Failed to load character appearance."}) end
		else Commands.notify(sender, sender, {"Could not find user: " .. userStr}) end
	end
end

Commands.invisible = function(sender, target, args) if target.Character then for _,v in pairs(target.Character:GetDescendants()) do if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Transparency = 1 end if v:IsA("Decal") then v.Transparency = 1 end end end end
Commands.visible = function(sender, target, args) if target.Character then for _,v in pairs(target.Character:GetDescendants()) do if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Transparency = 0 end if v:IsA("Decal") then v.Transparency = 0 end end end end

Commands.unaura = function(sender, target, args) if target.Character then for _,v in pairs(target.Character:GetChildren()) do if v.Name == "AuraHighlight" then v:Destroy() end end end end

Commands.light = function(sender, target, args) if target.Character and target.Character.PrimaryPart then local l = Instance.new("PointLight", target.Character.PrimaryPart); l.Range = 15; l.Brightness = 3; l.Name = "AdminLight" end end
Commands.unlight = function(sender, target, args) if target.Character and target.Character.PrimaryPart then local l = target.Character.PrimaryPart:FindFirstChild("AdminLight"); if l then l:Destroy() end end end

Commands.laydown = function(sender, target, args)
	local root = getRoot(target)
	local humanoid = getHumanoid(target)
	if not root or not humanoid then
		return
	end

	Commands.unlaydown(sender, target, args)
	cacheHumanoidState(target, "laydown")
	cachePose(target, "laydown")
	target:SetAttribute("LaydownActive", true)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	local forward = getHorizontalDirection(root.CFrame)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + forward) * CFrame.Angles(math.rad(90), 0, 0)
end

Commands.unlaydown = function(sender, target, args)
	target:SetAttribute("LaydownActive", false)
	local humanoid = getHumanoid(target)
	if humanoid then
		restoreHumanoidState(target, "laydown")
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	restorePose(target, "laydown")
end

local function sc(c, t, v) local h = c:FindFirstChild("Humanoid"); if h then local vo = h:FindFirstChild("Body"..t.."Scale"); if vo then vo.Value = v end end end
Commands.size = function(sender, target, args) local s = tonumber(args[1]) or 1; if target.Character then sc(target.Character, "Width", s); sc(target.Character, "Height", s); sc(target.Character, "Depth", s); local h = target.Character.Humanoid:FindFirstChild("HeadScale"); if h then h.Value = s end end end
Commands.thin = function(sender, target, args) if target.Character then sc(target.Character, "Width", 0.5); sc(target.Character, "Depth", 0.5) end end
Commands.unthin = function(sender, target, args) if target.Character then sc(target.Character, "Width", 1); sc(target.Character, "Depth", 1) end end
Commands.fat = function(sender, target, args) if target.Character then sc(target.Character, "Width", 1.5); sc(target.Character, "Depth", 1.5) end end
Commands.unfat = function(sender, target, args) if target.Character then sc(target.Character, "Width", 1); sc(target.Character, "Depth", 1) end end
Commands.width = function(sender, target, args) if target.Character then sc(target.Character, "Width", tonumber(args[1]) or 1) end end
Commands.height = function(sender, target, args) if target.Character then sc(target.Character, "Height", tonumber(args[1]) or 1) end end

Commands.to = function(sender, target, args)
	if sender.Character and target.Character then
		sender.Character:PivotTo(target.Character:GetPivot() * CFrame.new(0, 0, 3))
	end
end
Commands.bring = function(sender, target, args)
	if sender.Character and target.Character then
		teleportTarget(target, sender.Character:GetPivot() * CFrame.new(0, 0, 3))
	end
end
Commands.re = function(sender, target, args)
	if target.Character then
		local cf = target.Character:GetPivot()
		target:LoadCharacter()
		local newChar = target.Character or target.CharacterAdded:Wait()
		task.wait(0.1)
		newChar:PivotTo(cf)
	end
end
Commands.warp = function(sender, target, args)
	local dims = {["test"] = CFrame.new(100, 50, 100), ["ohio"] = CFrame.new(-1000, -500, -1000)}
	local dest = dims[tostring(args[1]):lower()]
	if target.Character and dest then
		teleportTarget(target, dest)
	end
end
Commands.gravity = function(sender, target, args) Workspace.Gravity = tonumber(args[1]) or 196.2 end

Commands.loadmap = function(sender, target, args)
	local backup = ServerStorage:FindFirstChild("AdminMapBackup")
	if not backup then Commands.notify(sender, sender, {"Map backup not found in ServerStorage!"}); return end
	for _, child in ipairs(Workspace:GetChildren()) do if not child:IsA("Camera") and not child:IsA("Terrain") and not Players:GetPlayerFromCharacter(child) then pcall(function() child:Destroy() end) end end
	for _, child in ipairs(backup:GetChildren()) do pcall(function() local clone = child:Clone(); if clone then clone.Parent = Workspace end end) end
	Commands.notify(sender, sender, {"The map has been successfully reloaded!"})
	for _, p in pairs(Players:GetPlayers()) do p:LoadCharacter() end
end

Commands.ff = function(sender, target, args) if target.Character then Instance.new("ForceField", target.Character) end end
Commands.unff = function(sender, target, args) if target.Character and target.Character:FindFirstChildOfClass("ForceField") then target.Character:FindFirstChildOfClass("ForceField"):Destroy() end end
Commands.hff = function(sender, target, args) if target.Character then local ff = target.Character:FindFirstChildOfClass("ForceField"); if ff then ff.Visible = false end end end

Commands.jail = function(sender, target, args)
	if not target.Character or not target.Character.PrimaryPart then return end
	if target:GetAttribute("IsJailed") then return end

	local f = Workspace:FindFirstChild("JailFolder") or Instance.new("Folder", Workspace); f.Name = "JailFolder"
	local jailModel = getAsset("Jail")

	if jailModel then
		jailModel.Name = "Jail_" .. target.Name
		jailModel.Parent = f

		local targetPos = target.Character.PrimaryPart.Position
		jailModel:PivotTo(CFrame.new(targetPos))

		local spawnLoc = findElement(jailModel, "JailSpawn")
		local tpCFrame = spawnLoc and (spawnLoc.CFrame * CFrame.new(0, 3, 0)) or (jailModel:GetPivot() * CFrame.new(0, 3, 0))
		target.Character:PivotTo(tpCFrame)

		target:SetAttribute("IsJailed", true)

		task.spawn(function()
			while target:GetAttribute("IsJailed") and target.Parent do
				if target.Character and target.Character.PrimaryPart then
					local dist = (target.Character.PrimaryPart.Position - tpCFrame.Position).Magnitude
					if dist > 5 then
						target.Character:PivotTo(tpCFrame)
					end
				end
				task.wait(0.25)
			end
		end)
	else
		Commands.notify(sender, sender, {"Jail model not found in AdminAssets!"})
	end
end

Commands.unjail = function(sender, target, args)
	target:SetAttribute("IsJailed", false)
	local f = Workspace:FindFirstChild("JailFolder")
	if f then 
		for _, p in pairs(f:GetChildren()) do 
			if p.Name == "Jail_" .. target.Name then p:Destroy() end 
		end 
		if #f:GetChildren() == 0 then f:Destroy() end
	end
end

Commands.explode = function(sender, target, args) local root = getRoot(target); if root then local e = Instance.new("Explosion", Workspace); e.Position = root.Position end end


Commands.fling = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local att = root:FindFirstChild("FlingAtt") or Instance.new("Attachment")
	att.Name = "FlingAtt"; att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "FlingVelocity"; lv.Attachment0 = att
	lv.MaxForce = 1e6; lv.VectorVelocity = Vector3.new(math.random(-500,500), 1000, math.random(-500,500))
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.Parent = root
	Debris:AddItem(lv, 0.1); Debris:AddItem(att, 0.15)
end

Commands.superf = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end

	local att = Instance.new("Attachment"); att.Name = "SuperFlingAtt"; att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Name = "SuperFlingVelocity"; lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.new(math.random(-200000,200000), 300000, math.random(-200000,200000))
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.Parent = root

	local av = Instance.new("AngularVelocity")
	av.Name = "SuperFlingSpin"; av.Attachment0 = att
	av.MaxTorque = math.huge
	av.AngularVelocity = Vector3.new(math.random(-1000,1000), math.random(-1000,1000), math.random(-1000,1000))
	av.RelativeTo = Enum.ActuatorRelativeTo.World; av.Parent = root

	Debris:AddItem(lv, 0.2); Debris:AddItem(av, 0.2); Debris:AddItem(att, 0.25)

	task.delay(0.25, function()
		local character = getCharacter(target)
		if character then
			character:PivotTo(CFrame.new(math.random(-1e7,1e7), math.random(1e6,5e6), math.random(-1e7,1e7)))
		end
	end)
end

Commands.spin = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	Commands.unspin(sender, target, args)
	local att = Instance.new("Attachment"); att.Name = "SpinAtt"; att.Parent = root
	local av = Instance.new("AngularVelocity")
	av.Name = "SpinVelocity"; av.Attachment0 = att
	av.MaxTorque = math.huge
	av.AngularVelocity = Vector3.new(0, (tonumber(args[1]) or 10) * 10, 0)
	av.RelativeTo = Enum.ActuatorRelativeTo.World; av.Parent = root
end

Commands.unspin = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local av = root:FindFirstChild("SpinVelocity"); if av then av:Destroy() end
	local att = root:FindFirstChild("SpinAtt"); if att then att:Destroy() end
end


Commands.spike = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end

	local spikesFolder = ensureWorkspaceFolder("Spikes")
	local existing = spikesFolder:FindFirstChild("AdminSpike_" .. target.UserId)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "AdminSpike_" .. target.UserId
	folder.Parent = spikesFolder

	local cleared = false
	local deathConnection
	local function clearSpikes()
		if cleared then
			return
		end
		cleared = true
		if deathConnection then
			deathConnection:Disconnect()
			deathConnection = nil
		end
		if folder.Parent then
			folder:Destroy()
		end
	end

	local humanoid = getHumanoid(target)
	if humanoid then
		deathConnection = humanoid.Died:Connect(clearSpikes)
	end
	task.delay(60, clearSpikes)

	local center = root.Position
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * 8, -2, math.sin(angle) * 8)
		local spike = Instance.new("WedgePart")
		spike.Name = "AdminSpike"
		spike.Size = Vector3.new(2.2, 10, 4.5)
		spike.Material = Enum.Material.Metal
		spike.Color = Color3.fromRGB(135, 18, 18)
		spike.Anchored = true
		spike.CanCollide = true
		spike.CFrame = CFrame.new(position, center) * CFrame.Angles(0, math.rad(90), 0)
		spike.Parent = folder
		spike.Touched:Connect(function(hit)
			local hitHumanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if hitHumanoid then
				hitHumanoid.Health = 0
			end
		end)
	end
end

Commands.unspike = function(sender, target, args)
	local spikesFolder = Workspace:FindFirstChild("AdminGenerated") and Workspace.AdminGenerated:FindFirstChild("Spikes")
	if spikesFolder then
		spikesFolder:Destroy()
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "AdminSpike" then
			descendant:Destroy()
		end
	end
end

Commands.rocket = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local att = Instance.new("Attachment"); att.Name = "RocketAtt"; att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "RocketVelocity"; lv.Attachment0 = att
	lv.MaxForce = 1e5; lv.VectorVelocity = Vector3.new(0, 100, 0)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.Parent = root
	task.spawn(function()
		task.wait(3)
		local currentRoot = getRoot(target)
		if currentRoot then
			local e = Instance.new("Explosion", Workspace); e.Position = currentRoot.Position
		end
		if lv and lv.Parent then lv:Destroy() end
		if att and att.Parent then att:Destroy() end
	end)
end
Commands.ls = function(sender, target, args)
	local root = getRoot(target)
	local humanoid = getHumanoid(target)
	if not root then return end

	local lightningFolder = ensureWorkspaceFolder("Lightning")
	local strikeFolder = Instance.new("Folder")
	strikeFolder.Name = "AdminLightning_" .. target.UserId
	strikeFolder.Parent = lightningFolder

	local targetPosition = root.Position + Vector3.new(0, 2, 0)
	local startPosition = targetPosition + Vector3.new(math.random(-3, 3), 24, math.random(-3, 3))
	local points = {startPosition}
	for step = 1, 5 do
		local alpha = step / 6
		local jitter = Vector3.new(math.random(-3, 3) * (1 - alpha), math.random(-1, 1), math.random(-3, 3) * (1 - alpha))
		table.insert(points, startPosition:Lerp(targetPosition, alpha) + jitter)
	end
	table.insert(points, targetPosition)

	for index = 1, #points - 1 do
		local segmentStart = points[index]
		local segmentEnd = points[index + 1]
		local distance = (segmentEnd - segmentStart).Magnitude
		local segment = Instance.new("Part")
		segment.Name = "AdminLightningSegment"
		segment.Size = Vector3.new(0.32, 0.32, distance)
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(232, 244, 255)
		segment.Anchored = true
		segment.CanCollide = false
		segment.CFrame = CFrame.lookAt(segmentStart, segmentEnd) * CFrame.new(0, 0, -(distance / 2))
		segment.Parent = strikeFolder
	end

	local flash = Instance.new("Part")
	flash.Name = "AdminLightningFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(4, 4, 4)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 247, 204)
	flash.Transparency = 0.2
	flash.Anchored = true
	flash.CanCollide = false
	flash.Position = targetPosition
	flash.Parent = strikeFolder

	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 18
	light.Color = Color3.fromRGB(240, 248, 255)
	light.Parent = flash

	if humanoid then
		humanoid:TakeDamage(50)
	end

	Debris:AddItem(strikeFolder, 0.35)
end

Commands.erain = function(sender, target, args)
	task.spawn(function()
		for _ = 1, 15 do
			local bomb = getAsset("Bomb")
			if bomb then
				bomb.Parent = Workspace
				local handle = bomb:FindFirstChildWhichIsA("BasePart")
				if handle then
					handle.Anchored = false
					handle.CanCollide = true
					handle.CFrame = CFrame.new(Vector3.new(math.random(-100, 100), 120, math.random(-100, 100)))
					handle.AssemblyLinearVelocity = Vector3.new(0, -80, 0)

					-- Trail of fire so the falling bomb is visible from the sky
					local fire = Instance.new("Fire")
					fire.Size = 4
					fire.Heat = 8
					fire.Parent = handle

					-- Debounced explosion so the bomb only blows up once
					local exploded = false
					handle.Touched:Connect(function()
						if exploded then return end
						exploded = true
						local e = Instance.new("Explosion")
						e.Position = handle.Position
						e.BlastRadius = 8
						e.BlastPressure = 50000
						e.Parent = Workspace
						task.delay(0.05, function()
							if bomb.Parent then bomb:Destroy() end
						end)
					end)

					-- Safety: clean up the bomb if it never lands
					Debris:AddItem(bomb, 10)
				else
					bomb:Destroy()
				end
			else
				-- Fallback: plain red block with explosion on touch
				local p = Instance.new("Part")
				p.BrickColor = BrickColor.Red()
				p.Position = Vector3.new(math.random(-100, 100), 120, math.random(-100, 100))
				p.Anchored = false
				p.Parent = Workspace
				p.AssemblyLinearVelocity = Vector3.new(0, -80, 0)
				local exploded = false
				p.Touched:Connect(function()
					if exploded then return end
					exploded = true
					local e = Instance.new("Explosion", Workspace)
					e.Position = p.Position
					task.delay(0.05, function() p:Destroy() end)
				end)
				Debris:AddItem(p, 10)
			end
			task.wait(0.3)
		end
	end)
end

Commands.gflip = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	root.CFrame *= CFrame.Angles(math.pi, 0, 0)
	local att = Instance.new("Attachment"); att.Name = "GFlipAtt"; att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "GFlipVelocity"; lv.Attachment0 = att
	lv.MaxForce = math.huge; lv.VectorVelocity = Vector3.new(0, 50, 0)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.Parent = root
	Debris:AddItem(lv, 3); Debris:AddItem(att, 3.05)
end
Commands.flip = function(sender, target, args) local root = getRoot(target); if root then root.CFrame *= CFrame.Angles(math.pi, 0, 0) end end

Commands.kaura = function(sender, target, args)
	if target.Character and target.Character.PrimaryPart then
		local character = target.Character
		local aura = Instance.new("Part"); aura.Shape = Enum.PartType.Ball; aura.Size = Vector3.new(15, 15, 15); aura.Transparency = 0.6; aura.BrickColor = BrickColor.new("Bright red"); aura.Material = Enum.Material.SmoothPlastic; aura.CanCollide = false; aura.Anchored = true; aura.Name = "KillAura_" .. target.Name; aura.Parent = workspace
		task.spawn(function()
			while aura.Parent and character and character.PrimaryPart do
				aura.Position = character.PrimaryPart.Position
				for _, p in pairs(Players:GetPlayers()) do
					if p ~= target and p.Character and p.Character.PrimaryPart then
						if (p.Character.PrimaryPart.Position - aura.Position).Magnitude <= 10 then local humanoid = p.Character:FindFirstChildOfClass("Humanoid"); if humanoid and humanoid.Health > 0 then humanoid.Health = 0; p.Character:BreakJoints() end end
					end
				end
				task.wait(0.1)
			end
			if aura then aura:Destroy() end
		end)
		Debris:AddItem(aura, 30); target.CharacterRemoving:Connect(function() if aura and aura.Parent then aura:Destroy() end end)
	end
end

Commands.blackhole = function(sender, target, args)
	if not (target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end

	local workspace = game:GetService("Workspace")
	local debris = game:GetService("Debris")
	local players = game:GetService("Players")

	local blackHole = Instance.new("Part")
	blackHole.Shape = Enum.PartType.Ball
	blackHole.Size = Vector3.new(6, 6, 6)
	blackHole.BrickColor = BrickColor.new("Really black")
	blackHole.Material = Enum.Material.Neon
	blackHole.Anchored = true
	blackHole.CanCollide = false
	blackHole.Position = target.Character.HumanoidRootPart.Position
	blackHole.Parent = workspace

	local radius = 80
	local duration = 8

	task.spawn(function()
		for i = 1, duration * 30 do
			for _, player in ipairs(players:GetPlayers()) do
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local hrp = player.Character.HumanoidRootPart
					local dist = (blackHole.Position - hrp.Position).Magnitude

					if dist <= radius then
						local strength = (radius - dist) / radius

						local targetPos = blackHole.Position
						hrp.CFrame = hrp.CFrame:Lerp(
							CFrame.new(targetPos),
							0.1 + (strength * 0.35)
						)

						local hum = player.Character:FindFirstChildOfClass("Humanoid")
						if hum then
							hum:TakeDamage(1 + (strength * 4))
						end
					end
				end
			end
			task.wait(0.03)
		end
	end)

	debris:AddItem(blackHole, duration)
end

Commands.npc = function(sender, target, args)
	if target.Character and target.Character.PrimaryPart then
		local npc = getAsset("Player") 
		if npc then 
			npc.Parent = Workspace
			npc:PivotTo(target.Character:GetPivot() * CFrame.new(0, 0, -10))
		else
			Commands.notify(sender, sender, {"Player model not found in AdminAssets!"})
		end
	end
end

Commands.fly = function(sender, target, args) ClientAction:FireClient(target, "fly", true) end
Commands.unfly = function(sender, target, args) ClientAction:FireClient(target, "fly", false) end
Commands.noclip = function(sender, target, args) ClientAction:FireClient(target, "noclip", true) end
Commands.clip = function(sender, target, args) ClientAction:FireClient(target, "noclip", false) end
Commands.mute = function(sender, target, args) ClientAction:FireClient(target, "mute", true) end
Commands.unmute = function(sender, target, args) ClientAction:FireClient(target, "mute", false) end
Commands.blind = function(sender, target, args) ClientAction:FireClient(target, "blind", true) end
Commands.unblind = function(sender, target, args) ClientAction:FireClient(target, "blind", false) end
Commands.flashbang = function(sender, target, args) ClientAction:FireClient(target, "flashbang", true) end

Commands.talk = function(sender, target, args) local msg = table.concat(args, " "); if target.Character and target.Character:FindFirstChild("Head") then ChatService:Chat(target.Character.Head, msg, Enum.ChatColor.White) end end
Commands.team = function(sender, target, args)
	ClientAction:FireClient(sender, "ShowTeamCreator")
end

Commands.untitle = function(sender, target, args) if target.Character and target.Character:FindFirstChild("Head") then local t = target.Character.Head:FindFirstChild("TitleGui"); if t then t:Destroy() end end end

Commands.smoke = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local _, smokeColor = consumeColorArgs(args, 1, 3)
	if not smokeColor then
		_, smokeColor = getDefaultColor(nil, "white")
	end
	Commands.unsmoke(sender, target, args)
	local smoke = Instance.new("Smoke")
	smoke.Name = "AdminSmoke"
	smoke.Color = smokeColor
	smoke.Opacity = 0.72
	smoke.RiseVelocity = 3
	smoke.Size = 9
	smoke.Parent = root
end

Commands.unsmoke = function(sender, target, args) if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then local smoke = target.Character.HumanoidRootPart:FindFirstChild("AdminSmoke"); if smoke then smoke:Destroy() end end end

Commands.fire = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local _, fireColor = consumeColorArgs(args, 1, 3)
	if not fireColor then
		_, fireColor = getDefaultColor(nil, "orange")
	end
	Commands.unfire(sender, target, args)
	local fire = Instance.new("Fire")
	fire.Name = "AdminFire"
	fire.Color = fireColor
	fire.SecondaryColor = mixColor(fireColor, Color3.new(1, 1, 0.8), 0.55)
	fire.Heat = 10
	fire.Size = 8
	fire.Parent = root
end

Commands.unfire = function(sender, target, args) if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then local fire = target.Character.HumanoidRootPart:FindFirstChild("AdminFire"); if fire then fire:Destroy() end end end

Commands.cmds = function(sender, target, args)
	ClientAction:FireClient(sender, "ShowCmds", {
		Commands = Settings.Commands,
		Count = Settings.TotalCommands,
	})
end

Commands.rlist = function(sender, target, args)
	local list = {}
	for _, p in pairs(game.Players:GetPlayers()) do
		table.insert(list, p.Name .. " - " .. Util.GetRank(p))
	end
	ClientAction:FireClient(sender, "ShowList", {Title = "Player Ranks", Data = list})
end

Commands.crl = function(sender, target, args)
	local list = {}
	for _, entry in ipairs(Settings.Commands or {}) do
		table.insert(list, string.format("%s%s - Requires: %s", Settings.Prefix, entry.Name, entry.Rank))
	end
	ClientAction:FireClient(sender, "ShowList", {Title = "Command Permissions", Data = list})
end

Commands.logs = function(sender, target, args, context)
	local logs = (context and context.Logs) or getSessionState().CommandLogs
	ClientAction:FireClient(sender, "UpdateLogs", {
		Logs = logs,
		Count = #logs,
	})
end

Commands.sparkles = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local _, sparkleColor = consumeColorArgs(args, 1, 3)
	if not sparkleColor then
		_, sparkleColor = getDefaultColor(nil, "white")
	end
	Commands.unsparkles(sender, target, args)
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "AdminSparkles"
	sparkles.SparkleColor = sparkleColor
	sparkles.Parent = root
end

Commands.unsparkles = function(sender, target, args) if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then local sparkles = target.Character.HumanoidRootPart:FindFirstChild("AdminSparkles"); if sparkles then sparkles:Destroy() end end end

Commands.trail = function(sender, target, args)
	local root = getRoot(target)
	if not root then
		return
	end

	Commands.untrail(sender, target, args)

	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "AdminTrailStart"
	startAttachment.Position = Vector3.new(0, 1.1, 0)
	startAttachment.Parent = root

	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "AdminTrailEnd"
	endAttachment.Position = Vector3.new(0, -1.6, 0)
	endAttachment.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "AdminTrail"
	trail.Attachment0 = startAttachment
	trail.Attachment1 = endAttachment
	trail.Lifetime = 0.55
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.9
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = root

	local normalizedFirst = Util.NormalizeColorToken(args[1] or "")
	if normalizedFirst == "rainbow" then
		runTargetLoop(target, "trailrainbow", 0.08, function()
			local hue = (os.clock() * 0.45) % 1
			trail.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, 0.95, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromHSV((hue + 0.18) % 1, 0.95, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV((hue + 0.36) % 1, 0.95, 1)),
			})
		end)
		return
	end

	local _, primaryColor, consumed = consumeColorArgs(args, 1, 3)
	local _, secondaryColor = consumeColorArgs(args, consumed + 1, 3)
	if not primaryColor then
		primaryColor = Settings.Colors.cyan or Color3.fromRGB(0, 255, 255)
	end
	if not secondaryColor then
		secondaryColor = primaryColor
	end
	trail.Color = ColorSequence.new(primaryColor, secondaryColor)
end
Commands.untrail = function(sender, target, args) if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then Util.StopLoop(target, "trailrainbow"); local hrp = target.Character.HumanoidRootPart; local trail = hrp:FindFirstChild("AdminTrail"); if trail then trail:Destroy() end; local att0 = hrp:FindFirstChild("AdminTrailStart") or hrp:FindFirstChild("TrailAttachment0"); if att0 then att0:Destroy() end; local att1 = hrp:FindFirstChild("AdminTrailEnd") or hrp:FindFirstChild("TrailAttachment1"); if att1 then att1:Destroy() end end end

Commands.bighead = function(sender, target, args)
	if target.Character then
		local hum = target.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum:FindFirstChild("HeadScale") then hum.HeadScale.Value = 3 else
			local head = target.Character:FindFirstChild("Head")
			if head then head.Size = Vector3.new(2.4, 1.2, 1.2) * 3; for _, v in pairs(head:GetChildren()) do if v:IsA("SpecialMesh") or v:IsA("BlockMesh") or v:IsA("CylinderMesh") then v.Scale = Vector3.new(3, 3, 3) end end end
		end
	end
end

Commands.dwarf = function(sender, target, args) if target.Character then local hum = target.Character:FindFirstChildOfClass("Humanoid"); if hum then local ws, hs, ds = hum:FindFirstChild("BodyWidthScale"), hum:FindFirstChild("BodyHeightScale"), hum:FindFirstChild("BodyDepthScale"); if ws then ws.Value = 0.5 end; if hs then hs.Value = 0.5 end; if ds then ds.Value = 0.5 end end end end
Commands.giant = function(sender, target, args) if target.Character then local hum = target.Character:FindFirstChildOfClass("Humanoid"); if hum then local ws, hs, ds = hum:FindFirstChild("BodyWidthScale"), hum:FindFirstChild("BodyHeightScale"), hum:FindFirstChild("BodyDepthScale"); if ws then ws.Value = 2 end; if hs then hs.Value = 2 end; if ds then ds.Value = 2 end end end end

Commands.clone = function(sender, target, args)
	if target.Character then
		target.Character.Archivable = true; local clone = target.Character:Clone(); target.Character.Archivable = false; clone.Name = target.Name .. "_Clone"; clone.Parent = Workspace; clone:PivotTo(target.Character:GetPivot() * CFrame.new(5,0,0))
		if clone:FindFirstChildOfClass("Humanoid") then clone:FindFirstChildOfClass("Humanoid").DisplayName = target.Name .. "" end
	end
end

Commands.prefix = function(sender, target, args)
	local newPrefix = tostring(args[1])
	if not newPrefix or newPrefix == "" then local currentPrefix = sender:GetAttribute("CustomPrefix") or Settings.Prefix; Commands.notify(sender, sender, {"Your current prefix: " .. currentPrefix}); return end
	if #newPrefix > 3 then Commands.notify(sender, sender, {"Prefix too long! Maximum 3 characters."}); return end
	sender:SetAttribute("CustomPrefix", newPrefix); Commands.notify(sender, sender, {"Prefix set to: " .. newPrefix .. " (Example: " .. newPrefix .. "kill me)"})
end

Commands.headless = function(sender, target, args)
	if target.Character then
		local head = target.Character:FindFirstChild("Head")
		if head then head.Transparency = 1; for _, v in pairs(head:GetChildren()) do if v:IsA("Decal") then v.Transparency = 1 end end end
	end
end
Commands.unheadless = function(sender, target, args)
	if target.Character then
		local head = target.Character:FindFirstChild("Head")
		if head then head.Transparency = 0; for _, v in pairs(head:GetChildren()) do if v:IsA("Decal") then v.Transparency = 0 end end end
	end
end

-- // PERMANENT RANK SYSTEM //
local DataStoreService = game:GetService("DataStoreService")
local PermRankStore = DataStoreService:GetDataStore("PermanentRanks_v1")
local PermanentRanks = {}

local function loadPermanentRank(player)
	local success, data = pcall(function() return PermRankStore:GetAsync("rank_" .. player.UserId) end)
	if success and data then PermanentRanks[player.UserId] = data; Settings.PlayerRanks[player.Name] = data; return data end return nil
end

local function savePermanentRank(player, rankName) return pcall(function() PermRankStore:SetAsync("rank_" .. player.UserId, rankName) end) end
local function removePermanentRank(player) local success = pcall(function() PermRankStore:SetAsync("rank_" .. player.UserId, nil) end); if success then PermanentRanks[player.UserId] = nil end return success end

Commands.permrank = function(sender, target, args)
	local rankInput = args[1]
	if not target or not rankInput then Commands.notify(sender, sender, {"Usage: ;permrank <player> <rank>"}); return end
	local properRankName = nil
	for key, _ in pairs(Settings.Ranks) do if key:lower() == rankInput:lower() then properRankName = key; break end end
	if not properRankName then Commands.notify(sender, sender, {"Invalid rank: " .. rankInput}); return end
	if savePermanentRank(target, properRankName) then
		PermanentRanks[target.UserId] = properRankName; Settings.PlayerRanks[target.Name] = properRankName; Commands.notify(sender, sender, {"Permanently set " .. target.Name .. " to rank: " .. properRankName}); Commands.notify(target, target, {"Your rank has been permanently set to: " .. properRankName})
	else Commands.notify(sender, sender, {"Failed to save rank. Please try again."}) end
end

Commands.unpermrank = function(sender, target, args)
	if not target then return end
	if removePermanentRank(target) then Settings.PlayerRanks[target.Name] = nil; Commands.notify(sender, sender, {"Removed permanent rank from " .. target.Name}) else Commands.notify(sender, sender, {"Failed to remove rank. Please try again."}) end
end

task.spawn(function()
	for _, player in pairs(Players:GetPlayers()) do loadPermanentRank(player) end
	Players.PlayerAdded:Connect(function(player) local rank = loadPermanentRank(player); if rank then print("[PermRank] Loaded rank for " .. player.Name .. ": " .. rank) end end)
end)

Commands.image = function(sender, target, args)
	local rawInput = tostring(args[1] or "")
	if rawInput == "" or rawInput == "nil" then Commands.notify(sender, sender, {"Provide an Image ID!"}); return end
	local imageId = string.match(rawInput, "%d+") 
	if not imageId then Commands.notify(sender, sender, {"Invalid Image ID!"}); return end
	ClientAction:FireClient(target, "chatimage", { Sender = sender.Name, ImageId = imageId })
end

Commands.r6 = function(sender, target, args)
	target:SetAttribute("ForcedRig", "R6")
	local desc = Players:GetHumanoidDescriptionFromUserId(target.UserId)
	local newChar = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	newChar.Name = target.Name
	newChar:PivotTo(target.Character and target.Character:GetPivot() or CFrame.new(0,10,0))
	target.Character = newChar
	newChar.Parent = Workspace
	Commands.notify(sender, sender, {"Forced " .. target.Name .. " to R6"})
end

Commands.r15 = function(sender, target, args)
	target:SetAttribute("ForcedRig", "R15")
	local desc = Players:GetHumanoidDescriptionFromUserId(target.UserId)
	local newChar = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	newChar.Name = target.Name
	newChar:PivotTo(target.Character and target.Character:GetPivot() or CFrame.new(0,10,0))
	target.Character = newChar
	newChar.Parent = Workspace
	Commands.notify(sender, sender, {"Forced " .. target.Name .. " to R15"})
end

Commands.magnetize = function(sender, target)
	task.spawn(function()
		for i = 1, 50 do
			for _, p in pairs(game.Players:GetPlayers()) do
				if p ~= target and p.Character then
					local r = p.Character:FindFirstChild("HumanoidRootPart")
					local t = target.Character:FindFirstChild("HumanoidRootPart")
					if r and t then r.AssemblyLinearVelocity = (t.Position - r.Position).Unit * 40 end
				end
			end
			task.wait(0.1)
		end
	end)
end

Commands.swap = function(sender, target, args)
	local allPlayers = Players:GetPlayers()
	local otherPlayers = {}
	for _, p in ipairs(allPlayers) do if p ~= sender and p.Character and p.Character.PrimaryPart then table.insert(otherPlayers, p) end end
	if #otherPlayers == 0 then Commands.notify(sender, sender, {"No other players found to swap with!"}); return end
	local randomPlayer = otherPlayers[math.random(1, #otherPlayers)]
	if sender.Character and sender.Character.PrimaryPart then
		local myCFrame = sender.Character:GetPivot()
		local theirCFrame = randomPlayer.Character:GetPivot()
		sender.Character:PivotTo(theirCFrame)
		randomPlayer.Character:PivotTo(myCFrame)
		Commands.notify(sender, sender, {"Swapped positions with " .. randomPlayer.Name}); Commands.notify(randomPlayer, randomPlayer, {"Your position was swapped with Admin " .. sender.Name})
	else Commands.notify(sender, sender, {"You need a character to use this command."}) end
end

Commands.control = function(sender, target, args)
	if sender == target or not target.Character or not sender.Character then return end
	ControlCache[sender.UserId] = { Char = sender.Character, CFrame = sender.Character:GetPivot() }
	if sender.Character.PrimaryPart then sender.Character.PrimaryPart.Anchored = true; sender.Character:PivotTo(CFrame.new(0, 500000, 0)) end
	local victimChar = target.Character; sender.Character = victimChar
	ClientAction:FireClient(sender, "updateCharacterState", { Char = victimChar, IsControlling = true })
	ClientAction:FireClient(target, "setControlState", false)
	Commands.notify(sender, sender, {"Controlling " .. target.Name})
end

Commands.uncontrol = function(sender, target, args)
	local cache = ControlCache[sender.UserId]
	if not cache then return end
	local victim = Players:GetPlayerFromCharacter(sender.Character)
	if victim then victim.Character = sender.Character; ClientAction:FireClient(victim, "setControlState", true) end
	local originalBody = cache.Char
	if originalBody and originalBody.Parent then
		if originalBody.PrimaryPart then originalBody.PrimaryPart.Anchored = false; originalBody:PivotTo(cache.CFrame) end
		sender.Character = originalBody
		ClientAction:FireClient(sender, "updateCharacterState", { Char = originalBody, IsControlling = false })
	end
	ControlCache[sender.UserId] = nil
	Commands.notify(sender, sender, {"Returned to original body."})
end

local function setScreenEffect(target, effectName, enabled, properties)
	ClientAction:FireClient(target, "screenEffect", {
		Effect = effectName,
		Enabled = enabled,
		Properties = properties,
	})
end

local function removeCharacterNames(target, names)
	local character = getCharacter(target)
	if character then
		Util.DestroyNamed(character, names)
	end
end

local function forCharacterParts(target, callback)
	local character = getCharacter(target)
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			callback(descendant)
		end
	end
end

local function sanitizeCommandToken(token)
	return tostring(token or ""):gsub("^;+", ""):gsub("^%(", ""):gsub("%)$", ""):match("^%s*(.-)%s*$")
end

local function restoreLightingDefaults()
	for propertyName, value in pairs(LightingDefaults) do
		Lighting[propertyName] = value
	end
end

Commands.whois = function(sender, target, args)
	local info = {
		"Name: " .. target.Name,
		"Display Name: " .. target.DisplayName,
		"UserId: " .. target.UserId,
		"Rank: " .. Util.GetRank(target),
		"Account Age: " .. tostring(target.AccountAge) .. " days",
		"Team: " .. ((target.Team and target.Team.Name) or "None"),
	}
	ClientAction:FireClient(sender, "ShowList", {Title = "Who Is " .. target.Name, Data = info})
end

Commands.lockcmds = function(sender, target, args)
	local session = getSessionState()
	local requestedCommand = sanitizeCommandToken(args[1])
	if not requestedCommand or requestedCommand == "" then
		session.GlobalCommandLock = true
		table.clear(session.LockedCommands)
		Commands.notify(sender, sender, {"All commands locked for non-exempt players."})
		return
	end
	if requestedCommand:lower() == "all" then
		session.GlobalCommandLock = true
		table.clear(session.LockedCommands)
		Commands.notify(sender, sender, {"All commands locked for non-exempt players."})
		return
	end

	local resolution = Util.ResolveCommandInput(requestedCommand)
	local canonical = resolution and resolution.Canonical
	if not canonical or not Settings.CommandRegistry[canonical] then
		Commands.notify(sender, sender, {"Unknown command: " .. requestedCommand})
		return
	end

	session.LockedCommands[canonical] = true
	Commands.notify(sender, sender, {"Locked command: " .. canonical})
end

Commands.unlockcmds = function(sender, target, args)
	local session = getSessionState()
	local requestedCommand = sanitizeCommandToken(args[1])
	if not requestedCommand or requestedCommand == "" then
		session.GlobalCommandLock = false
		table.clear(session.LockedCommands)
		Commands.notify(sender, sender, {"All command locks cleared."})
		return
	end
	if requestedCommand:lower() == "all" then
		session.GlobalCommandLock = false
		table.clear(session.LockedCommands)
		Commands.notify(sender, sender, {"All command locks cleared."})
		return
	end

	local resolution = Util.ResolveCommandInput(requestedCommand)
	local canonical = resolution and resolution.Canonical
	if not canonical or not Settings.CommandRegistry[canonical] then
		Commands.notify(sender, sender, {"Unknown command: " .. requestedCommand})
		return
	end

	session.LockedCommands[canonical] = nil
	Commands.notify(sender, sender, {"Unlocked command: " .. canonical})
end

Commands.clearlogs = function(sender, target, args)
	local session = getSessionState()
	table.clear(session.CommandLogs)
	session.NextLogId = 1
	Commands.notify(sender, sender, {"Cleared the command log."})
end

Commands.blur = function(sender, target, args)
	local requestedSize = tonumber(args[1]) or 24
	setScreenEffect(target, "blur", true, {
		Size = math.clamp(requestedSize, 0, 56),
	})
end

Commands.unblur = function(sender, target, args) setScreenEffect(target, "blur", false) end
Commands.colorcorrection = function(sender, target, args) setScreenEffect(target, "colorcorrection", true) end
Commands.uncolorcorrection = function(sender, target, args) setScreenEffect(target, "colorcorrection", false) end

Commands.anchor = function(sender, target, args)
	local character = getCharacter(target)
	if not character then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

Commands.unanchor = function(sender, target, args)
	local character = getCharacter(target)
	if not character then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

Commands.slippery = function(sender, target, args)
	local character = getCharacter(target)
	local root = getRoot(target)
	local humanoid = getHumanoid(target)
	if not character or not root or not humanoid then return end
	Commands.unslippery(sender, target, args)
	Util.CachePhysicalProperties(character, "slippery")
	forCharacterParts(target, function(part)
		part.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0, 0.1, 1, 1)
	end)
	local momentum = SlipperyMomentumCache[target.UserId] or Vector3.zero
	runTargetLoop(target, "slippery", 0.05, function()
		local activeRoot = getRoot(target)
		local activeHumanoid = getHumanoid(target)
		if not activeRoot or not activeHumanoid then return end

		local moveDirection = activeHumanoid.MoveDirection
		if moveDirection.Magnitude > 0.05 then
			local goalVelocity = moveDirection.Unit * math.max(activeHumanoid.WalkSpeed, 12) * 1.2
			momentum = momentum:Lerp(goalVelocity, 0.28)
		else
			momentum *= 0.96
		end

		SlipperyMomentumCache[target.UserId] = momentum
		local currentVelocity = activeRoot.AssemblyLinearVelocity
		activeRoot.AssemblyLinearVelocity = Vector3.new(momentum.X, currentVelocity.Y, momentum.Z)
	end, function()
		SlipperyMomentumCache[target.UserId] = nil
	end)
end

Commands.unslippery = function(sender, target, args)
	local character = getCharacter(target)
	if character then Util.RestorePhysicalProperties(character, "slippery") end
	SlipperyMomentumCache[target.UserId] = nil
	Util.StopLoop(target, "slippery")
end

Commands.trip = function(sender, target, args)
	local humanoid = getHumanoid(target)
	local root = getRoot(target)
	if not humanoid or not root then return end
	cacheHumanoidState(target, "trip")
	humanoid.PlatformStand = true
	root.CFrame *= CFrame.Angles(math.rad(90), 0, 0)
	task.delay(2, function()
		restoreHumanoidState(target, "trip")
	end)
end

Commands.slam = function(sender, target, args)
	local root = getRoot(target)
	if not root then return end
	local att = Instance.new("Attachment"); att.Name = "SlamAtt"; att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SlamVelocity"; lv.Attachment0 = att
	lv.MaxForce = math.huge; lv.VectorVelocity = Vector3.new(0, -math.abs(tonumber(args[1]) or 150), 0)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.Parent = root
	Debris:AddItem(lv, 0.25); Debris:AddItem(att, 0.3)
end

Commands.follow = function(sender, target, args)
	runTargetLoop(target, "follow", 0.1, function()
		if not sender.Character or not target.Character then return end
		local senderRoot = getRoot(sender)
		if senderRoot then
			local destination = senderRoot.CFrame * CFrame.new(0, 0, 4)
			teleportTarget(target, destination)
		end
	end)
end

Commands.unfollow = function(sender, target, args)
	Util.StopLoop(target, "follow")
end

Commands.stack = function(sender, target, args, context)
	local senderRoot = getRoot(sender)
	if not senderRoot then return end
	local height = ((context and context.TargetIndex) or 1) * 5
	teleportTarget(target, CFrame.new(senderRoot.Position + Vector3.new(0, height, 0)))
end

Commands.noarms = function(sender, target, args)
	forCharacterParts(target, function(part)
		if part.Name:find("Arm") or part.Name:find("Hand") then
			part.Transparency = 1
			part.CanCollide = false
		end
	end)
end

Commands.nolegs = function(sender, target, args)
	forCharacterParts(target, function(part)
		if part.Name:find("Leg") or part.Name:find("Foot") then
			part.Transparency = 1
			part.CanCollide = false
		end
	end)
end

local function attachHeadParts(target, name, builder)
	local character = getCharacter(target)
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	removeCharacterNames(target, {name})
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = head
	builder(folder, head)
end

local function attachTorsoParts(target, name, builder)
	local torso = getTorso(target)
	if not torso then return end
	removeCharacterNames(target, {name})
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = torso
	builder(folder, torso)
end

-- Attach a Model from AdminAssets to a character body part.
-- modelName: child name in ReplicatedStorage.AdminAssets
-- attachPartName: which body part to weld to (e.g., "Head" or "UpperTorso")
-- folderName: name of the folder the welded parts live under on the body part
-- colorOverride (optional): Color3 - applied to every BasePart in the model
-- customMountOffset (optional): CFrame - rigidly binds PrimaryPart to attachTo at this specific offset
local function attachAccessoryModel(target, folderName, modelName, attachPartName, colorOverride, customMountOffset)
	local character = getCharacter(target)
	if not character then return end
	local attachTo = character:FindFirstChild(attachPartName)
	if not attachTo then return end

	removeCharacterNames(target, {folderName})

	local template = getAsset(modelName)
	if not template then
		Commands.notify(target, target, {modelName .. " model not found in AdminAssets!"})
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = attachTo

	local primary = template.PrimaryPart or template:FindFirstChildWhichIsA("BasePart")
	local rootCF = (primary and primary.CFrame) or CFrame.new()

	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local clone = descendant:Clone()
			clone.Anchored = false
			clone.CanCollide = false
			clone.Massless = true
			clone.CastShadow = false

			if customMountOffset and primary then
				-- Normalizes relative to PrimaryPart: completely immune to any dragging or world offset in Studio!
				local relCF = rootCF:ToObjectSpace(descendant.CFrame)
				clone.CFrame = (attachTo.CFrame * customMountOffset) * relCF
			else
				clone.CFrame = attachTo.CFrame * descendant.CFrame
			end

			if colorOverride then
				clone.Color = colorOverride
			end
			clone.Parent = folder

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = clone
			weld.Part1 = attachTo
			weld.Parent = clone
		end
	end

	template:Destroy()
end

Commands.halo = function(sender, target, args)
	local _, haloColor = consumeColorArgs(args, 1, 3)
	if not haloColor then
		_, haloColor = getDefaultColor(nil, "gold")
	end
	attachAccessoryModel(target, "AdminHalo", "Halo", "Head", haloColor)
end

Commands.unhalo = function(sender, target, args) removeCharacterNames(target, {"AdminHalo"}) end

Commands.horns = function(sender, target, args)
	local _, hornColor = consumeColorArgs(args, 1, 3)
	if not hornColor then
		_, hornColor = getDefaultColor(nil, "dgray")
	end
	attachAccessoryModel(target, "AdminHorns", "Horns", "Head", hornColor)
end

Commands.unhorns = function(sender, target, args) removeCharacterNames(target, {"AdminHorns"}) end

Commands.wings = function(sender, target, args)
	-- No color arg: wings keep their built-in celestial feather gradient.
	-- Rigidly anchored to the back between shoulder blades (+0.55 in Z, rotated 180 deg around Y)
	local backOffsetR15 = CFrame.new(0, -0.15, 0.55) * CFrame.Angles(0, math.rad(180), 0)
	local backOffsetR6 = CFrame.new(0, 0.20, 0.55) * CFrame.Angles(0, math.rad(180), 0)

	attachAccessoryModel(target, "AdminWings", "Wings", "UpperTorso", nil, backOffsetR15)
	-- Fallback for R6 rigs: Torso center is at waist, so upper back is Y = +0.20
	local character = getCharacter(target)
	if character and not character:FindFirstChild("AdminWings", true) then
		attachAccessoryModel(target, "AdminWings", "Wings", "Torso", nil, backOffsetR6)
	end
end

Commands.unwings = function(sender, target, args) removeCharacterNames(target, {"AdminWings"}) end

Commands.cape = function(sender, target, args)
	local _, capeColor = consumeColorArgs(args, 1, 3)
	if not capeColor then
		_, capeColor = getDefaultColor(nil, "red")
	end

	attachTorsoParts(target, "AdminCape", function(folder, torso)
		-- 1. Create the Collar (Rigidly welded to the torso)
		createWeldedPart(folder, "Part", "CapeCollar", torso, {
			Size = Vector3.new(2.25, 0.28, 0.45),
			Material = Enum.Material.SmoothPlastic,
			Color = mixColor(capeColor, Color3.new(0, 0, 0), 0.15),
			CFrame = torso.CFrame * CFrame.new(0, 0.72, 0.6),
		})

		local foldColor = mixColor(capeColor, Color3.new(0, 0, 0), 0.08)

		-- 2. Helper function to create a "Row" of the cape (Main piece + Left/Right folds)
		local function createCapeRow(name)
			local main = Instance.new("Part")
			main.Name = name .. "_Main"
			main.Size = Vector3.new(3.15, 1.6, 0.18) -- 1/3rd of the 4.8 total height
			main.Material = Enum.Material.SmoothPlastic
			main.Color = capeColor
			main.CanCollide = false
			main.Massless = false -- False allows it to have natural gravity!
			-- Extremely light density, 0 elasticity to prevent bouncing
			main.CustomPhysicalProperties = PhysicalProperties.new(0.05, 0.1, 0, 1, 1)
			main.Parent = folder

			local function addFold(sideName, xDir, yawAngle)
				local fold = Instance.new("Part")
				fold.Name = name .. "_" .. sideName
				fold.Size = Vector3.new(1.05, 1.6, 0.16)
				fold.Material = Enum.Material.SmoothPlastic
				fold.Color = foldColor
				fold.CanCollide = false
				fold.Massless = false
				fold.CustomPhysicalProperties = PhysicalProperties.new(0.05, 0.1, 0, 1, 1)

				-- We only angle the Yaw (Y-axis) so the vertical edges stay perfectly flush with the other rows
				fold.CFrame = main.CFrame * CFrame.new(1.1 * xDir, 0, 0.08) * CFrame.Angles(0, yawAngle, 0)
				fold.Parent = folder

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = fold
				weld.Part1 = main
				weld.Parent = fold
			end

			-- Add the flared sides
			addFold("FoldL", -1, math.rad(-10))
			addFold("FoldR", 1, math.rad(10))

			return main
		end

		-- 3. Create the 3 segments
		local topRow = createCapeRow("CapeTop")
		local midRow = createCapeRow("CapeMid")
		local botRow = createCapeRow("CapeBot")

		-- Pre-position them perfectly stacked to prevent violent snapping when they spawn
		topRow.CFrame = torso.CFrame * CFrame.new(0, -0.08, 0.75)
		midRow.CFrame = topRow.CFrame * CFrame.new(0, -1.6, 0)
		botRow.CFrame = midRow.CFrame * CFrame.new(0, -1.6, 0)

		-- 4. Helper to connect rows with a Hinge and apply soft Damping (Brakes)
		local function connectHinge(part0, pos0, part1, pos1, lowerLimit, upperLimit, dampingTorque)
			local att0 = Instance.new("Attachment")
			att0.Position = pos0
			att0.Parent = part0

			local att1 = Instance.new("Attachment")
			att1.Position = pos1
			att1.Parent = part1

			local hinge = Instance.new("HingeConstraint")
			hinge.Attachment0 = att0
			hinge.Attachment1 = att1
			hinge.LimitsEnabled = true
			hinge.LowerAngle = lowerLimit
			hinge.UpperAngle = upperLimit

			-- Activating the Motor with 0 velocity acts as air-resistance/friction
			hinge.ActuatorType = Enum.ActuatorType.Motor
			hinge.MotorMaxTorque = dampingTorque
			hinge.AngularVelocity = 0

			hinge.Parent = folder
		end

		-- Connect Torso to Top Row (Stiffer damping, doesn't swing forward into player)
		connectHinge(torso, Vector3.new(0, 0.72, 0.75), topRow, Vector3.new(0, 0.8, 0), -5, 70, 0.5)

		-- Connect Top Row to Mid Row (Moderate damping)
		connectHinge(topRow, Vector3.new(0, -0.8, 0), midRow, Vector3.new(0, 0.8, 0), -15, 45, 0.2)

		-- Connect Mid Row to Bot Row (Very loose damping for a flowy tail end)
		connectHinge(midRow, Vector3.new(0, -0.8, 0), botRow, Vector3.new(0, 0.8, 0), -15, 45, 0.1)
	end)
end

Commands.uncape = function(sender, target, args) removeCharacterNames(target, {"AdminCape"}) end

Commands.rainbow = function(sender, target, args)
	cacheAppearance(target, "rainbow")
	runTargetLoop(target, "rainbow", 0.15, function()
		local hue = (os.clock() * 0.25) % 1
		local color = Color3.fromHSV(hue, 0.9, 1)
		forCharacterParts(target, function(part)
			part.Color = color
		end)
	end, function()
		restoreAppearance(target, "rainbow")
	end)
end

Commands.unrainbow = function(sender, target, args)
	Util.StopLoop(target, "rainbow")
	restoreAppearance(target, "rainbow")
end

Commands.outline = function(sender, target, args)
	local character = getCharacter(target)
	if not character then return end
	Commands.unoutline(sender, target, args)
	local _, outlineColor = consumeColorArgs(args, 1, 3)
	if not outlineColor then
		_, outlineColor = getDefaultColor(nil, "white")
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "AdminOutlineHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = outlineColor
	highlight.Parent = character
end

Commands.unoutline = function(sender, target, args)
	removeCharacterNames(target, {"AdminOutlineHighlight"})
end

Commands.chrome = function(sender, target, args)
	cacheAppearance(target, "chrome")
	forCharacterParts(target, function(part)
		part.Material = Enum.Material.Metal
		part.Color = Settings.Colors.silver
	end)
end

Commands.unchrome = function(sender, target, args)
	restoreAppearance(target, "chrome")
end

Commands.unneon = function(sender, target, args)
	restoreAppearance(target, "neon")
end

Commands.day = function(sender, target, args) Lighting.ClockTime = 14 end
Commands.night = function(sender, target, args) Lighting.ClockTime = 21 end
Commands.midnight = function(sender, target, args) Lighting.ClockTime = 0 end
Commands.noon = function(sender, target, args) Lighting.ClockTime = 12 end
Commands.morning = function(sender, target, args) Lighting.ClockTime = 8 end
Commands.evening = function(sender, target, args) Lighting.ClockTime = 18 end
Commands.dawn = function(sender, target, args) Lighting.ClockTime = 6 end
Commands.dusk = function(sender, target, args) Lighting.ClockTime = 19 end

Commands.fullbright = function(sender, target, args)
	Lighting.Brightness = 4
	Lighting.Ambient = Color3.fromRGB(235, 235, 235)
	Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
	Lighting.GlobalShadows = false
end

Commands.unfullbright = function(sender, target, args)
	restoreLightingDefaults()
end

Commands.sepia = function(sender, target, args)
	local effect = ensureLightingEffect("AdminSepiaEffect", "ColorCorrectionEffect")
	effect.TintColor = Color3.fromRGB(220, 190, 140)
	effect.Saturation = -0.4
	effect.Contrast = 0.15
end

Commands.unsepia = function(sender, target, args)
	local effect = Lighting:FindFirstChild("AdminSepiaEffect")
	if effect then effect:Destroy() end
end

Commands.disco = function(sender, target, args)
	runWorldLoop("disco", 0.2, function()
		Lighting.Ambient = Color3.fromHSV(math.random(), 1, 1)
		Lighting.OutdoorAmbient = Color3.fromHSV(math.random(), 1, 1)
	end, function()
		Lighting.Ambient = LightingDefaults.Ambient
		Lighting.OutdoorAmbient = LightingDefaults.OutdoorAmbient
	end)
end

Commands.undisco = function(sender, target, args) stopWorldLoop("disco") end

Commands.time = function(sender, target, args) Lighting.ClockTime = tonumber(args[1]) or Lighting.ClockTime end

-- // HARDENED EXTENSIONS //

local BodyScaleCache = {}
local ReflectanceCache = {}
local DisplayNameCache = {}
local FaceCache = {}
local ClothingCache = {}
local AccessoryCache = {}
local WaypointStore = {}
local ReturnStore = {}
local CustomSpawnStore = {}
local EmoteTrackCache = {}
local HookedPlayers = {}

local EMOTE_ANIMATIONS = {
	dance = 507771019,
	laugh = 507770818,
	cheer = 507770677,
	wave = 507770239,
	salute = 507770239,
}

local function trimText(text)
	return (text or ""):match("^%s*(.-)%s*$")
end

local function splitWords(text)
	local result = {}
	for word in string.gmatch(text or "", "%S+") do
		table.insert(result, word)
	end
	return result
end

local function toNumber(value, fallback)
	local parsed = tonumber(value)
	if parsed == nil then
		return fallback
	end
	return parsed
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds < 60 then
		return tostring(seconds) .. "s"
	end
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	if minutes < 60 then
		return remainder > 0 and string.format("%dm %ds", minutes, remainder) or string.format("%dm", minutes)
	end
	local hours = math.floor(minutes / 60)
	minutes = minutes % 60
	return minutes > 0 and string.format("%dh %dm", hours, minutes) or string.format("%dh", hours)
end

local function ensureStateTable(key)
	local state = getSessionState()
	state[key] = state[key] or {}
	return state[key]
end

local function pushLimited(list, entry, limit)
	table.insert(list, 1, entry)
	while #list > (limit or 150) do
		table.remove(list)
	end
end

local function addSessionLog(listName, entry, limit)
	local list = ensureStateTable(listName)
	pushLimited(list, entry, limit or 150)
	return list
end

local function buildEntryText(args)
	return trimText(table.concat(args or {}, " "))
end

local function resolveSingleTarget(executor, token)
	local targets = Util.GetTargets(token or "", executor)
	return targets[1]
end

local function resolveMaterial(materialText)
	local normalized = tostring(materialText or ""):lower():gsub("[%s%p_]+", "")
	return normalized, Settings.Materials[normalized]
end

local function saveReturnPosition(target)
	local root = getRoot(target)
	if root then
		ReturnStore[target.UserId] = root.CFrame
	end
end

local function teleportWithReturn(target, destination)
	local character = getCharacter(target)
	if not character then
		return
	end
	saveReturnPosition(target)
	character:PivotTo(destination)
end

local function getPlayerBackpack(target)
	return target:FindFirstChildOfClass("Backpack") or target:WaitForChild("Backpack", 2)
end

local function getAdminToolsFolder()
	return ServerStorage:FindFirstChild("AdminTools") or ServerStorage:WaitForChild("AdminTools", 2)
end

local function cloneCuratedTool(toolKey)
	local toolSettings = Settings.ToolRegistry[toolKey]
	local folder = getAdminToolsFolder()
	if not toolSettings or not folder then
		return nil
	end

	local assetName = toolSettings.AssetName or toolKey
	local source = folder:FindFirstChild(assetName)
	if not source or (not source:IsA("Tool") and not source:IsA("Model")) then
		local wanted = assetName:lower()
		for _, child in ipairs(folder:GetChildren()) do
			if (child:IsA("Tool") or child:IsA("Model")) and child.Name:lower() == wanted then
				source = child
				break
			end
		end
	end
	if not source or (not source:IsA("Tool") and not source:IsA("Model")) then
		return nil
	end

	local clone: Tool
	if source:IsA("Tool") then
		clone = source:Clone() :: Tool
		local nested = clone:FindFirstChildWhichIsA("Model")
		if nested and not clone:FindFirstChild("Handle") then
			for _, ch in ipairs(nested:GetChildren()) do
				ch.Parent = clone
			end
			nested:Destroy()
		end
	else
		clone = Instance.new("Tool")
		clone.Name = source.Name
		clone.RequiresHandle = true
		clone.CanBeDropped = true
		for _, ch in ipairs(source:GetChildren()) do
			ch:Clone().Parent = clone
		end
	end

	clone:SetAttribute("AdminTool", true)
	clone:SetAttribute("AdminToolKey", toolKey)
	return clone
end

local function findCuratedToolByName(requestedName)
	local folder = getAdminToolsFolder()
	if not folder then
		return nil
	end

	local normalized = tostring(requestedName or ""):lower()
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Tool") or child:IsA("Model") then
			local toolName = child.Name:lower()
			if toolName == normalized or toolName:sub(1, #normalized) == normalized then
				local clone: Tool
				if child:IsA("Tool") then
					clone = child:Clone() :: Tool
					local nested = clone:FindFirstChildWhichIsA("Model")
					if nested and not clone:FindFirstChild("Handle") then
						for _, ch in ipairs(nested:GetChildren()) do
							ch.Parent = clone
						end
						nested:Destroy()
					end
				else
					clone = Instance.new("Tool")
					clone.Name = child.Name
					clone.RequiresHandle = true
					clone.CanBeDropped = true
					for _, ch in ipairs(child:GetChildren()) do
						ch:Clone().Parent = clone
					end
				end
				clone:SetAttribute("AdminTool", true)
				clone:SetAttribute("AdminToolKey", child.Name)
				return clone
			end
		end
	end

	return nil
end

local function giveToolInstance(target, tool)
	local backpack = getPlayerBackpack(target)
	if backpack and tool then
		tool.Parent = backpack
		return true
	end
	return false
end

local function removeTools(target, matcher)
	local removed = 0
	for _, container in ipairs({target:FindFirstChildOfClass("Backpack"), getCharacter(target)}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and (not matcher or matcher(child)) then
					child:Destroy()
					removed += 1
				end
			end
		end
	end
	return removed
end

local function filterPrivateText(fromPlayer, toPlayer, rawText)
	rawText = trimText(rawText)
	if rawText == "" then
		return ""
	end
	if not fromPlayer or not fromPlayer:IsA("Player") or not toPlayer or not toPlayer:IsA("Player") then
		return rawText
	end

	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(rawText, fromPlayer.UserId, Enum.TextFilterContext.PrivateChat)
		return result:GetNonChatStringForUserAsync(toPlayer.UserId)
	end)
	if ok then
		return filtered
	end
	return nil
end

local function filterBroadcastText(fromPlayer, rawText)
	rawText = trimText(rawText)
	if rawText == "" then
		return ""
	end
	if not fromPlayer or not fromPlayer:IsA("Player") then
		return rawText
	end

	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(rawText, fromPlayer.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return filtered
	end
	return nil
end

function Commands.CreateTeamFromMenu(sender, payload)
	if not sender or not sender:IsA("Player") or type(payload) ~= "table" then
		return false, "Invalid team request."
	end
	if type(payload.Name) ~= "string" or type(payload.Color) ~= "string" then
		return false, "Invalid team name or color."
	end

	local rawName = trimText(payload.Name)
	if rawName == "" then
		return false, "Enter a team name."
	end
	if #rawName > 32 then
		return false, "Team names must be 32 characters or fewer."
	end
	if rawName:find("[%c]") then
		return false, "Team names cannot contain control characters."
	end

	local colorName, color = Util.ResolveColorName(payload.Color)
	if not color then
		return false, "Select a valid team color."
	end

	local value = payload.Value
	if value ~= nil then
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return false, "The optional value must be a finite number."
		end
		if value < -1000000000 or value > 1000000000 then
			return false, "The optional value must be between -1,000,000,000 and 1,000,000,000."
		end
	end

	if payload.AutoAssignable ~= nil and type(payload.AutoAssignable) ~= "boolean" then
		return false, "Invalid auto-assign setting."
	end
	if payload.AssignCreator ~= nil and type(payload.AssignCreator) ~= "boolean" then
		return false, "Invalid join-team setting."
	end

	local filteredName = filterBroadcastText(sender, rawName)
	if not filteredName or filteredName == "" then
		return false, "The team name could not be filtered."
	end
	filteredName = trimText(filteredName)
	if filteredName == "" or #filteredName > 32 then
		return false, "The filtered team name is invalid."
	end

	local normalizedName = filteredName:lower()
	for _, existing in ipairs(TeamsService:GetChildren()) do
		if existing:IsA("Team") and existing.Name:lower() == normalizedName then
			return false, "A team with that name already exists."
		end
	end

	local team = Instance.new("Team")
	team.Name = filteredName
	team.TeamColor = BrickColor.new(color)
	team.AutoAssignable = payload.AutoAssignable == true
	team:SetAttribute("ColorName", colorName)
	team:SetAttribute("CreatedByUserId", sender.UserId)
	if value ~= nil then
		team:SetAttribute("Value", value)
	end
	team.Parent = TeamsService

	local assignCreator = payload.AssignCreator ~= false
	if assignCreator then
		sender.Team = team
		sender.Neutral = false
	end

	return true, "Created team " .. filteredName .. ".", {
		Name = filteredName,
		Color = colorName,
		Value = value,
		AutoAssignable = team.AutoAssignable,
		AssignCreator = assignCreator,
	}
end

local function fireList(player, title, items)
	ClientAction:FireClient(player, "ShowList", {
		Title = title,
		Data = items,
	})
end

local function fireBanner(player, id, title, message, duration, style)
	ClientAction:FireClient(player, "ShowBanner", {
		Id = id,
		Title = title,
		Message = message,
		Duration = duration,
		Style = style,
	})
end

local function hideBanner(player, id)
	ClientAction:FireClient(player, "HideBanner", {
		Id = id,
	})
end

local function fireModal(player, id, title, message, primaryText, secondaryText, style, showInput, placeholder)
	ClientAction:FireClient(player, "ShowModal", {
		Id = id,
		Title = title,
		Message = message,
		PrimaryText = primaryText,
		SecondaryText = secondaryText,
		Style = style,
		ShowInput = showInput,
		Placeholder = placeholder,
	})
end

local function closeModal(player, id)
	ClientAction:FireClient(player, "CloseModal", {
		Id = id,
	})
end

local function broadcastBanner(id, title, message, duration, style)
	for _, player in ipairs(Players:GetPlayers()) do
		fireBanner(player, id, title, message, duration, style)
	end
end

local function closeModalForAll(id)
	for _, player in ipairs(Players:GetPlayers()) do
		closeModal(player, id)
	end
end

local function hideBannerForAll(id)
	for _, player in ipairs(Players:GetPlayers()) do
		hideBanner(player, id)
	end
end

local function getWarningStore(target)
	local store = ensureStateTable("Warnings")
	store[target.UserId] = store[target.UserId] or {}
	return store[target.UserId]
end

local function getNoteStore(target)
	local store = ensureStateTable("Notes")
	store[target.UserId] = store[target.UserId] or {}
	return store[target.UserId]
end

local function getModerationHistory(target)
	local store = ensureStateTable("ModerationHistory")
	store[target.UserId] = store[target.UserId] or {}
	return store[target.UserId]
end

local function addModerationEntry(target, actionName, actor, detail)
	local history = getModerationHistory(target)
	pushLimited(history, {
		Timestamp = os.time(),
		Action = actionName,
		Actor = actor and actor.Name or "System",
		Detail = detail or "",
	}, 50)
end

local function appendChatLog(player, message)
	addSessionLog("ChatLogs", {
		Timestamp = os.time(),
		User = player.Name,
		Text = message,
	}, 150)
end

local function appendJoinLog(player)
	addSessionLog("JoinLogs", {
		Timestamp = os.time(),
		User = player.Name,
		Text = player.Name .. " joined the server.",
	}, 80)
end

local function appendLeaveLog(player)
	addSessionLog("LeaveLogs", {
		Timestamp = os.time(),
		User = player.Name,
		Text = player.Name .. " left the server.",
	}, 80)
end

local function appendDeathLog(player)
	addSessionLog("DeathLogs", {
		Timestamp = os.time(),
		User = player.Name,
		Text = player.Name .. " died.",
	}, 80)
end

local function cacheBodyScales(target, key)
	local humanoid = getHumanoid(target)
	if not humanoid then
		return
	end

	BodyScaleCache[target.UserId] = BodyScaleCache[target.UserId] or {}
	if BodyScaleCache[target.UserId][key] then
		return
	end

	local snapshot = {}
	for _, scaleName in ipairs({"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "BodyTypeScale", "ProportionScale", "HeadScale"}) do
		local scale = humanoid:FindFirstChild(scaleName)
		if scale then
			snapshot[scaleName] = scale.Value
		end
	end
	BodyScaleCache[target.UserId][key] = snapshot
end

local function restoreBodyScales(target, key)
	local snapshot = BodyScaleCache[target.UserId] and BodyScaleCache[target.UserId][key]
	local humanoid = getHumanoid(target)
	if not snapshot or not humanoid then
		return
	end

	for scaleName, value in pairs(snapshot) do
		local scale = humanoid:FindFirstChild(scaleName)
		if scale then
			scale.Value = value
		end
	end

	BodyScaleCache[target.UserId][key] = nil
end

local function setBodyScale(target, key, scaleName, value)
	cacheBodyScales(target, key)
	local humanoid = getHumanoid(target)
	local scale = humanoid and humanoid:FindFirstChild(scaleName)
	if scale then
		scale.Value = value
	end
end

local function cacheReflectance(target, key)
	local character = getCharacter(target)
	if not character then
		return
	end

	ReflectanceCache[target.UserId] = ReflectanceCache[target.UserId] or {}
	if ReflectanceCache[target.UserId][key] then
		return
	end

	local snapshot = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			snapshot[part] = part.Reflectance
		end
	end
	ReflectanceCache[target.UserId][key] = snapshot
end

local function restoreReflectance(target, key)
	local snapshot = ReflectanceCache[target.UserId] and ReflectanceCache[target.UserId][key]
	if not snapshot then
		return
	end
	for part, reflectance in pairs(snapshot) do
		if part and part.Parent then
			part.Reflectance = reflectance
		end
	end
	ReflectanceCache[target.UserId][key] = nil
end

local function setRenderTransparency(target, key, alpha)
	cacheAppearance(target, key)
	forCharacterParts(target, function(part)
		part.Transparency = clamp(alpha, 0, 1)
	end)
end

local function setRenderReflectance(target, key, value)
	cacheReflectance(target, key)
	forCharacterParts(target, function(part)
		part.Reflectance = clamp(value, 0, 1)
	end)
end

local function setDisplayName(target, name)
	local humanoid = getHumanoid(target)
	if not humanoid then
		return
	end
	DisplayNameCache[target.UserId] = DisplayNameCache[target.UserId] or humanoid.DisplayName
	humanoid.DisplayName = name
end

local function restoreDisplayName(target)
	local humanoid = getHumanoid(target)
	local cached = DisplayNameCache[target.UserId]
	if humanoid and cached then
		humanoid.DisplayName = cached
	end
	DisplayNameCache[target.UserId] = nil
end

local function setFaceTexture(target, textureId)
	local character = getCharacter(target)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	local face = head:FindFirstChildOfClass("Decal")
	if not face then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Parent = head
	end
	FaceCache[target.UserId] = FaceCache[target.UserId] or face.Texture
	face.Texture = "rbxassetid://" .. tostring(textureId)
end

local function restoreFaceTexture(target)
	local character = getCharacter(target)
	local head = character and character:FindFirstChild("Head")
	local cached = FaceCache[target.UserId]
	if not head or cached == nil then
		return
	end
	local face = head:FindFirstChildOfClass("Decal")
	if face then
		face.Texture = cached
	end
	FaceCache[target.UserId] = nil
end

local function setClothingTemplate(target, className, templateValue)
	local character = getCharacter(target)
	if not character then
		return
	end

	local item = character:FindFirstChildOfClass(className) or Instance.new(className)
	item.Parent = character
	local cacheKey = className == "Shirt" and "ShirtTemplate" or "PantsTemplate"
	ClothingCache[target.UserId] = ClothingCache[target.UserId] or {}
	if ClothingCache[target.UserId][cacheKey] == nil then
		ClothingCache[target.UserId][cacheKey] = item[cacheKey]
	end
	item[cacheKey] = "rbxassetid://" .. tostring(templateValue)
end

local function restoreClothingTemplate(target, className)
	local character = getCharacter(target)
	local cacheKey = className == "Shirt" and "ShirtTemplate" or "PantsTemplate"
	local cached = ClothingCache[target.UserId] and ClothingCache[target.UserId][cacheKey]
	if not character or cached == nil then
		return
	end
	local item = character:FindFirstChildOfClass(className)
	if item then
		item[cacheKey] = cached
	end
	ClothingCache[target.UserId][cacheKey] = nil
end

local function addAccessoryByAssetId(target, assetId)
	local character = getCharacter(target)
	local humanoid = getHumanoid(target)
	if not character or not humanoid then
		return false
	end

	local ok, model = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not model then
		return false
	end

	local accessory = model:FindFirstChildWhichIsA("Accessory", true)
	if not accessory then
		model:Destroy()
		return false
	end

	AccessoryCache[target.UserId] = AccessoryCache[target.UserId] or {}
	table.insert(AccessoryCache[target.UserId], accessory.Name)
	accessory.Name = "AdminAccessory_" .. accessory.Name
	accessory.Parent = character
	humanoid:AddAccessory(accessory)
	model:Destroy()
	return true
end

local function removeAdminAccessories(target)
	local character = getCharacter(target)
	if not character then
		return 0
	end

	local removed = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child.Name:sub(1, 15) == "AdminAccessory_" then
			child:Destroy()
			removed += 1
		end
	end
	AccessoryCache[target.UserId] = nil
	return removed
end

local function playEmoteAnimation(target, emoteName)
	local humanoid = getHumanoid(target)
	if not humanoid then
		return
	end

	local animationId = EMOTE_ANIMATIONS[emoteName]
	if not animationId then
		return
	end

	if EmoteTrackCache[target.UserId] then
		pcall(function()
			EmoteTrackCache[target.UserId]:Stop()
		end)
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(animationId)
	local ok, track = pcall(function()
		return humanoid:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track:Play()
		EmoteTrackCache[target.UserId] = track
	end
	animation:Destroy()
end

local function stopEmoteAnimation(target)
	local track = EmoteTrackCache[target.UserId]
	if track then
		pcall(function()
			track:Stop()
		end)
	end
	EmoteTrackCache[target.UserId] = nil
end

function Commands.ResolveJoinBlock(player)
	local state = getSessionState()
	local entry = Commands.BannedPlayers[player.Name] or Commands.BannedPlayers[player.UserId]
	if type(entry) == "table" and entry.ExpiresAt and entry.ExpiresAt <= os.time() then
		Commands.BannedPlayers[player.Name] = nil
		Commands.BannedPlayers[player.UserId] = nil
		entry = nil
	end
	if entry then
		local reason = type(entry) == "table" and entry.Reason or nil
		return reason and ("You are banned from this server. Reason: " .. reason) or "You are banned from this server."
	end

	local whitelist = state.Whitelist
	if whitelist and next(whitelist) ~= nil then
		local lowerName = player.Name:lower()
		if not whitelist[lowerName] and not whitelist[tostring(player.UserId)] then
			return "This server is currently whitelisted."
		end
	end

	local serverLockRank = state.ServerLockRank
	if serverLockRank then
		local playerValue = Settings.Ranks[Util.GetRank(player)] or 0
		if playerValue < serverLockRank then
			return "This server is currently locked."
		end
	end

	return nil
end

local function hookPlayer(player)
	if HookedPlayers[player] then
		return
	end
	HookedPlayers[player] = true

	appendJoinLog(player)

	player.Chatted:Connect(function(message)
		appendChatLog(player, message)
	end)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			local spawnCFrame = CustomSpawnStore[player.UserId]
			if spawnCFrame and character.Parent then
				character:PivotTo(spawnCFrame)
			end
		end)

		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				appendDeathLog(player)
			end)
		end
	end)

	local blockReason = Commands.ResolveJoinBlock(player)
	if blockReason then
		task.defer(function()
			if player.Parent then
				player:Kick(blockReason)
			end
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	HookedPlayers[player] = nil
	appendLeaveLog(player)
end)

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(hookPlayer, player)
end

Commands.notify = function(sender, target, args)
	local msg = buildEntryText(args)
	if msg == "" or not target or not target:FindFirstChild("PlayerGui") then
		return
	end

	local ui = getUiAsset("Notification", "ScreenGui")
	if ui then
		ui.Name = "Notification"
		ui.Parent = target.PlayerGui
		local label = findElement(ui, "MessageLabel", "TextLabel") or findElement(ui, "TextLabel", "TextLabel")
		if label then
			label.Text = msg
		end
		Debris:AddItem(ui, 5)
	else
		fireBanner(target, "NotificationBanner", sender and sender.Name or "Admin", msg, 5, "info")
	end
end

Commands.ban = function(sender, target, args)
	if not target then
		return
	end

	local rawReason = buildEntryText(args)
	if rawReason == "" then
		rawReason = "No reason provided."
	end

	local storedReason = filterBroadcastText(sender, rawReason)
	local targetReason = filterPrivateText(sender, target, rawReason)
	if storedReason == nil or storedReason == "" or targetReason == nil or targetReason == "" then
		Commands.notify(sender, sender, {"The ban reason could not be filtered. The player was not banned."})
		return
	end

	local entry = {
		Reason = storedReason,
		Actor = sender and sender.Name or "System",
		Username = target.Name,
		UserId = target.UserId,
		Permanent = true,
	}
	Commands.BannedPlayers[target.Name] = entry
	Commands.BannedPlayers[target.UserId] = entry
	addModerationEntry(target, "Ban", sender, storedReason)
	logAudit(sender, "ban", target, storedReason)
	Commands.notify(sender, sender, {"Banned " .. target.Name .. ". Reason: " .. storedReason})
	target:Kick("You have been banned from this server. Reason: " .. targetReason)
end

Commands.unban = function(sender, target, args)
	local requested = buildEntryText(args)
	if requested == "" then
		local list = {}
		local seenNames = {}
		for key, entry in pairs(Commands.BannedPlayers) do
			local username = type(key) == "string" and key
				or (type(entry) == "table" and entry.Username)
			if username and not seenNames[username:lower()] then
				seenNames[username:lower()] = true
				table.insert(list, username)
			end
		end
		table.sort(list, function(a, b)
			return a:lower() < b:lower()
		end)
		ClientAction:FireClient(sender, "ShowUnban", list)
		return
	end

	local requestedLower = requested:lower()
	local keysToRemove = {}
	local entriesToRemove = {}
	local displayName = requested

	for key, entry in pairs(Commands.BannedPlayers) do
		local keyMatches = tostring(key):lower() == requestedLower
		local entryMatches = type(entry) == "table"
			and (
				tostring(entry.Username or ""):lower() == requestedLower
				or tostring(entry.UserId or "") == requested
			)
		if keyMatches or entryMatches then
			keysToRemove[key] = true
			if type(entry) == "table" then
				entriesToRemove[entry] = true
				displayName = entry.Username or displayName
			elseif type(key) == "string" then
				displayName = key
			end
		end
	end

	if next(entriesToRemove) then
		for key, entry in pairs(Commands.BannedPlayers) do
			if entriesToRemove[entry] then
				keysToRemove[key] = true
			end
		end
	end

	if not next(keysToRemove) then
		Commands.notify(sender, sender, {requested .. " is not in the ban list."})
		return
	end

	for key in pairs(keysToRemove) do
		Commands.BannedPlayers[key] = nil
	end
	logAudit(sender, "unban", displayName, "Successfully unbanned by admin")
	Commands.notify(sender, sender, {"Successfully unbanned " .. displayName .. "."})
end

Commands.pm = function(sender, target, args)
	local rawMessage = buildEntryText(args)
	if rawMessage == "" or not target then
		return
	end

	local filteredMessage = filterPrivateText(sender, target, rawMessage)
	if filteredMessage == nil or filteredMessage == "" then
		Commands.notify(sender, sender, {"Message could not be filtered for delivery."})
		return
	end

	if target:FindFirstChild("PlayerGui") then
		local ui = getUiAsset("Pm", "ScreenGui")
		if ui then
			ui.Name = "Pm"
			local title = findElement(ui, "TitleLabel", "TextLabel")
			if title then
				title.Text = "PM from " .. sender.Name
			end
			local label = findElement(ui, "MessageLabel", "TextLabel") or findElement(ui, "TextLabel", "TextLabel")
			if label then
				label.Text = filteredMessage
			end
			local senderValue = ui:FindFirstChild("SenderName")
			if not senderValue or not senderValue:IsA("StringValue") then
				warn("AdminUiAssets.Pm is missing the SenderName StringValue.")
				ui:Destroy()
				return
			end
			senderValue.Value = sender.Name
			ui.Parent = target.PlayerGui
			Debris:AddItem(ui, 120)
		else
			fireModal(target, "PmModal", "PM from " .. sender.Name, filteredMessage, "Close", nil, "info")
		end
	end
end

Commands.m = function(sender, target, args)
	local filtered = filterBroadcastText(sender, buildEntryText(args))
	if not filtered or filtered == "" then
		Commands.notify(sender, sender, {"System message could not be filtered."})
		return
	end
	broadcastBanner("SystemMessageBanner", "System Message", filtered, 8, "info")
end

Commands.color = function(sender, target, args)
	local colorName, color = Util.ResolveColorName(args[1] or "")
	if not color then
		Commands.notify(sender, sender, {"Provide a valid color name."})
		return
	end
	cacheAppearance(target, "color")
	forCharacterParts(target, function(part)
		part.Color = color
	end)
	Commands.notify(sender, sender, {"Color set to " .. colorName .. "."})
end

Commands.aura = function(sender, target, args)
	local character = getCharacter(target)
	if not character then
		return
	end
	local _, auraColor = Util.ResolveColorName(args[1] or "")
	if not auraColor then
		_, auraColor = getDefaultColor(nil, "white")
	end
	Commands.unaura(sender, target, args)
	local highlight = Instance.new("Highlight")
	highlight.Name = "AuraHighlight"
	highlight.FillColor = auraColor
	highlight.OutlineColor = auraColor
	highlight.FillTransparency = 0.5
	highlight.Parent = character
end

Commands.chatcolor = function(sender, target, args)
	local colorName, color = Util.ResolveColorName(args[1] or "")
	if not color then
		target:SetAttribute("ChatColor", nil)
		local runner = ServerScriptService:FindFirstChild("ChatServiceRunner")
		if runner then
			local s, CS = pcall(function() return require(runner:FindFirstChild("ChatService")) end)
			if s and CS then
				local speaker = CS:GetSpeaker(target.Name)
				if speaker then speaker:SetExtraData("ChatColor", nil); speaker:SetExtraData("NameColor", nil) end
			end
		end
		Commands.notify(sender, target, {"Chat color reset."})
		return
	end
	target:SetAttribute("ChatColor", color)
	local runner = ServerScriptService:FindFirstChild("ChatServiceRunner")
	if runner then
		local s, CS = pcall(function() return require(runner:FindFirstChild("ChatService")) end)
		if s and CS then
			local speaker = CS:GetSpeaker(target.Name)
			if speaker then speaker:SetExtraData("ChatColor", color); speaker:SetExtraData("NameColor", color) end
		end
	end
	Commands.notify(sender, target, {"Chat color set to " .. colorName .. "."})
end

Commands.material = function(sender, target, args)
	local materialName, material = resolveMaterial(args[1] or "")
	if not material then
		Commands.notify(sender, sender, {"Provide a valid material name."})
		return
	end
	cacheAppearance(target, "material")
	forCharacterParts(target, function(part)
		part.Material = material
	end)
	Commands.notify(sender, sender, {"Material set to " .. materialName .. "."})
end

Commands.sword = function(sender, target, args)
	local tool = cloneCuratedTool("sword")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"Sword tool not found in ServerStorage/AdminTools."})
end

Commands.pipe = function(sender, target, args)
	local tool = cloneCuratedTool("pipe")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"MetalPipe tool not found in ServerStorage/AdminTools."})
end

Commands.banhammer = function(sender, target, args)
	local tool = cloneCuratedTool("banhammer")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"BanHammer tool not found in ServerStorage/AdminTools."})
end
Commands.hammer = Commands.banhammer

Commands.gravitygun = function(sender, target, args)
	local tool = cloneCuratedTool("gravitygun")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"GravityGun tool not found in ServerStorage/AdminTools."})
end
Commands.gravgun = Commands.gravitygun

Commands.freezeray = function(sender, target, args)
	local tool = cloneCuratedTool("freezeray")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"FreezeRay tool not found in ServerStorage/AdminTools."})
end
Commands.icewand = Commands.freezeray

Commands.panel = function(sender, target, args)
	if ClientAction then
		ClientAction:FireClient(sender, "ToggleDashboard")
	end
end
Commands.dashboard = Commands.panel

Commands.rpg = function(sender, target, args)
	local tool = cloneCuratedTool("rpg")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"RPG tool not found in ServerStorage/AdminTools."})
end

Commands.btools = function(sender, target, args)
	local tool = cloneCuratedTool("btools")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"BuildingTools tool not found in ServerStorage/AdminTools."})
end

Commands.tptool = function(sender, target, args)
	local tool = cloneCuratedTool("tptool")
	if tool and giveToolInstance(target, tool) then
		return
	end
	Commands.notify(sender, sender, {"TeleportTool not found in ServerStorage/AdminTools."})
end

Commands.tbomb = function(sender, target, args, context)
	-- Reject "all" target so this command can't be used to mass-tbomb.
	if context and context.Targets then
		local playerCount = #Players:GetPlayers()
		if playerCount > 0 and #context.Targets >= playerCount then
			Commands.notify(sender, sender, {"The tbomb command cannot target everyone."})
			return
		end
	end

	local clone = getAsset("TimeBomb")
	if not clone then
		Commands.notify(sender, sender, {"TimeBomb tool not found in AdminAssets."})
		return
	end
	clone:SetAttribute("AdminTool", true)
	clone:SetAttribute("AdminToolKey", "tbomb")
	if giveToolInstance(target, clone) then
		return
	end
	clone:Destroy()
end

Commands.gear = function(sender, target, args)
	local id = tonumber(args[1])
	if not id then
		Commands.notify(sender, sender, {"Provide a numeric gear asset id."})
		return
	end
	if not Settings.AllowExternalAssetTools then
		Commands.notify(sender, sender, {"External gear loading is disabled in this hardened build."})
		return
	end
	pcall(function()
		local asset = InsertService:LoadAsset(id)
		local tool = asset and asset:FindFirstChildOfClass("Tool")
		if tool and getPlayerBackpack(target) then
			tool.Parent = target.Backpack
		end
	end)
end

Commands.title = function(sender, target, args)
	local character = getCharacter(target)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	local _, titleColor, consumed = consumeColorArgs(args, 1, 3)
	if not titleColor then
		_, titleColor = getDefaultColor(nil, "white")
		consumed = 0
	end

	local filteredText = filterPrivateText(sender, target, table.concat(args, " ", consumed + 1))
	if not filteredText or filteredText == "" then
		Commands.notify(sender, sender, {"Provide title text that can be filtered."})
		return
	end

	Commands.untitle(sender, target, args)
	local gui = getUiAsset("Title", "BillboardGui")
	if not gui then
		warn("TitleGui not found!")
		return
	end

	gui.Name = "TitleGui"
	gui.Parent = head
	local label = findElement(gui, "MessageLabel", "TextLabel") or gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = filteredText
		label.TextColor3 = titleColor
	end
end

local function getSpawnLocationCFrame()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			return descendant.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

local function showLogEntries(player, title, entries, formatter)
	local formatted = {}
	if #entries == 0 then
		table.insert(formatted, "No entries recorded.")
	else
		for _, entry in ipairs(entries) do
			table.insert(formatted, formatter(entry))
		end
	end
	fireList(player, title, formatted)
end

local function clearPhysicalMode(target, key)
	local character = getCharacter(target)
	if character then
		Util.RestorePhysicalProperties(character, key)
	end
end

local function setVectorForce(target, name, scale)
	local root = getRoot(target)
	if not root then
		return
	end

	local attachment = root:FindFirstChild(name .. "Attachment") or Instance.new("Attachment")
	attachment.Name = name .. "Attachment"
	attachment.Parent = root

	local vectorForce = root:FindFirstChild(name) or Instance.new("VectorForce")
	vectorForce.Name = name
	vectorForce.Attachment0 = attachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * (1 - scale), 0)
	vectorForce.Parent = root
end

local function clearVectorForce(target, name)
	local root = getRoot(target)
	if not root then
		return
	end
	local attachment = root:FindFirstChild(name .. "Attachment")
	local vectorForce = root:FindFirstChild(name)
	if attachment then attachment:Destroy() end
	if vectorForce then vectorForce:Destroy() end
end

Commands.warn = function(sender, target, args)
	local reason = buildEntryText(args)
	if reason == "" then
		reason = "No reason provided."
	end
	local warnings = getWarningStore(target)
	pushLimited(warnings, {
		Timestamp = os.time(),
		Actor = sender.Name,
		Reason = reason,
	}, 25)
	addModerationEntry(target, "Warn", sender, reason)
	Commands.notify(sender, sender, {"Warned " .. target.Name .. ": " .. reason})
	Commands.notify(sender, target, {"You were warned by " .. sender.Name .. ": " .. reason})
end

Commands.unwarn = function(sender, target, args)
	local warnings = getWarningStore(target)
	if #warnings == 0 then
		Commands.notify(sender, sender, {"No warnings stored for " .. target.Name .. "."})
		return
	end
	local index = clamp(toNumber(args[1], 1), 1, #warnings)
	local removed = table.remove(warnings, index)
	addModerationEntry(target, "Unwarn", sender, removed and removed.Reason or "")
	Commands.notify(sender, sender, {"Removed warning #" .. tostring(index) .. " for " .. target.Name .. "."})
end

Commands.warnings = function(sender, target, args)
	local warnings = getWarningStore(target)
	showLogEntries(sender, "Warnings - " .. target.Name, warnings, function(entry)
		return string.format("%s | %s | %s", os.date("%m/%d %I:%M %p", entry.Timestamp), entry.Actor or "Unknown", entry.Reason or "")
	end)
end

Commands.tempmute = function(sender, target, args)
	local seconds = clamp(toNumber(args[1], 60), 1, 86400)
	local reason = trimText(table.concat(args, " ", 2))
	Commands.mute(sender, target, args)
	target:SetAttribute("TempMutedUntil", os.time() + seconds)
	addModerationEntry(target, "TempMute", sender, reason ~= "" and reason or formatDuration(seconds))
	Commands.notify(sender, sender, {"Muted " .. target.Name .. " for " .. formatDuration(seconds) .. "."})
	task.delay(seconds, function()
		if target.Parent and (target:GetAttribute("TempMutedUntil") or 0) <= os.time() then
			target:SetAttribute("TempMutedUntil", nil)
			Commands.unmute(sender, target, {})
		end
	end)
end

Commands.tempban = function(sender, target, args)
	local seconds = clamp(toNumber(args[1], 600), 1, 86400 * 30)
	local reason = trimText(table.concat(args, " ", 2))
	local entry = {
		Reason = reason ~= "" and reason or ("Tempbanned for " .. formatDuration(seconds)),
		ExpiresAt = os.time() + seconds,
		Actor = sender.Name,
		Username = target.Name,
		UserId = target.UserId,
	}
	Commands.BannedPlayers[target.Name] = entry
	Commands.BannedPlayers[target.UserId] = entry
	addModerationEntry(target, "TempBan", sender, entry.Reason)
	target:Kick("You were temp banned for " .. formatDuration(seconds) .. ". Reason: " .. entry.Reason)
end

Commands.softban = function(sender, target, args)
	local reason = buildEntryText(args)
	if reason == "" then
		reason = "Soft banned."
	end
	addModerationEntry(target, "SoftBan", sender, reason)
	target:Kick(reason)
end

Commands.banreason = function(sender, target, args)
	local entry = Commands.BannedPlayers[target.Name] or Commands.BannedPlayers[target.UserId]
	if type(entry) ~= "table" then
		Commands.notify(sender, sender, {"No stored ban reason for " .. target.Name .. "."})
		return
	end
	local reason = entry.Reason or "No reason provided."
	Commands.notify(sender, sender, {target.Name .. " ban reason: " .. reason})
end

Commands.chatlogs = function(sender, target, args)
	local logs = ensureStateTable("ChatLogs")
	showLogEntries(sender, "Chat Logs", logs, function(entry)
		return string.format("%s | %s: %s", os.date("%m/%d %I:%M %p", entry.Timestamp), entry.User or "Unknown", entry.Text or "")
	end)
end

Commands.joinlogs = function(sender, target, args)
	local logs = ensureStateTable("JoinLogs")
	showLogEntries(sender, "Join Logs", logs, function(entry)
		return string.format("%s | %s", os.date("%m/%d %I:%M %p", entry.Timestamp), entry.Text or "")
	end)
end

Commands.leavelogs = function(sender, target, args)
	local logs = ensureStateTable("LeaveLogs")
	showLogEntries(sender, "Leave Logs", logs, function(entry)
		return string.format("%s | %s", os.date("%m/%d %I:%M %p", entry.Timestamp), entry.Text or "")
	end)
end

Commands.deathlogs = function(sender, target, args)
	local logs = ensureStateTable("DeathLogs")
	showLogEntries(sender, "Death Logs", logs, function(entry)
		return string.format("%s | %s", os.date("%m/%d %I:%M %p", entry.Timestamp), entry.Text or "")
	end)
end

Commands.serverlock = function(sender, target, args)
	local requestedRank = tostring(args[1] or "Player")
	local properRankName = nil
	for rankName in pairs(Settings.Ranks) do
		if rankName:lower() == requestedRank:lower() then
			properRankName = rankName
			break
		end
	end
	properRankName = properRankName or "Player"
	getSessionState().ServerLockRank = Settings.Ranks[properRankName]
	logAudit(sender, "serverlock", nil, "Server locked below rank " .. properRankName)
	Commands.notify(sender, sender, {"Server locked below rank " .. properRankName .. "."})
end

Commands.unlockserver = function(sender, target, args)
	getSessionState().ServerLockRank = nil
	logAudit(sender, "unlockserver", nil, "Server lock cleared")
	Commands.notify(sender, sender, {"Server lock cleared."})
end

Commands.whitelist = function(sender, target, args)
	local requested = trimText(args[1] or "")
	if requested == "" then
		Commands.notify(sender, sender, {"Provide a username or userId to whitelist."})
		return
	end
	local whitelist = ensureStateTable("Whitelist")
	whitelist[requested:lower()] = true
	Commands.notify(sender, sender, {"Whitelisted " .. requested .. "."})
end

Commands.unwhitelist = function(sender, target, args)
	local requested = trimText(args[1] or "")
	if requested == "" then
		Commands.notify(sender, sender, {"Provide a username or userId to remove from the whitelist."})
		return
	end
	local whitelist = ensureStateTable("Whitelist")
	whitelist[requested:lower()] = nil
	whitelist[requested] = nil
	Commands.notify(sender, sender, {"Removed " .. requested .. " from the whitelist."})
end

Commands.Shadowbanned = Commands.Shadowbanned or {}

Commands.shadowban = function(sender, target, args)
	local reason = buildEntryText(args)
	local entry = {
		Reason = reason ~= "" and reason or "Shadow banned to Ghost Realm.",
		Actor = sender.Name,
		Username = target.Name,
		UserId = target.UserId,
		Silent = true,
	}
	Commands.Shadowbanned[target.Name] = true
	Commands.Shadowbanned[target.UserId] = true
	addModerationEntry(target, "GhostRealm", sender, entry.Reason)
	target:SetAttribute("IsShadowbanned", true)

	-- Make character invisible, non-collidable, and hide nametags
	local char = target.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
				part.CastShadow = false
			elseif part:IsA("Decal") then
				part.Transparency = 1
			elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") then
				part.Enabled = false
			end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.NameDisplayDistance = 0
			hum.HealthDisplayDistance = 0
		end
	end

	Commands.notify(sender, sender, {string.format("[GHOST REALM] %s has been silently banished to the Ghost Realm.", target.Name)})
end

Commands.unshadowban = function(sender, target, args)
	Commands.Shadowbanned[target.Name] = nil
	Commands.Shadowbanned[target.UserId] = nil
	addModerationEntry(target, "UnGhostRealm", sender, "")
	target:SetAttribute("IsShadowbanned", nil)

	Commands.re(sender, target, args)
	Commands.notify(sender, sender, {string.format("[GHOST REALM] %s has been released from the Ghost Realm.", target.Name)})
end

Commands.tospawn = function(sender, target, args)
	local destination = CustomSpawnStore[target.UserId] or getSpawnLocationCFrame()
	if destination then
		teleportWithReturn(target, destination)
	end
end

Commands.setspawn = function(sender, target, args)
	local character = getCharacter(target)
	if character then
		CustomSpawnStore[target.UserId] = character:GetPivot()
		Commands.notify(sender, sender, {"Saved a custom spawn for " .. target.Name .. "."})
	end
end

Commands.removespawn = function(sender, target, args)
	CustomSpawnStore[target.UserId] = nil
	Commands.notify(sender, sender, {"Removed the custom spawn for " .. target.Name .. "."})
end

Commands.waypoint = function(sender, target, args)
	local destination = WaypointStore[target.UserId]
	if destination and getCharacter(target) then
		teleportWithReturn(target, destination)
	end
end

Commands.clearwaypoint = function(sender, target, args)
	WaypointStore[target.UserId] = nil
	Commands.notify(sender, sender, {"Waypoint cleared."})
end

Commands.jumppower = function(sender, target, args)
	local humanoid = getHumanoid(target)
	if humanoid then
		cacheHumanoidState(target, "jumppower")
		humanoid.JumpPower = toNumber(args[1], humanoid.JumpPower)
	end
end

Commands.unjumppower = function(sender, target, args)
	restoreHumanoidState(target, "jumppower")
end

Commands.hipheight = function(sender, target, args)
	local humanoid = getHumanoid(target)
	if humanoid then
		cacheHumanoidState(target, "hipheight")
		humanoid.HipHeight = toNumber(args[1], humanoid.HipHeight)
	end
end

Commands.unhipheight = function(sender, target, args)
	restoreHumanoidState(target, "hipheight")
end

Commands.depth = function(sender, target, args)
	setBodyScale(target, "depth", "BodyDepthScale", toNumber(args[1], 1))
end

Commands.undepth = function(sender, target, args)
	restoreBodyScales(target, "depth")
end

Commands.unboing = function(sender, target, args)
	clearPhysicalMode(target, "boing")
end

Commands.knockback = function(sender, target, args)
	local senderRoot = getRoot(sender)
	local targetRoot = getRoot(target)
	if senderRoot and targetRoot then
		local force = toNumber(args[1], 120)
		local direction = (targetRoot.Position - senderRoot.Position)
		if direction.Magnitude > 0 then
			targetRoot.AssemblyLinearVelocity = direction.Unit * force + Vector3.new(0, 30, 0)
		end
	end
end

Commands.stun = function(sender, target, args)
	local humanoid = getHumanoid(target)
	if humanoid then
		cacheHumanoidState(target, "stun")
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

Commands.unstun = function(sender, target, args)
	restoreHumanoidState(target, "stun")
end

Commands.ragdoll = function(sender, target, args)
	local humanoid = getHumanoid(target)
	if humanoid then
		cacheHumanoidState(target, "ragdoll")
		humanoid.PlatformStand = true
	end
end

Commands.unragdoll = function(sender, target, args)
	restoreHumanoidState(target, "ragdoll")
end

Commands.massless = function(sender, target, args)
	forCharacterParts(target, function(part)
		part.Massless = true
	end)
end

Commands.unmassless = function(sender, target, args)
	forCharacterParts(target, function(part)
		part.Massless = false
	end)
end

Commands.gravityscale = function(sender, target, args)
	local scale = clamp(toNumber(args[1], 1), 0, 4)
	if math.abs(scale - 1) < 0.001 then
		clearVectorForce(target, "AdminGravityScale")
		return
	end
	setVectorForce(target, "AdminGravityScale", scale)
end

local function getOrCreateWorldSound()
	local folder = ensureWorkspaceFolder("Audio")
	local sound = folder:FindFirstChild("AdminWorldMusic")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "AdminWorldMusic"
		sound.Looped = true
		sound.Volume = 0.5
		sound.Parent = folder
	end
	return sound
end

local function getOrCreateWeatherPart(name)
	local folder = ensureWorkspaceFolder("Weather")
	local part = folder:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(1, 1, 1)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.CFrame = CFrame.new(0, 120, 0)
		part.Parent = folder
	end
	return part
end

local function clearWeatherPart(name)
	local folder = Workspace:FindFirstChild("AdminGenerated")
	local weatherFolder = folder and folder:FindFirstChild("Weather")
	local part = weatherFolder and weatherFolder:FindFirstChild(name)
	if part then
		part:Destroy()
	end
end

Commands.headsize = function(sender, target, args)
	cacheBodyScales(target, "headsize")
	local humanoid = getHumanoid(target)
	if humanoid and humanoid:FindFirstChild("HeadScale") then
		humanoid.HeadScale.Value = toNumber(args[1], 1.5)
		return
	end
	local head = getCharacter(target) and getCharacter(target):FindFirstChild("Head")
	if head then
		head.Size = head.Size * toNumber(args[1], 1.5)
	end
end

Commands.unheadsize = function(sender, target, args)
	restoreBodyScales(target, "headsize")
end

Commands.shirt = function(sender, target, args)
	local assetId = tonumber(args[1])
	if assetId then
		setClothingTemplate(target, "Shirt", assetId)
	end
end

Commands.unshirt = function(sender, target, args)
	restoreClothingTemplate(target, "Shirt")
end

Commands.pants = function(sender, target, args)
	local assetId = tonumber(args[1])
	if assetId then
		setClothingTemplate(target, "Pants", assetId)
	end
end

Commands.unpants = function(sender, target, args)
	restoreClothingTemplate(target, "Pants")
end

Commands.face = function(sender, target, args)
	local assetId = tonumber(args[1])
	if assetId then
		setFaceTexture(target, assetId)
	end
end

Commands.unface = function(sender, target, args)
	restoreFaceTexture(target)
end

Commands.hat = function(sender, target, args)
	local assetId = tonumber(args[1])
	if assetId and not addAccessoryByAssetId(target, assetId) then
		Commands.notify(sender, sender, {"Unable to load that accessory asset."})
	end
end

Commands.unhat = function(sender, target, args)
	removeAdminAccessories(target)
end

Commands.displayname = function(sender, target, args)
	local name = buildEntryText(args)
	if name ~= "" then
		setDisplayName(target, name)
	end
end

Commands.undisplayname = function(sender, target, args)
	restoreDisplayName(target)
end

Commands.transparency = function(sender, target, args)
	setRenderTransparency(target, "transparency", toNumber(args[1], 0.5))
end

Commands.untransparency = function(sender, target, args)
	restoreAppearance(target, "transparency")
end

Commands.reflectance = function(sender, target, args)
	setRenderReflectance(target, "reflectance", toNumber(args[1], 0.2))
end

Commands.unreflectance = function(sender, target, args)
	restoreReflectance(target, "reflectance")
end

Commands.bundle = function(sender, target, args)
	local outfitId = tonumber(args[1])
	if not outfitId then
		return
	end
	local humanoid = getHumanoid(target)
	if not humanoid then
		return
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
	end)
	if ok and description then
		humanoid:ApplyDescription(description)
	else
		Commands.notify(sender, sender, {"Unable to load that bundle or outfit id."})
	end
end

Commands.xray = function(sender, target, args)
	ClientAction:FireClient(target, "xray", true)
end

Commands.unxray = function(sender, target, args)
	ClientAction:FireClient(target, "xray", false)
end

Commands.ambient = function(sender, target, args)
	local _, color = consumeColorArgs(args, 1, 3)
	if color then
		Lighting.Ambient = color
	end
end

Commands.outdoorambient = function(sender, target, args)
	local _, color = consumeColorArgs(args, 1, 3)
	if color then
		Lighting.OutdoorAmbient = color
	end
end

Commands.brightness = function(sender, target, args)
	Lighting.Brightness = clamp(toNumber(args[1], Lighting.Brightness), 0, 10)
end

Commands.unshadows = function(sender, target, args)
	Lighting.GlobalShadows = false
end

Commands.music = function(sender, target, args)
	local soundId = tonumber(args[1])
	if not soundId then
		return
	end
	local sound = getOrCreateWorldSound()
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound:Play()
end

Commands.volume = function(sender, target, args)
	local sound = getOrCreateWorldSound()
	sound.Volume = clamp(toNumber(args[1], sound.Volume), 0, 1)
end

Commands.rain = function(sender, target, args)
	local part = getOrCreateWeatherPart("RainEmitter")
	local emitter = part:FindFirstChildOfClass("ParticleEmitter") or Instance.new("ParticleEmitter")
	emitter.Rate = 500
	emitter.Speed = NumberRange.new(90, 110)
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
end

Commands.unrain = function(sender, target, args)
	clearWeatherPart("RainEmitter")
end

Commands.snow = function(sender, target, args)
	local part = getOrCreateWeatherPart("SnowEmitter")
	local emitter = part:FindFirstChildOfClass("ParticleEmitter") or Instance.new("ParticleEmitter")
	emitter.Rate = 220
	emitter.Speed = NumberRange.new(18, 30)
	emitter.Lifetime = NumberRange.new(5, 7)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
end

Commands.unsnow = function(sender, target, args)
	clearWeatherPart("SnowEmitter")
end

Commands.unwind = function(sender, target, args)
	local sound = getOrCreateWorldSound()
	sound:Stop()
	sound.SoundId = ""
end

Commands.eclipse = function(sender, target, args)
	Lighting.ClockTime = 12
	Lighting.Brightness = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 60)
end

Commands.uneclipse = function(sender, target, args)
	restoreLightingDefaults()
end

Commands.sunrise = function(sender, target, args)
	Lighting.ClockTime = 6
end

Commands.sunset = function(sender, target, args)
	Lighting.ClockTime = 18
end

Commands.rainbowworld = function(sender, target, args)
	runWorldLoop("rainbowworld", 0.15, function()
		local hue = (os.clock() * 0.18) % 1
		Lighting.Ambient = Color3.fromHSV(hue, 0.9, 1)
		Lighting.OutdoorAmbient = Color3.fromHSV((hue + 0.2) % 1, 0.9, 1)
		Lighting.FogColor = Color3.fromHSV((hue + 0.45) % 1, 0.85, 1)
	end, function()
		restoreLightingDefaults()
	end)
end

Commands.closevote = function(sender, target, args)
	closeModalForAll("GlobalVote")
end

Commands.credits = function(sender, target, args)
	fireModal(sender, "CreditsModal", "Credits", "Hardened admin pack with local tools, filtered GUI text, and expanded moderation, utility, and world controls.", "Close", nil, "info")
end

Commands.banlist = function(sender, target, args)
	local items = {}
	local seen = {}
	for key, entry in pairs(Commands.BannedPlayers) do
		if type(key) == "string" and not seen[key] then
			seen[key] = true
			local reason = type(entry) == "table" and entry.Reason or "No reason provided."
			table.insert(items, key .. " - " .. reason)
		end
	end
	fireList(sender, "Ban List", items)
end

Commands.toolsui = function(sender, target, args)
	local items = {}
	local folder = getAdminToolsFolder()
	if folder then
		for _, tool in ipairs(folder:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(items, tool.Name)
			end
		end
	end
	fireList(sender, "Admin Tools", items)
end

Commands.aliases = function(sender, target, args)
	local items = {}
	for alias, canonical in pairs(Settings.Aliases or {}) do
		table.insert(items, alias .. " -> " .. canonical)
	end
	table.sort(items)
	fireList(sender, "Aliases", items)
end

Commands.hideguis = function(sender, target, args)
	ClientAction:FireClient(target, "ToggleAllGuis", false)
end

Commands.showguis = function(sender, target, args)
	ClientAction:FireClient(target, "ToggleAllGuis", true)
end

local function getStatValueObject(target, statName)
	local normalized = trimText(statName):lower()
	if normalized == "" then
		return nil
	end

	for _, container in ipairs({target:FindFirstChild("leaderstats"), target}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("BoolValue") or child:IsA("StringValue") then
					local childName = child.Name:lower()
					if childName == normalized or childName:sub(1, #normalized) == normalized then
						return child
					end
				end
			end
		end
	end

	return nil
end

local function ensureNumericStat(target, statName)
	local stat = getStatValueObject(target, statName)
	if stat and (stat:IsA("NumberValue") or stat:IsA("IntValue")) then
		return stat
	end

	local leaderstats = target:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local newStat = Instance.new("IntValue")
	newStat.Name = statName
	newStat.Value = 0
	newStat.Parent = leaderstats
	return newStat
end

local function resolveToolRequest(requestedName, fallbackKey)
	local normalized = trimText(requestedName)
	local tool = nil

	if normalized ~= "" then
		local registryKey = normalized:lower()
		tool = cloneCuratedTool(registryKey) or findCuratedToolByName(normalized)
		if tool then
			return tool
		end
		local assetId = tonumber(normalized)
		if assetId and Settings.AllowExternalAssetTools then
			return "external:" .. tostring(assetId)
		end
	end

	if fallbackKey then
		tool = cloneCuratedTool(fallbackKey)
		if tool then
			return tool
		end
	end

	return nil
end

Commands.countdown = function(sender, target, args)
	local seconds = math.max(1, math.floor(clamp(toNumber(args[1], 10), 1, 600)))
	local filteredMessage = filterBroadcastText(sender, table.concat(args, " ", 2))
	local message = (filteredMessage and filteredMessage ~= "") and filteredMessage or "Admin countdown"
	local remaining = seconds
	local completed = false

	stopWorldLoop("countdown")
	runWorldLoop("countdown", 1, function()
		if remaining <= 0 then
			completed = true
			broadcastBanner("CountdownBanner", "Countdown", message .. " now!", 2, "success")
			task.delay(2, function()
				hideBannerForAll("CountdownBanner")
			end)
			stopWorldLoop("countdown")
			return
		end

		broadcastBanner("CountdownBanner", "Countdown", string.format("%s (%ds)", message, remaining), 1.1, "warning")
		remaining -= 1
	end, function()
		if not completed then
			hideBannerForAll("CountdownBanner")
		end
	end)
end

Commands.cancelcountdown = function(sender, target, args)
	stopWorldLoop("countdown")
	hideBannerForAll("CountdownBanner")
end

Commands.give = function(sender, target, args)
	local request = buildEntryText(args)
	local resolved = resolveToolRequest(request, "give")
	if typeof(resolved) == "string" and resolved:sub(1, 9) == "external:" then
		Commands.gear(sender, target, {resolved:sub(10)})
		return
	end
	if resolved and giveToolInstance(target, resolved) then
		return
	end
	Commands.notify(sender, sender, {"Requested tool not found in ServerStorage/AdminTools."})
end

Commands.toolrain = function(sender, target, args)
	local request = buildEntryText(args)
	local resolved = resolveToolRequest(request, "toolrain")
	if typeof(resolved) == "string" and resolved:sub(1, 9) == "external:" then
		Commands.gear(sender, target, {resolved:sub(10)})
		return
	end
	if not resolved then
		Commands.notify(sender, sender, {"Requested tool not found in ServerStorage/AdminTools."})
		return
	end

	local root = getRoot(target)
	local handle = resolved:FindFirstChild("Handle") or resolved:FindFirstChildWhichIsA("BasePart", true)
	if root and handle then
		resolved.Parent = Workspace
		handle.CFrame = root.CFrame + Vector3.new(math.random(-6, 6), 22, math.random(-6, 6))
		handle.AssemblyLinearVelocity = Vector3.new(0, -24, 0)
		task.delay(12, function()
			if resolved and resolved.Parent then
				resolved:Destroy()
			end
		end)
		return
	end

	giveToolInstance(target, resolved)
end

Commands.cleargear = function(sender, target, args)
	removeTools(target)
end

Commands.refresh = function(sender, target, args)
	Commands.re(sender, target, args)
end

Commands.resetstats = function(sender, target, args)
	for _, container in ipairs({target:FindFirstChild("leaderstats"), target}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("NumberValue") or child:IsA("IntValue") then
					child.Value = 0
				elseif child:IsA("BoolValue") then
					child.Value = false
				elseif child:IsA("StringValue") then
					child.Value = ""
				end
			end
		end
	end
end

Commands.setstat = function(sender, target, args)
	local statName = args[1]
	local statValue = tonumber(args[2])
	if not statName or statValue == nil then
		Commands.notify(sender, sender, {"Usage: setstat <player> <statName> <value>"})
		return
	end

	local stat = ensureNumericStat(target, statName)
	if not stat then
		Commands.notify(sender, sender, {"Target has no writable leaderstats container."})
		return
	end
	stat.Value = statValue
end

Commands.addstat = function(sender, target, args)
	local statName = args[1]
	local statValue = tonumber(args[2])
	if not statName or statValue == nil then
		Commands.notify(sender, sender, {"Usage: addstat <player> <statName> <value>"})
		return
	end

	local stat = ensureNumericStat(target, statName)
	if not stat then
		Commands.notify(sender, sender, {"Target has no writable leaderstats container."})
		return
	end
	stat.Value += statValue
end

Commands.removestat = function(sender, target, args)
	local stat = getStatValueObject(target, args[1] or "")
	if stat then
		stat:Destroy()
	end
end

Commands.dance = function(sender, target, args)
	playEmoteAnimation(target, "dance")
end

Commands.undance = function(sender, target, args)
	stopEmoteAnimation(target)
end

Commands.laugh = function(sender, target, args)
	playEmoteAnimation(target, "laugh")
end

Commands.cheer = function(sender, target, args)
	playEmoteAnimation(target, "cheer")
end

Commands.wave = function(sender, target, args)
	playEmoteAnimation(target, "wave")
end

Commands.salute = function(sender, target, args)
	playEmoteAnimation(target, "salute")
end

Commands.zombie = function(sender, target, args)
	cacheHumanoidState(target, "zombie")
	cacheAppearance(target, "zombie")
	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid.WalkSpeed = 8
		humanoid.JumpPower = 0
	end
	forCharacterParts(target, function(part)
		part.Color = Color3.fromRGB(106, 148, 92)
		part.Material = Enum.Material.SmoothPlastic
	end)
end

Commands.unzombie = function(sender, target, args)
	restoreHumanoidState(target, "zombie")
	restoreAppearance(target, "zombie")
end

-- Alias function references: alias -> canonical handler
-- These MUST point alias keys to the existing canonical function.
Commands.rj = Commands.rejoin
Commands.exterminate = Commands.kill
Commands.tp = Commands.to
Commands.img = Commands.image
Commands.superfling = Commands.superf
Commands.message = Commands.m
Commands.ranks = Commands.rlist
-- =========================================================================
-- SIGNATURE EXPANSION FEATURES
-- =========================================================================

-- 1. Delta Snapshot & Rollback Engine
Commands.Snapshots = {}
Commands.LatestSnapshotName = "initial"

local function ensureSnapshotsFolder(): Folder
	local folder = ServerStorage:FindFirstChild("AdminSnapshots") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "AdminSnapshots"
		folder.Parent = ServerStorage
	end
	return folder
end

local function saveWorkspaceSnapshot(name: string): (boolean, number)
	local snapshotsFolder = ensureSnapshotsFolder()
	local existing = snapshotsFolder:FindFirstChild(name)
	if existing then existing:Destroy() end

	local snapDir = Instance.new("Folder")
	snapDir.Name = name
	snapDir.Parent = snapshotsFolder

	local count = 0
	for _, child in ipairs(workspace:GetChildren()) do
		if not child:IsA("Camera") and not child:IsA("Terrain") and not Players:GetPlayerFromCharacter(child) then
			if child.Name ~= "AdminAssets" and child.Name ~= "SingularityVortex" and child.Name ~= "CryoIceBlock" and child.Name ~= "AdminJail" then
				if child.Archivable then
					pcall(function()
						local clone = child:Clone()
						if clone then
							clone.Parent = snapDir
							count += 1
						end
					end)
				end
			end
		end
	end

	Commands.Snapshots[name] = {
		Name = name,
		Timestamp = os.time(),
		ItemCount = count,
	}
	Commands.LatestSnapshotName = name
	return true, count
end

local function restoreWorkspaceSnapshot(name: string): (boolean, string)
	local snapshotsFolder = ensureSnapshotsFolder()
	local snapDir = snapshotsFolder:FindFirstChild(name) :: Folder?
	if not snapDir then
		local backup = ServerStorage:FindFirstChild("AdminMapBackup") :: Folder?
		if backup then
			snapDir = backup
		else
			return false, "Snapshot '" .. name .. "' not found."
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if not child:IsA("Camera") and not child:IsA("Terrain") and not Players:GetPlayerFromCharacter(child) then
			if child.Name ~= "AdminAssets" then
				pcall(function() child:Destroy() end)
			end
		end
	end

	local restoredCount = 0
	for _, item in ipairs(snapDir:GetChildren()) do
		pcall(function()
			local clone = item:Clone()
			if clone then
				clone.Parent = workspace
				restoredCount += 1
			end
		end)
	end

	return true, string.format("Restored %d objects from snapshot '%s'.", restoredCount, name)
end

Commands.snapshot = function(sender, target, args)
	local action = (args[1] or "save"):lower()
	local name = args[2] or ("snap_" .. os.date("%H%M%S"))

	if action == "save" then
		local success, count = saveWorkspaceSnapshot(name)
		Commands.notify(sender, sender, {string.format("[SNAPSHOT] Saved snapshot '%s' (%d items).", name, count)})
	elseif action == "list" then
		local list = {}
		for snapName, data in pairs(Commands.Snapshots) do
			table.insert(list, string.format("• %s (%d items)", snapName, data.ItemCount or 0))
		end
		if #list == 0 then
			Commands.notify(sender, sender, {"[SNAPSHOT] No custom snapshots saved yet. Using initial map backup."})
		else
			Commands.notify(sender, sender, {"[SNAPSHOTS]:\n" .. table.concat(list, "\n")})
		end
	elseif action == "clear" then
		local snapshotsFolder = ensureSnapshotsFolder()
		if args[2] then
			local snap = snapshotsFolder:FindFirstChild(args[2])
			if snap then snap:Destroy() end
			Commands.Snapshots[args[2]] = nil
			Commands.notify(sender, sender, {string.format("[SNAPSHOT] Cleared snapshot '%s'.", args[2])})
		else
			snapshotsFolder:ClearAllChildren()
			Commands.Snapshots = {}
			Commands.notify(sender, sender, {"[SNAPSHOT] All custom snapshots cleared."})
		end
	else
		Commands.notify(sender, sender, {"Usage: snapshot <save/list/clear> [name]"})
	end
end

Commands.rollback = function(sender, target, args)
	local name = args[1] or Commands.LatestSnapshotName or "initial"
	local success, msg = restoreWorkspaceSnapshot(name)
	if success then
		Commands.notify(sender, sender, {"[ROLLBACK] " .. msg})
	else
		Commands.notify(sender, sender, {"[ROLLBACK ERROR] " .. msg})
	end
end

Commands.undo = function(sender, target, args)
	Commands.rollback(sender, target, {Commands.LatestSnapshotName or "initial"})
end

-- 2. Cinematic Freecam & Surveillance Drone
Commands.freecam = function(sender, target, args)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local clientAction = remotes and remotes:FindFirstChild("ClientAction") :: RemoteEvent?
	if clientAction then
		clientAction:FireClient(sender, "ToggleFreecam", { Mode = "Freecam" })
	end
	Commands.notify(sender, sender, {"[FREECAM] Cinematic camera detached. Press [Backquote] or run ;undrone to exit."})
end

Commands.drone = function(sender, target, args)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local clientAction = remotes and remotes:FindFirstChild("ClientAction") :: RemoteEvent?
	if clientAction then
		clientAction:FireClient(sender, "ToggleFreecam", { Mode = "Drone" })
	end
	Commands.notify(sender, sender, {"[DRONE] Surveillance drone deployed! [N] Night Vision | [T] Thermal | Click Player to moderate."})
end

Commands.undrone = function(sender, target, args)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local clientAction = remotes and remotes:FindFirstChild("ClientAction") :: RemoteEvent?
	if clientAction then
		clientAction:FireClient(sender, "DisableFreecam", {})
	end
	Commands.notify(sender, sender, {"[DRONE] Freecam / drone mode disabled. Camera restored."})
end

-- 3. Black Hole / Singularity Cannon
Commands.blackholecannon = function(sender, target, args)
	local toolsFolder = getAdminToolsFolder()
	local bhTool = toolsFolder and (toolsFolder:FindFirstChild("BlackHoleCannon") or toolsFolder:FindFirstChild("singularity"))
	if not bhTool then
		Commands.notify(sender, sender, {"BlackHoleCannon tool not found in ServerStorage/AdminTools."})
		return
	end
	giveToolInstance(target, bhTool)
end

-- 4. Chrono Watch / Time Rewind
Commands.PlayerHistory = {}

task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local list = Commands.PlayerHistory[p.UserId]
				if not list then
					list = {}
					Commands.PlayerHistory[p.UserId] = list
				end
				table.insert(list, {
					Time = now,
					CFrame = hrp.CFrame,
					Health = hum.Health,
				})
				if #list > 150 then
					table.remove(list, 1)
				end
			end
		end
	end
end)

Commands.rewind = function(sender, target, args)
	local seconds = math.clamp(tonumber(args[1]) or 5, 1, 15)
	local char = target.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		Commands.notify(sender, sender, {"Target player character not found."})
		return
	end

	local list = Commands.PlayerHistory[target.UserId]
	if not list or #list == 0 then
		Commands.notify(sender, sender, {"No rewind history recorded yet for " .. target.Name .. "."})
		return
	end

	local targetTime = os.clock() - seconds
	local chosenFrame = list[1]
	for i = #list, 1, -1 do
		if list[i].Time <= targetTime then
			chosenFrame = list[i]
			break
		end
	end

	local prevAnchored = hrp.Anchored
	hrp.Anchored = true

	local ghost = Instance.new("Part")
	ghost.Size = hrp.Size
	ghost.CFrame = hrp.CFrame
	ghost.Material = Enum.Material.Neon
	ghost.Color = Color3.fromRGB(56, 189, 248)
	ghost.Transparency = 0.5
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.Parent = workspace
	Debris:AddItem(ghost, 1.2)

	local rewindSound = Instance.new("Sound")
	rewindSound.SoundId = "rbxassetid://9114223180"
	rewindSound.PlaybackSpeed = 1.6
	rewindSound.Volume = 1.5
	rewindSound.Parent = hrp
	rewindSound:Play()
	Debris:AddItem(rewindSound, 2)

	task.wait(0.2)
	hrp.CFrame = chosenFrame.CFrame
	hum.Health = math.max(hum.Health, chosenFrame.Health)
	hrp.Anchored = prevAnchored

	Commands.notify(sender, sender, {string.format("[CHRONO] Rewound %s back by %d seconds.", target.Name, seconds)})
	Commands.notify(target, target, {string.format("[CHRONO] You were rewound in time by %d seconds.", seconds)})
end

-- 5. Custom Command Macro Engine
Commands.Macros = {
	lockdown = ";serverlock on ;freeze all ;m EMERGENCY: Server Lockdown Initiated",
	unlockdown = ";serverlock off ;unfreeze all ;m Server Lockdown Lifted",
	purge = ";clean ;cleargear ;m All Dropped Tools & Admin Debris Cleared",
}

Commands.macro = function(sender, target, args)
	local raw = table.concat(args, " ")
	local action, rest = raw:match("^(%S+)%s*(.*)$")
	action = action and action:lower() or "list"

	if action == "create" or action == "set" then
		local macroName, sequence = rest:match("^(%S+)%s+(.+)$")
		if not macroName or not sequence or sequence == "" then
			Commands.notify(sender, sender, {"Usage: macro create <name> <commands...>"})
			return
		end
		Commands.Macros[macroName:lower()] = sequence
		Commands.notify(sender, sender, {string.format("[MACRO] Created ';%s' -> %s", macroName:lower(), sequence)})
	elseif action == "delete" or action == "remove" then
		local macroName = rest:match("^(%S+)")
		if not macroName or not Commands.Macros[macroName:lower()] then
			Commands.notify(sender, sender, {"Macro not found."})
			return
		end
		Commands.Macros[macroName:lower()] = nil
		Commands.notify(sender, sender, {string.format("[MACRO] Deleted macro ';%s'.", macroName:lower())})
	elseif action == "list" then
		local lines = {}
		for name, seq in pairs(Commands.Macros) do
			table.insert(lines, string.format("• ;%s => %s", name, seq))
		end
		if #lines == 0 then
			Commands.notify(sender, sender, {"[MACRO] No macros defined."})
		else
			Commands.notify(sender, sender, {"[ACTIVE MACROS]:\n" .. table.concat(lines, "\n")})
		end
	elseif action == "run" or action == "exec" then
		local macroName = rest:match("^(%S+)")
		if not macroName or not Commands.Macros[macroName:lower()] then
			Commands.notify(sender, sender, {"Macro not found: " .. tostring(macroName)})
			return
		end
		if Commands.ExecuteMacroSequence then
			Commands.ExecuteMacroSequence(sender, Commands.Macros[macroName:lower()])
		else
			Commands.notify(sender, sender, {"[MACRO RUN] " .. Commands.Macros[macroName:lower()]})
		end
	else
		Commands.notify(sender, sender, {"Usage: macro <create/delete/list/run> [name] [commands]"})
	end
end

-- Aliases
Commands.ghostban = Commands.shadowban
Commands.unghostban = Commands.unshadowban
Commands.snap = Commands.snapshot
Commands.undomap = Commands.rollback
Commands.maprestore = Commands.rollback
Commands.cam = Commands.freecam
Commands.cinematic = Commands.freecam
Commands.unfreecam = Commands.undrone
Commands.singularitycannon = Commands.blackholecannon
Commands.timerewind = Commands.rewind
Commands.timewarp = Commands.rewind
Commands.setmacro = Commands.macro
Commands.clr = Commands.crl

return Commands
