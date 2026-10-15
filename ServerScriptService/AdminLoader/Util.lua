local Util = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local settingsModule = ReplicatedStorage:WaitForChild("AdminSettings", 10)
if not settingsModule then
	error("AdminSettings could not be found in ReplicatedStorage.")
end
local Settings = require(settingsModule)

local PhysicalCache = {}
local LoopCache = {}
local ColorAliasMap = nil

local function getPlayerKey(player)
	return player and player.UserId or 0
end

local function trim(text)
	return (text or ""):match("^%s*(.-)%s*$")
end

local function normalizeCompact(text)
	return trim(tostring(text or "")):lower():gsub("[%s%p_]+", "")
end

local function buildColorAliasMap()
	if ColorAliasMap then
		return ColorAliasMap
	end

	local map = {}
	local function addAlias(alias, colorName)
		local normalized = normalizeCompact(alias)
		if normalized ~= "" and Settings.Colors[colorName] then
			map[normalized] = colorName
		end
	end

	for colorName in pairs(Settings.Colors or {}) do
		addAlias(colorName, colorName)

		if colorName:match("^d[%a]+$") and #colorName > 1 then
			addAlias("dark" .. colorName:sub(2), colorName)
		elseif colorName:match("^l[%a]+$") and #colorName > 1 then
			addAlias("light" .. colorName:sub(2), colorName)
		end
	end

	addAlias("r", "red")
	addAlias("dg", "dgreen")
	addAlias("db", "dblue")
	addAlias("dr", "dred")
	addAlias("dp", "dpurple")
	addAlias("dw", "white")

	ColorAliasMap = map
	return map
end

local function resolveStaticCommandName(commandName)
	local lowered = tostring(commandName or ""):lower()
	return Settings.Aliases[lowered] or lowered
end

function Util.NormalizeColorToken(colorText)
	return normalizeCompact(colorText)
end

function Util.ResolveColorName(colorText)
	local normalized = normalizeCompact(colorText)
	if normalized == "" then
		return nil, nil
	end

	local colorName = buildColorAliasMap()[normalized]
	if colorName then
		return colorName, Settings.Colors[colorName]
	end
	return nil, nil
end

function Util.ResolveCommandInput(commandName)
	local rawName = tostring(commandName or ""):lower()
	local canonical = resolveStaticCommandName(rawName)
	local meta = Settings.CommandRegistry[canonical]
	if meta then
		return {
			Canonical = canonical,
			Meta = meta,
			InjectedArgs = nil,
		}
	end

	if rawName:sub(1, 5) == "title" and #rawName > 5 then
		local colorName = Util.ResolveColorName(rawName:sub(6))
		if colorName and Settings.CommandRegistry.title then
			return {
				Canonical = "title",
				Meta = Settings.CommandRegistry.title,
				InjectedArgs = {colorName},
			}
		end
	end

	return nil
end

function Util.ResolveCommandName(commandName)
	local resolved = Util.ResolveCommandInput(commandName)
	if resolved then
		return resolved.Canonical
	end
	return resolveStaticCommandName(commandName)
end

function Util.GetCommandMeta(commandName)
	local resolved = Util.ResolveCommandInput(commandName)
	if resolved then
		return resolved.Meta, resolved.Canonical
	end
	local canonical = resolveStaticCommandName(commandName)
	return Settings.CommandRegistry[canonical], canonical
end

function Util.GetRank(player)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return "Player"
	end
	if player.UserId == game.CreatorId then
		return "Creator"
	end
	if Settings.PlayerRanks and Settings.PlayerRanks[player.Name] then
		return Settings.PlayerRanks[player.Name]
	end
	return "Player"
end

function Util.CanExecute(player, commandName, target)
	local meta = Util.GetCommandMeta(commandName)
	local requiredRank = (meta and meta.Rank) or Settings.CommandRanks[commandName] or "Creator"
	local playerRank = Util.GetRank(player)

	if not Settings.Ranks then
		return false
	end

	local playerValue = Settings.Ranks[playerRank] or 0
	local requiredValue = Settings.Ranks[requiredRank] or 100
	if playerValue < requiredValue then
		return false
	end

	if target and target:IsA("Player") and target ~= player then
		local targetRank = Util.GetRank(target)
		local targetValue = Settings.Ranks[targetRank] or 0
		if playerRank ~= "Creator" and playerValue <= targetValue then
			return false
		end
	end

	return true
end

function Util.GetTargets(nameString, executor)
	local targets = {}
	local loweredInput = trim(tostring(nameString or "")):lower()
	if loweredInput == "" then
		return {}
	end

	for term in string.gmatch(loweredInput, "[^,]+") do
		local cleaned = trim(term)
		if cleaned == "me" then
			table.insert(targets, executor)
		elseif cleaned == "all" then
			for _, player in ipairs(Players:GetPlayers()) do
				table.insert(targets, player)
			end
		elseif cleaned == "others" then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= executor then
					table.insert(targets, player)
				end
			end
		elseif cleaned == "random" then
			local list = Players:GetPlayers()
			if #list > 0 then
				table.insert(targets, list[math.random(1, #list)])
			end
		else
			for _, player in ipairs(Players:GetPlayers()) do
				local name = player.Name:lower()
				local displayName = player.DisplayName:lower()
				if name:sub(1, #cleaned) == cleaned or displayName:sub(1, #cleaned) == cleaned then
					table.insert(targets, player)
				end
			end
		end
	end

	local unique = {}
	local resolved = {}
	for _, target in ipairs(targets) do
		if not unique[target] then
			unique[target] = true
			table.insert(resolved, target)
		end
	end
	return resolved
end

function Util.GetCharacter(player)
	return player and player.Character or nil
end

function Util.GetHumanoid(playerOrCharacter)
	local character = playerOrCharacter
	if typeof(playerOrCharacter) == "Instance" and playerOrCharacter:IsA("Player") then
		character = playerOrCharacter.Character
	end
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function Util.GetRootPart(playerOrCharacter)
	local character = playerOrCharacter
	if typeof(playerOrCharacter) == "Instance" and playerOrCharacter:IsA("Player") then
		character = playerOrCharacter.Character
	end
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
end

function Util.DestroyNamed(root, names)
	if not root then
		return 0
	end
	local lookup = {}
	for _, name in ipairs(names) do
		lookup[name] = true
	end
	local removed = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if lookup[descendant.Name] then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

function Util.CachePhysicalProperties(character, key)
	if not character then
		return
	end
	PhysicalCache[character] = PhysicalCache[character] or {}
	if PhysicalCache[character][key] then
		return
	end

	local snapshot = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			snapshot[descendant] = descendant.CustomPhysicalProperties
		end
	end
	PhysicalCache[character][key] = snapshot
end

function Util.RestorePhysicalProperties(character, key)
	local characterCache = PhysicalCache[character]
	local snapshot = characterCache and characterCache[key]
	if not snapshot then
		return
	end
	for part, properties in pairs(snapshot) do
		if part and part.Parent then
			part.CustomPhysicalProperties = properties
		end
	end
	characterCache[key] = nil
end

function Util.BeginLoop(player, key, cleanup)
	local playerLoops = LoopCache[player] or {}
	LoopCache[player] = playerLoops
	if playerLoops[key] then
		Util.StopLoop(player, key)
	end
	playerLoops[key] = {Active = true, Cleanup = cleanup}
	return playerLoops[key]
end

function Util.IsLoopActive(player, key, token)
	local playerLoops = LoopCache[player]
	return playerLoops and playerLoops[key] == token and token.Active
end

function Util.StopLoop(player, key)
	local playerLoops = LoopCache[player]
	local token = playerLoops and playerLoops[key]
	if not token then
		return
	end
	token.Active = false
	playerLoops[key] = nil
	if token.Cleanup then
		pcall(token.Cleanup)
	end
end

function Util.StopAllLoops(player)
	local playerLoops = LoopCache[player]
	if not playerLoops then
		return
	end
	for key in pairs(playerLoops) do
		Util.StopLoop(player, key)
	end
	LoopCache[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	Util.StopAllLoops(player)
end)

return Util