--!strict
-- AuditLogger.lua
-- Centralized audit and Discord webhook dispatcher for AdminV4.
-- Formats rich Discord embeds with executor, victim, command, reason, PlaceId, JobId, and timestamp.

local HttpService = game:GetService("HttpService")

local AuditLogger = {}

local function resolveConfig()
	local configModule = script.Parent:FindFirstChild("Config")
	if not configModule and script.Parent.Parent then
		configModule = script.Parent.Parent:FindFirstChild("Config")
	end
	if configModule and configModule:IsA("ModuleScript") then
		local ok, result = pcall(require, configModule)
		if ok and type(result) == "table" then
			return result
		end
	end
	return nil
end

local Config = resolveConfig() or {
	DiscordWebhook = {
		Enabled = false,
		WebhookUrl = "",
		BotUsername = "AdminV4 Audit Sentinel",
		LoggedCommands = {
			ban = true,
			kick = true,
			shutdown = true,
			serverlock = true,
			banhammer = true,
		},
		EmbedColors = {},
	}
}

-- Format ISO 8601 UTC timestamp
local function getIsoTimestamp(): string
	return os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
end

-- Discord Webhook embed dispatcher
function AuditLogger.LogModeration(executor: any, actionName: string, target: any, reason: string?, extra: any?)
	local webhookConfig = Config.DiscordWebhook
	if not webhookConfig or not webhookConfig.Enabled then
		return
	end

	local webhookUrl = webhookConfig.WebhookUrl
	if not webhookUrl or webhookUrl == "" or (webhookUrl:find("discord.com/api/webhooks") == nil and webhookUrl:find("discordapp.com/api/webhooks") == nil) then
		return
	end

	local lowerAction = actionName:lower()
	if webhookConfig.LoggedCommands and not webhookConfig.LoggedCommands[lowerAction] then
		return
	end

	local executorName = "System / Console"
	if typeof(executor) == "Instance" and executor:IsA("Player") then
		executorName = string.format("%s (@%s)", executor.DisplayName, executor.Name)
	elseif type(executor) == "string" and executor ~= "" then
		executorName = executor
	end

	local targetName = "Server-wide"
	if typeof(target) == "Instance" and target:IsA("Player") then
		targetName = string.format("%s (@%s)", target.DisplayName, target.Name)
	elseif type(target) == "string" and target ~= "" then
		targetName = target
	elseif type(target) == "table" and target.Name then
		targetName = tostring(target.Name)
	end

	local displayReason = reason or "No specific reason provided."
	if displayReason == "" then
		displayReason = "No specific reason provided."
	end

	local embedColor = (webhookConfig.EmbedColors and webhookConfig.EmbedColors[lowerAction]) or 0x2563EB

	local actionTitles: {[string]: string} = {
		ban = "🔨 Player Banned",
		pban = "🔨 Permanent Ban Applied",
		unban = "🔓 Player Unbanned",
		kick = "👢 Player Kicked",
		shutdown = "⚠️ Server Shutdown Initiated",
		serverlock = "🔒 Server Locked",
		unlockserver = "🔓 Server Unlocked",
		banhammer = "⚡ Ban Hammer Strike",
	}

	local title = actionTitles[lowerAction] or string.format("🛡️ Moderation: %s", actionName:upper())

	local fields: {any} = {
		{
			name = "👮 Admin / Executor",
			value = executorName,
			inline = true,
		},
		{
			name = "🎯 Target",
			value = targetName,
			inline = true,
		},
		{
			name = "⚡ Command",
			value = ";" .. lowerAction,
			inline = true,
		},
		{
			name = "📝 Reason / Details",
			value = string.format("```%s```", displayReason:sub(1, 1000)),
			inline = false,
		},
	}

	if webhookConfig.IncludePlaceId ~= false then
		table.insert(fields, {
			name = "🗺️ Place ID",
			value = tostring(game.PlaceId),
			inline = true,
		})
	end

	if webhookConfig.IncludeJobId ~= false then
		local jobId = game.JobId ~= "" and game.JobId or "Studio / Local Session"
		table.insert(fields, {
			name = "🆔 Server Job ID",
			value = string.format("`%s`", jobId:sub(1, 36)),
			inline = true,
		})
	end

	local payload = {
		username = webhookConfig.BotUsername or "AdminV4 Audit Sentinel",
		avatar_url = webhookConfig.AvatarUrl or nil,
		embeds = {
			{
				title = title,
				description = string.format("**%s** executed **;%s** on **%s**", executorName, lowerAction, targetName),
				color = embedColor,
				fields = fields,
				timestamp = getIsoTimestamp(),
				footer = {
					text = "AdminV4 Security & Audit Sentinel",
				},
			}
		}
	}

	task.spawn(function()
		local jsonBody
		local encodeOk, encodeErr = pcall(function()
			jsonBody = HttpService:JSONEncode(payload)
		end)
		if not encodeOk then
			warn("[AuditLogger] Failed to encode webhook payload: " .. tostring(encodeErr))
			return
		end

		local postOk, postErr = pcall(function()
			HttpService:PostAsync(webhookUrl, jsonBody, Enum.HttpContentType.ApplicationJson)
		end)

		if not postOk then
			warn(string.format("[AuditLogger] Webhook delivery failed: %s (Ensure 'Allow HTTP Requests' is enabled in Studio Game Settings)", tostring(postErr)))
		end
	end)
end

return AuditLogger
