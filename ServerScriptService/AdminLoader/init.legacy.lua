local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local mapBackupFolder = ServerStorage:FindFirstChild("AdminMapBackup")
if not mapBackupFolder then
	mapBackupFolder = Instance.new("Folder")
	mapBackupFolder.Name = "AdminMapBackup"
	mapBackupFolder.Parent = ServerStorage

	for _, child in ipairs(workspace:GetChildren()) do
		if not child:IsA("Camera") and not child:IsA("Terrain") and not Players:GetPlayerFromCharacter(child) then
			if child.Archivable then
				pcall(function()
					local clone = child:Clone()
					if clone then
						clone.Parent = mapBackupFolder
					end
				end)
			end
		end
	end
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local AdminAssets = ensureFolder(ReplicatedStorage, "AdminAssets")
local AdminUiAssets = ensureFolder(ReplicatedStorage, "AdminUiAssets")
local Remotes = ensureFolder(ReplicatedStorage, "Remotes")
local AdminTools = ensureFolder(ServerStorage, "AdminTools")

local function ensureRemote(name, className)
	local remote = Remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		warn(string.format("Replacing Remotes.%s because it is not a %s.", name, className))
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local ExecuteEvent = ensureRemote("ExecuteCommand", "RemoteEvent")
ensureRemote("ClientAction", "RemoteEvent")
local TeamRequest = ensureRemote("TeamRequest", "RemoteFunction")

local function resolveModule(name)
	local child = script:FindFirstChild(name)
	if child and child:IsA("ModuleScript") then
		return child
	end
	local sibling = script.Parent and script.Parent:FindFirstChild(name)
	if sibling and sibling:IsA("ModuleScript") then
		return sibling
	end
	return script:WaitForChild(name, 5) or (script.Parent and script.Parent:WaitForChild(name, 5))
end

local commandsModule = resolveModule("Commands")
if not commandsModule then
	warn("CRITICAL: Commands module could not be found under script or script.Parent!")
	return
end
local Commands = require(commandsModule)

local utilModule = resolveModule("Util")
if not utilModule then
	warn("CRITICAL: Util module could not be found under script or script.Parent!")
	return
end
local Util = require(utilModule)

local configModule = resolveModule("Config")
local Config = configModule and require(configModule) or nil

local auditLoggerModule = resolveModule("AuditLogger")
local AuditLogger = auditLoggerModule and require(auditLoggerModule) or nil

local SettingsModule = ReplicatedStorage:WaitForChild("AdminSettings", 10)
if not SettingsModule then
	warn("CRITICAL: AdminSettings not found!")
	return
end

local Settings = require(SettingsModule)
local SessionState = {
	CommandLogs = {},
	GlobalCommandLock = false,
	LockedCommands = {},
	NextLogId = 1,
}
local TeamRequestTimes = {}

if Commands.SetSessionState then
	Commands.SetSessionState(SessionState)
else
	Commands.SessionState = SessionState
end

local function trim(text)
	return (text or ""):match("^%s*(.-)%s*$")
end

local function splitWords(text)
	local words = {}
	for word in string.gmatch(text or "", "%S+") do
		table.insert(words, word)
	end
	return words
end

local function getRankValue(player)
	return Settings.Ranks[Util.GetRank(player)] or 0
end

local function isLockExempt(player)
	return getRankValue(player) >= (Settings.Ranks.HeadAdmin or 4)
end

local function validateRegistry()
	local aliasOwners = {}
	local registryCount = 0
	local visibleCount = #(Settings.Commands or {})

	for name, meta in pairs(Settings.CommandRegistry or {}) do
		registryCount += 1
		if type(Commands[name]) ~= "function" then
			warn("Admin registry validation: missing handler for command '" .. name .. "'")
		end
		if Settings.CommandRanks[name] ~= meta.Rank then
			warn("Admin registry validation: rank drift for '" .. name .. "'")
		end

		for _, alias in ipairs(meta.Aliases or {}) do
			if Settings.CommandRegistry[alias] then
				warn("Admin registry validation: alias '" .. alias .. "' collides with canonical command")
			end
			if aliasOwners[alias] and aliasOwners[alias] ~= name then
				warn("Admin registry validation: alias collision for '" .. alias .. "'")
			end
			aliasOwners[alias] = name
			if Settings.Aliases[alias] ~= name then
				warn("Admin registry validation: alias drift for '" .. alias .. "'")
			end
		end
	end

	if Settings.RegistryCount and Settings.RegistryCount ~= registryCount then
		warn("Admin registry validation: registry count drift detected")
	end

	if Settings.TotalCommands and Settings.TotalCommands ~= visibleCount then
		warn("Admin registry validation: visible command count drift detected")
	end

	if Settings.AllCommands and #Settings.AllCommands ~= registryCount then
		warn("Admin registry validation: all-command list drift detected")
	end

	for _, entry in ipairs(Settings.Commands or {}) do
		if not Settings.CommandRegistry[entry.Name] then
			warn("Admin registry validation: help entry drift for '" .. tostring(entry.Name) .. "'")
		end
	end
end

validateRegistry()

local function parseTargetsAndArgs(player, meta, remainder)
	local targetMode = meta.TargetMode or "optional"
	local argMode = meta.ArgMode or "words"
	local cleanedRemainder = trim(remainder)
	local targets = {}
	local args = {}

	if targetMode == "none" then
		targets = {player}
		if argMode == "rest" then
			if cleanedRemainder ~= "" then
				args = {cleanedRemainder}
			end
		else
			args = splitWords(cleanedRemainder)
		end
		return targets, args
	end

	local firstToken, rest = cleanedRemainder:match("^(%S+)%s*(.*)$")
	local argString = ""

	if not firstToken or firstToken == "" then
		-- Instantly target the executor if no names/arguments were passed
		targets = {player}
	else
		local resolvedTargets = Util.GetTargets(firstToken, player)
		if #resolvedTargets > 0 then
			targets = resolvedTargets
			argString = trim(rest)
		elseif meta.ValueFallback then
			targets = {player}
			argString = cleanedRemainder
		else
			return nil, nil, "Player not found: " .. firstToken
		end
	end

	if argMode == "rest" then
		if trim(argString) ~= "" then
			args = {trim(argString)}
		end
	else
		args = splitWords(argString)
	end

	return targets, args
end

local function processCommand(player, msg)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(msg) ~= "string" then
		return
	end

	local playerPrefix = player:GetAttribute("CustomPrefix") or Settings.Prefix
	if string.sub(msg, 1, #playerPrefix) ~= playerPrefix then
		return
	end

	local commandBody = trim(string.sub(msg, #playerPrefix + 1))
	if commandBody == "" then
		return
	end

	local rawCommandName, remainder = commandBody:match("^(%S+)%s*(.*)$")
	if not rawCommandName then
		return
	end

	-- Custom Command Macro Execution
	if Commands.Macros and Commands.Macros[rawCommandName:lower()] then
		if Util.CanExecute(player, "macro") then
			local macroSeq = Commands.Macros[rawCommandName:lower()]
			if Commands.ExecuteMacroSequence then
				Commands.ExecuteMacroSequence(player, macroSeq)
			end
			return
		else
			Commands.notify(player, player, {"You do not have permission to execute macros."})
			return
		end
	end

	local resolution = Util.ResolveCommandInput(rawCommandName)
	local meta = resolution and resolution.Meta
	local commandName = resolution and resolution.Canonical
	if not meta or type(Commands[commandName]) ~= "function" then
		return
	end

	if not Util.CanExecute(player, commandName) then
		return
	end

	local isExempt = isLockExempt(player)
	if SessionState.GlobalCommandLock and not isExempt then
		Commands.notify(player, player, {"Commands are currently locked."})
		return
	end

	if SessionState.LockedCommands[commandName] and not isExempt then
		Commands.notify(player, player, {string.format("The %s command is currently locked.", commandName)})
		return
	end

	local targets, args, parseError = parseTargetsAndArgs(player, meta, remainder or "")
	if not targets then
		Commands.notify(player, player, {parseError})
		return
	end

	if resolution and resolution.InjectedArgs and #resolution.InjectedArgs > 0 then
		local mergedArgs = {}
		for _, value in ipairs(resolution.InjectedArgs) do
			table.insert(mergedArgs, value)
		end
		for _, value in ipairs(args) do
			table.insert(mergedArgs, value)
		end
		args = mergedArgs
	end

	print(string.format("[ADMIN] %s ran: %s", player.Name, msg))
	local logId = SessionState.NextLogId or 1
	table.insert(SessionState.CommandLogs, 1, {
		Id = logId,
		Timestamp = os.time(),
		User = player.Name,
		Cmd = msg,
		Canonical = commandName,
	})
	SessionState.NextLogId = logId + 1
	if #SessionState.CommandLogs > 150 then
		table.remove(SessionState.CommandLogs)
	end

	for index, target in ipairs(targets) do
		task.spawn(function()
			if not Util.CanExecute(player, commandName, target) then
				return
			end
			local context = {
				CanonicalName = commandName,
				CommandMeta = meta,
				Logs = SessionState.CommandLogs,
				Targets = targets,
				TargetIndex = index,
				Prefix = playerPrefix,
				RawMessage = msg,
			}
			local success, err = pcall(function()
				Commands[commandName](player, target, args, context)
			end)
			if not success then
				warn("Command Error [" .. commandName .. "]: " .. tostring(err))
			end
		end)
	end
end

Commands.ExecuteMacroSequence = function(sender, sequence)
	local prefix = sender:GetAttribute("CustomPrefix") or Settings.Prefix or ";"
	for subCmd in string.gmatch(sequence, "[^;|]+") do
		local trimmed = trim(subCmd)
		if trimmed ~= "" then
			if trimmed:sub(1, #prefix) ~= prefix then
				trimmed = prefix .. trimmed
			end
			processCommand(sender, trimmed)
		end
	end
end

local function onPlayerAdded(player)
	local joinBlockReason = Commands.ResolveJoinBlock and Commands.ResolveJoinBlock(player)
	if joinBlockReason then
		player:Kick(joinBlockReason)
		return
	end

	if Commands.BannedPlayers and Commands.BannedPlayers[player.Name] then
		player:Kick("You are banned from this server.")
		return
	end

	player:SetAttribute("LaydownActive", false)

	player.CharacterAdded:Connect(function(character)
		Util.StopAllLoops(player)
		player:SetAttribute("LaydownActive", false)

		-- Maintain Ghost Realm quarantine on respawn
		if (Commands.Shadowbanned and (Commands.Shadowbanned[player.Name] or Commands.Shadowbanned[player.UserId])) or player:GetAttribute("IsShadowbanned") then
			player:SetAttribute("IsShadowbanned", true)
			task.defer(function()
				for _, part in ipairs(character:GetDescendants()) do
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
				local hum = character:WaitForChild("Humanoid", 4) :: Humanoid?
				if hum then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					hum.NameDisplayDistance = 0
					hum.HealthDisplayDistance = 0
				end
			end)
		end

		local forcedRig = player:GetAttribute("ForcedRig")
		if forcedRig then
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				local currentRig = humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
				if currentRig ~= forcedRig then
					task.defer(function()
						local description = Players:GetHumanoidDescriptionFromUserId(player.UserId)
						local newCharacter = Players:CreateHumanoidModelFromDescription(
							description,
							forcedRig == "R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
						)
						newCharacter.Name = player.Name
						newCharacter:PivotTo(character:GetPivot())
						player.Character = newCharacter
						newCharacter.Parent = workspace
					end)
				end
			end
		end
	end)

	player.Chatted:Connect(function(message)
		if (Commands.Shadowbanned and (Commands.Shadowbanned[player.Name] or Commands.Shadowbanned[player.UserId])) or player:GetAttribute("IsShadowbanned") then
			return
		end
		processCommand(player, message)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(onPlayerAdded, player)
end

ExecuteEvent.OnServerEvent:Connect(processCommand)

TeamRequest.OnServerInvoke = function(player, payload)
	if not player or typeof(player) ~= "Instance" or player.Parent ~= Players or typeof(payload) ~= "table" then
		return false, "Invalid team request."
	end
	if not Util.CanExecute(player, "team") then
		return false, "You do not have permission to create teams."
	end

	local isExempt = isLockExempt(player)
	if SessionState.GlobalCommandLock and not isExempt then
		return false, "Commands are currently locked."
	end
	if SessionState.LockedCommands.team and not isExempt then
		return false, "The team command is currently locked."
	end

	local now = os.clock()
	local lastRequest = TeamRequestTimes[player.UserId]
	if lastRequest and now - lastRequest < 1 then
		return false, "Please wait before creating another team."
	end
	TeamRequestTimes[player.UserId] = now

	if type(Commands.CreateTeamFromMenu) ~= "function" then
		return false, "Team creation is unavailable."
	end

	local called, success, message, result = pcall(Commands.CreateTeamFromMenu, player, payload)
	if not called then
		warn("Team creation error: " .. tostring(success))
		return false, "The team could not be created."
	end
	if success ~= true then
		return false, tostring(message or "The team could not be created.")
	end

	local logId = SessionState.NextLogId or 1
	local resultName = type(result) == "table" and result.Name or "team"
	table.insert(SessionState.CommandLogs, 1, {
		Id = logId,
		Timestamp = os.time(),
		User = player.Name,
		Cmd = string.format("%steam [menu: %s]", player:GetAttribute("CustomPrefix") or Settings.Prefix, resultName),
		Canonical = "team",
	})
	SessionState.NextLogId = logId + 1
	if #SessionState.CommandLogs > 150 then
		table.remove(SessionState.CommandLogs)
	end

	return true, tostring(message or "Team created."), result
end

Players.PlayerRemoving:Connect(function(player)
	TeamRequestTimes[player.UserId] = nil
end)
