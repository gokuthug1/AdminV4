--!strict
-- Config.lua
-- Configuration settings for AdminV4 Discord Webhooks and Server Integrations.

local Config = {
	DiscordWebhook = {
		Enabled = false, -- Set to true and provide WebhookUrl below to enable Discord audit logs
		WebhookUrl = "", -- Your Discord channel Webhook URL (e.g., "https://discord.com/api/webhooks/...")
		BotUsername = "AdminV4",
		AvatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=1&width=420&height=420&format=png",
		MinRank = 3, -- Minimum admin rank to trigger Discord webhook logs (Default: 3 = Moderator)
		IncludeJobId = true,
		IncludePlaceId = true,
		LoggedCommands = {
			ban = true,
			pban = true,
			unban = true,
			kick = true,
			shutdown = true,
			serverlock = true,
			unlockserver = true,
			banhammer = true,
		},
		EmbedColors = {
			ban = 0x991B1B,        -- Deep Red
			pban = 0x7F1D1D,       -- Dark Crimson
			unban = 0x10B981,      -- Emerald Green
			kick = 0xDC2626,       -- Bright Red
			shutdown = 0x7C3AED,   -- Deep Purple
			serverlock = 0xEA580C, -- Warning Orange
			unlockserver = 0x059669,-- Teal Green
			banhammer = 0xEF4444,  -- Thunder Red
			default = 0x2563EB,    -- Royal Blue
		},
	},
}

return Config
