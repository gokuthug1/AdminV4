-- Location: ReplicatedStorage > AdminSettings
local Settings = {}

Settings.Prefix = ";"
Settings.FlySpeed = 50
Settings.CommandBarKey = Enum.KeyCode.Semicolon
Settings.AllowExternalAssetTools = false
Settings.ToolRegistry = {
	sword = {AssetName = "sword"},
	rpg = {AssetName = "rpg"},
	btools = {AssetName = "BuildingTools"},
	tptool = {AssetName = "tptool"},
	pipe = {AssetName = "MetalPipe"},
	metalpipe = {AssetName = "MetalPipe"},
	banhammer = {AssetName = "BanHammer"},
	hammer = {AssetName = "BanHammer"},
	gravitygun = {AssetName = "GravityGun"},
	gravgun = {AssetName = "GravityGun"},
	freezeray = {AssetName = "FreezeRay"},
	icewand = {AssetName = "FreezeRay"},
	blackholecannon = {AssetName = "BlackHoleCannon"},
	singularity = {AssetName = "BlackHoleCannon"},
	bh = {AssetName = "BlackHoleCannon"},
	give = {Folder = "AdminTools"},
	toolrain = {Folder = "AdminTools"},
}

Settings.Ranks = {
	["Player"] = 0,
	["VIP"] = 1,
	["Moderator"] = 2,
	["Admin"] = 3,
	["HeadAdmin"] = 4,
	["Owner"] = 5,
	["Creator"] = 6,
}

Settings.PlayerRanks = {
	["gokuthug6"] = "Creator",
	["gokuthug0"] = "Creator",
	["iluvfnfppl"] = "Owner",
	["LJXBOXGMAER"] = "Owner",
	["32x977"] = "Owner",
}

local registry = {}

local function copyArray(list)
	local copy = {}
	for index, value in ipairs(list or {}) do
		copy[index] = value
	end
	return copy
end

local function prettyCommandName(name)
	local pretty = tostring(name or "")
	pretty = pretty:gsub("([a-z])([0-9])", "%1 %2")
	pretty = pretty:gsub("([0-9])([a-z])", "%1 %2")
	return pretty
end

local function defaultDescription(name)
	local lower = tostring(name or ""):lower()
	if lower:sub(1, 2) == "un" and #lower > 2 then
		return "Removes the " .. prettyCommandName(lower:sub(3)) .. " effect."
	end
	if lower:sub(1, 5) == "clear" and #lower > 5 then
		return "Clears " .. prettyCommandName(lower:sub(6)) .. "."
	end
	if lower:sub(1, 3) == "set" and #lower > 3 then
		return "Sets " .. prettyCommandName(lower:sub(4)) .. "."
	end
	if lower:sub(1, 3) == "add" and #lower > 3 then
		return "Adds to " .. prettyCommandName(lower:sub(4)) .. "."
	end
	if lower:sub(1, 6) == "remove" and #lower > 6 then
		return "Removes " .. prettyCommandName(lower:sub(7)) .. "."
	end
	if lower:sub(-3) == "all" and #lower > 3 then
		return "Applies " .. prettyCommandName(lower:sub(1, -4)) .. " to everyone."
	end
	return prettyCommandName(lower):gsub("^%l", string.upper) .. "."
end

local function register(name, data)
	name = tostring(name or ""):lower()
	assert(name ~= "", "Command name is required.")
	assert(not registry[name], "Duplicate canonical command: " .. tostring(name))

	local aliases = {}
	for _, alias in ipairs(data.Aliases or {}) do
		table.insert(aliases, tostring(alias):lower())
	end

	registry[name] = {
		Rank = data.Rank or "Player",
		Desc = data.Desc or defaultDescription(name),
		Aliases = aliases,
		TargetMode = data.TargetMode or "optional",
		ArgMode = data.ArgMode or "words",
		ValueFallback = data.ValueFallback == true,
		Args = copyArray(data.Args),
		Category = data.Category,
		Hidden = data.Hidden == true,
	}
end

local function registerBatch(entries, shared)
	for _, entry in ipairs(entries) do
		local data = {}
		for key, value in pairs(shared or {}) do
			data[key] = value
		end

		local name
		if type(entry) == "string" then
			name = entry
		else
			name = entry.Name
			for key, value in pairs(entry) do
				if key ~= "Name" then
					data[key] = value
				end
			end
		end

		register(name, data)
	end
end

-- // Command Registry //
register("permrank", {Rank = "Owner", Desc = "Permanently sets a player's admin rank.", TargetMode = "optional", Args = {{Name = "rank", Type = "rank"}}})
register("unpermrank", {Rank = "Owner", Desc = "Removes a player's permanent admin rank.", TargetMode = "optional"})
register("rank", {Rank = "Owner", Desc = "Gives a player a temporary admin rank.", TargetMode = "optional", Args = {{Name = "rank", Type = "rank"}}})
register("unrank", {Rank = "Owner", Desc = "Removes a player's temporary rank.", TargetMode = "optional"})
register("kill", {Rank = "Moderator", Desc = "Kills the target player.", TargetMode = "optional", Aliases = {"exterminate"}})
register("jump", {Rank = "VIP", Desc = "Forces the target to jump.", TargetMode = "optional"})
register("speed", {Rank = "VIP", Desc = "Sets a player's walk speed.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "speed", Type = "number", Hint = "16"}}})
register("to", {Rank = "Moderator", Desc = "Teleports you to the target player.", TargetMode = "optional", Aliases = {"tp"}})
register("freeze", {Rank = "Moderator", Desc = "Freezes the target player.", TargetMode = "optional"})
register("unfreeze", {Rank = "Moderator", Desc = "Unfreezes the target player.", TargetMode = "optional"})
register("invisible", {Rank = "Moderator", Desc = "Makes the player invisible.", TargetMode = "optional"})
register("visible", {Rank = "Moderator", Desc = "Restores the player's visibility.", TargetMode = "optional"})
register("heal", {Rank = "Admin", Desc = "Heals a player to full health.", TargetMode = "optional"})
register("god", {Rank = "Admin", Desc = "Makes a player invincible.", TargetMode = "optional"})
register("ungod", {Rank = "Admin", Desc = "Removes invincibility from a player.", TargetMode = "optional"})
register("bring", {Rank = "Admin", Desc = "Teleports the target player to you.", TargetMode = "optional"})
register("sit", {Rank = "VIP", Desc = "Forces the target to sit.", TargetMode = "optional"})
register("sword", {Rank = "VIP", Desc = "Gives the player a classic sword.", TargetMode = "optional"})
register("pipe", {Rank = "Admin", Desc = "Gives the heavy metal pipe tool with ragdoll knockback.", TargetMode = "optional", Aliases = {"metalpipe"}})
register("banhammer", {Rank = "HeadAdmin", Desc = "Gives the mythical Ban Hammer. Hits trigger lightning and kick/ban targets.", TargetMode = "optional", Aliases = {"hammer"}})
register("gravitygun", {Rank = "Admin", Desc = "Gives the zero-point Gravity Gun to grab, levitate, and fling objects/players.", TargetMode = "optional", Aliases = {"gravgun"}})
register("freezeray", {Rank = "Admin", Desc = "Gives the Freeze Ray wand that encases targets in a crystal ice cube.", TargetMode = "optional", Aliases = {"icewand"}})
register("panel", {Rank = "Moderator", Desc = "Toggles the Executive Admin Dashboard tablet GUI.", TargetMode = "none", Aliases = {"dashboard"}})
register("explode", {Rank = "Admin", Desc = "Creates an explosion at the player's position.", TargetMode = "optional"})
register("loopkill", {Rank = "HeadAdmin", Desc = "Continuously kills the target.", TargetMode = "optional"})
register("unloopkill", {Rank = "HeadAdmin", Desc = "Stops loopkilling the target.", TargetMode = "optional"})
register("btools", {Rank = "Admin", Desc = "Gives building tools.", TargetMode = "optional"})
register("fling", {Rank = "Admin", Desc = "Sends the player flying.", TargetMode = "optional"})
register("ff", {Rank = "Admin", Desc = "Gives a player a forcefield.", TargetMode = "optional"})
register("unff", {Rank = "Admin", Desc = "Removes a player's forcefield.", TargetMode = "optional"})
register("hff", {Rank = "Admin", Desc = "Hides the player's forcefield.", TargetMode = "optional"})
register("kick", {Rank = "Admin", Desc = "Removes a player from the server.", TargetMode = "optional", ArgMode = "rest", Args = {{Name = "reason", Type = "text"}}})
register("damage", {Rank = "Admin", Desc = "Deals a specific amount of damage.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "amount", Type = "number", Hint = "10"}}})
register("clone", {Rank = "Admin", Desc = "Clones the target player's character.", TargetMode = "optional"})
register("jail", {Rank = "Admin", Desc = "Puts the player in a jail cell.", TargetMode = "optional"})
register("unjail", {Rank = "Admin", Desc = "Removes the player's jail cell.", TargetMode = "optional"})
register("rpg", {Rank = "Admin", Desc = "Gives a rocket launcher.", TargetMode = "optional"})
register("rejoin", {Rank = "Player", Desc = "Forces you to rejoin the game.", TargetMode = "none", Aliases = {"rj"}})
register("tptool", {Rank = "Admin", Desc = "Gives a click-to-teleport tool.", TargetMode = "optional"})
register("tbomb", {Rank = "Admin", Desc = "Gives a TimeBomb that explodes after a delay.", TargetMode = "optional", Aliases = {"timebomb"}})
register("re", {Rank = "Moderator", Desc = "Respawns the player at their current position.", TargetMode = "optional"})
register("loadmap", {Rank = "HeadAdmin", Desc = "Reloads the backed-up map.", TargetMode = "none"})
register("fly", {Rank = "Admin", Desc = "Enables flying for the player.", TargetMode = "optional"})
register("unfly", {Rank = "Admin", Desc = "Disables flying for the player.", TargetMode = "optional"})
register("char", {Rank = "Admin", Desc = "Changes the player's avatar to a specific user.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "username", Type = "player"}}})
register("gear", {Rank = "Admin", Desc = "Gives a tool by asset ID.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "assetId", Type = "number", Hint = "AssetID"}}})
register("talk", {Rank = "Admin", Desc = "Forces the target to say something.", TargetMode = "optional", ArgMode = "rest", ValueFallback = true, Args = {{Name = "message", Type = "text"}}})
register("erain", {Rank = "Admin", Desc = "Makes it rain bombs.", TargetMode = "optional"})
register("ls", {Rank = "Admin", Desc = "Strikes the player with lightning.", TargetMode = "optional"})
register("light", {Rank = "Admin", Desc = "Attaches a light source to the player.", TargetMode = "optional"})
register("unlight", {Rank = "Admin", Desc = "Removes the attached light.", TargetMode = "optional"})
register("gflip", {Rank = "Admin", Desc = "Flips the player and launches them upward.", TargetMode = "optional"})
register("noclip", {Rank = "Admin", Desc = "Allows the player to walk through walls.", TargetMode = "optional"})
register("clip", {Rank = "Admin", Desc = "Disables noclip.", TargetMode = "optional"})
register("spike", {Rank = "Admin", Desc = "Spawns deadly spikes around a player.", TargetMode = "optional"})
register("unspike", {Rank = "Admin", Desc = "Removes all admin spikes from the map.", TargetMode = "none"})
register("ban", {Rank = "Owner", Desc = "Bans a player from the server.", TargetMode = "optional", ArgMode = "rest", Args = {{Name = "reason", Type = "text"}}})
register("unban", {Rank = "Owner", Desc = "Opens the unban list or unbans a specific username.", TargetMode = "none", Args = {{Name = "username", Type = "text"}}})
register("pm", {Rank = "Moderator", Desc = "Sends a private message popup to a player.", TargetMode = "optional", ArgMode = "rest", Args = {{Name = "message", Type = "text"}}})
register("color", {Rank = "Moderator", Desc = "Changes the color of the player's body parts.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("size", {Rank = "Admin", Desc = "Scales the player's overall size.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "scale", Type = "number", Hint = "1"}}})
register("aura", {Rank = "Admin", Desc = "Gives the player a glowing aura.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unaura", {Rank = "Admin", Desc = "Removes the player's aura.", TargetMode = "optional"})
register("tkill", {Rank = "HeadAdmin", Desc = "Kills the target after a short delay.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "seconds", Type = "number", Hint = "1"}}})
register("gravity", {Rank = "Admin", Desc = "Sets the workspace gravity.", TargetMode = "none", Args = {{Name = "value", Type = "number", Hint = "196.2"}}})
register("flip", {Rank = "Admin", Desc = "Flips the player upside down.", TargetMode = "optional"})
register("rocket", {Rank = "HeadAdmin", Desc = "Launches the player into the sky like a rocket.", TargetMode = "optional"})
register("kaura", {Rank = "HeadAdmin", Desc = "Gives the player a deadly kill aura sphere.", TargetMode = "optional"})
register("cmds", {Rank = "VIP", Desc = "Shows the canonical command list.", TargetMode = "none"})
register("warp", {Rank = "Creator", Desc = "Warps a player to a preset dimension.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "dimension", Type = "list", Values = {"test", "ohio"}}}})
register("rlist", {Rank = "Player", Desc = "Shows the online player ranks.", TargetMode = "none", Aliases = {"ranks"}})
register("logs", {Rank = "Moderator", Desc = "Shows the server command logs with timestamps.", TargetMode = "none"})
register("crl", {Rank = "Player", Desc = "Shows command permission requirements.", TargetMode = "none", Aliases = {"clr"}})
register("smoke", {Rank = "VIP", Desc = "Attaches smoke to the player.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unsmoke", {Rank = "VIP", Desc = "Removes the smoke effect.", TargetMode = "optional"})
register("fire", {Rank = "VIP", Desc = "Sets the player on fire.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unfire", {Rank = "VIP", Desc = "Extinguishes the player.", TargetMode = "optional"})
register("shutdown", {Rank = "Owner", Desc = "Shuts down the current server.", TargetMode = "none"})
register("thin", {Rank = "VIP", Desc = "Makes the player character thin.", TargetMode = "optional"})
register("unthin", {Rank = "VIP", Desc = "Resets the player's thickness.", TargetMode = "optional"})
register("fat", {Rank = "VIP", Desc = "Makes the player character wider.", TargetMode = "optional"})
register("unfat", {Rank = "VIP", Desc = "Resets the player's width.", TargetMode = "optional"})
register("width", {Rank = "VIP", Desc = "Sets the player's width scale.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "scale", Type = "number", Hint = "1"}}})
register("height", {Rank = "VIP", Desc = "Sets the player's height scale.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "scale", Type = "number", Hint = "1"}}})
register("mute", {Rank = "HeadAdmin", Desc = "Prevents the player from chatting.", TargetMode = "optional"})
register("unmute", {Rank = "HeadAdmin", Desc = "Allows the player to chat again.", TargetMode = "optional"})
register("chatcolor", {Rank = "Admin", Desc = "Sets a player's chat color or resets it.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("health", {Rank = "Moderator", Desc = "Sets a player's health.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "amount", Type = "number", Hint = "100"}}})
register("title", {Rank = "Admin", Desc = "Places floating text above a player's head.", TargetMode = "optional", ArgMode = "words", ValueFallback = true, Args = {{Name = "color", Type = "color"}, {Name = "text", Type = "text"}}})
register("untitle", {Rank = "Admin", Desc = "Removes the floating title text.", TargetMode = "optional"})
register("spin", {Rank = "Moderator", Desc = "Makes the player spin rapidly.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "speed", Type = "number", Hint = "10"}}})
register("unspin", {Rank = "Moderator", Desc = "Stops the player's spin effect.", TargetMode = "optional"})
register("flashbang", {Rank = "Admin", Desc = "Triggers a blinding flash effect.", TargetMode = "optional"})
register("npc", {Rank = "Moderator", Desc = "Spawns a player NPC in front of the target.", TargetMode = "optional"})
register("blackhole", {Rank = "Creator", Desc = "Creates a black hole that pulls players in.", TargetMode = "optional"})
register("laydown", {Rank = "Player", Desc = "Forces the player into a laying-down pose until they jump or are released.", TargetMode = "optional"})
register("unlaydown", {Rank = "Player", Desc = "Restores the player's normal standing pose.", TargetMode = "optional"})
register("notify", {Rank = "Admin", Desc = "Sends a popup notification to a player.", TargetMode = "optional", ArgMode = "rest", ValueFallback = true, Args = {{Name = "message", Type = "text"}}})
register("blind", {Rank = "Admin", Desc = "Turns the player's screen black.", TargetMode = "optional"})
register("unblind", {Rank = "Admin", Desc = "Restores the player's vision.", TargetMode = "optional"})
register("m", {Rank = "Creator", Desc = "Displays a system message to everyone.", TargetMode = "none", ArgMode = "rest", Aliases = {"message"}, Args = {{Name = "message", Type = "text"}}})
register("team", {Rank = "Admin", Desc = "Opens the team creation menu.", TargetMode = "none"})
register("sparkles", {Rank = "VIP", Desc = "Adds sparkles to the player.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unsparkles", {Rank = "VIP", Desc = "Removes the sparkles effect.", TargetMode = "optional"})
register("trail", {
	Rank = "VIP",
	Desc = "Gives the player a two-color trail or a rainbow trail.",
	TargetMode = "optional",
	ValueFallback = true,
	Args = {
		{Name = "primaryColor", Type = "color", Values = {"rainbow"}, TerminalValues = {"rainbow"}},
		{Name = "secondaryColor", Type = "color", Optional = true},
	},
})
register("untrail", {Rank = "VIP", Desc = "Removes the player's trail.", TargetMode = "optional"})
register("bighead", {Rank = "VIP", Desc = "Makes the player's head bigger.", TargetMode = "optional"})
register("dwarf", {Rank = "VIP", Desc = "Makes the player small.", TargetMode = "optional"})
register("giant", {Rank = "VIP", Desc = "Makes the player large.", TargetMode = "optional"})
register("clean", {Rank = "Admin", Desc = "Cleans dropped tools and spawned admin items.", TargetMode = "none"})
register("superf", {Rank = "Admin", Desc = "Super flings the target extremely far.", TargetMode = "optional", Aliases = {"superfling"}})
register("prefix", {Rank = "VIP", Desc = "Sets your personal command prefix.", TargetMode = "none", Args = {{Name = "prefix", Type = "text"}}})
register("headless", {Rank = "VIP", Desc = "Makes the player's head invisible.", TargetMode = "optional"})
register("unheadless", {Rank = "VIP", Desc = "Restores the player's head visibility.", TargetMode = "optional"})
register("image", {Rank = "Admin", Desc = "Sends an image ID to chat.", TargetMode = "optional", ValueFallback = true, Aliases = {"img"}, Args = {{Name = "assetId", Type = "number", Hint = "AssetID"}}})
register("r6", {Rank = "Moderator", Desc = "Respawns the target as an R6 avatar.", TargetMode = "optional"})
register("r15", {Rank = "Moderator", Desc = "Respawns the target as an R15 avatar.", TargetMode = "optional"})
register("magnetize", {Rank = "Admin", Desc = "Makes other players stick to the target.", TargetMode = "optional"})
register("swap", {Rank = "Moderator", Desc = "Swaps your position with a random player.", TargetMode = "none"})
register("control", {Rank = "Admin", Desc = "Takes control of the target player's body.", TargetMode = "optional"})
register("uncontrol", {Rank = "Admin", Desc = "Returns you to your original body.", TargetMode = "none"})
register("material", {Rank = "VIP", Desc = "Sets the player's material using Settings.Materials.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "material", Type = "material"}}})
register("day", {Rank = "Admin", Desc = "Sets the clock time to 14:00.", TargetMode = "none"})
register("night", {Rank = "Admin", Desc = "Sets the clock time to 21:00.", TargetMode = "none"})
register("midnight", {Rank = "Admin", Desc = "Sets the clock time to 00:00.", TargetMode = "none"})
register("noon", {Rank = "Admin", Desc = "Sets the clock time to 12:00.", TargetMode = "none"})
register("morning", {Rank = "Admin", Desc = "Sets the clock time to 08:00.", TargetMode = "none"})
register("evening", {Rank = "Admin", Desc = "Sets the clock time to 18:00.", TargetMode = "none"})
register("dawn", {Rank = "Admin", Desc = "Sets the clock time to 06:00.", TargetMode = "none"})
register("dusk", {Rank = "Admin", Desc = "Sets the clock time to 19:00.", TargetMode = "none"})
register("slippery", {Rank = "VIP", Desc = "Makes the player slippery.", TargetMode = "optional"})
register("unslippery", {Rank = "VIP", Desc = "Restores normal friction.", TargetMode = "optional"})
register("trip", {Rank = "VIP", Desc = "Trips the player and knocks them down briefly.", TargetMode = "optional"})
register("slam", {Rank = "Admin", Desc = "Slams the player downward.", TargetMode = "optional", Args = {{Name = "force", Type = "number", Hint = "150"}}})
register("noarms", {Rank = "VIP", Desc = "Hides the player's arms.", TargetMode = "optional"})
register("nolegs", {Rank = "VIP", Desc = "Hides the player's legs.", TargetMode = "optional"})
register("blur", {Rank = "Admin", Desc = "Blurs the target's screen.", TargetMode = "optional", ValueFallback = true, Aliases = {"blureffect"}, Args = {{Name = "size", Type = "number", Hint = "24"}}})
register("unblur", {Rank = "Admin", Desc = "Removes the target's blur effect.", TargetMode = "optional", Aliases = {"unblureffect"}})
register("colorcorrection", {Rank = "Admin", Desc = "Adds color correction to the target's screen.", TargetMode = "optional"})
register("uncolorcorrection", {Rank = "Admin", Desc = "Removes the target's color correction effect.", TargetMode = "optional"})
register("anchor", {Rank = "Admin", Desc = "Anchors the player's character.", TargetMode = "optional"})
register("unanchor", {Rank = "Admin", Desc = "Unanchors the player's character.", TargetMode = "optional"})
register("whois", {Rank = "Moderator", Desc = "Shows detailed info about a player.", TargetMode = "optional"})
register("lockcmds", {Rank = "HeadAdmin", Desc = "Locks all commands or a specific command for non-exempt players.", TargetMode = "none", Args = {{Name = "command", Type = "command"}}})
register("unlockcmds", {Rank = "HeadAdmin", Desc = "Unlocks all commands or a specific command.", TargetMode = "none", Args = {{Name = "command", Type = "command"}}})
register("clearlogs", {Rank = "HeadAdmin", Desc = "Clears the session command log.", TargetMode = "none"})
register("follow", {Rank = "Moderator", Desc = "Makes the target follow you.", TargetMode = "optional"})
register("unfollow", {Rank = "Moderator", Desc = "Stops the target from following you.", TargetMode = "optional"})
register("stack", {Rank = "Moderator", Desc = "Stacks the target players above you.", TargetMode = "optional"})
register("halo", {Rank = "VIP", Desc = "Adds a glowing halo over the player.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unhalo", {Rank = "VIP", Desc = "Removes the halo.", TargetMode = "optional"})
register("horns", {Rank = "VIP", Desc = "Adds horns to the player's head.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unhorns", {Rank = "VIP", Desc = "Removes the horns.", TargetMode = "optional"})
register("wings", {Rank = "VIP", Desc = "Adds wings to the player's back.", TargetMode = "optional"})
register("unwings", {Rank = "VIP", Desc = "Removes the wings.", TargetMode = "optional"})
register("cape", {Rank = "VIP", Desc = "Adds a cape to the player's back.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("uncape", {Rank = "VIP", Desc = "Removes the cape.", TargetMode = "optional"})
register("rainbow", {Rank = "VIP", Desc = "Cycles the player's colors in a rainbow.", TargetMode = "optional"})
register("unrainbow", {Rank = "VIP", Desc = "Stops the rainbow effect.", TargetMode = "optional"})
register("outline", {Rank = "VIP", Desc = "Adds an outline highlight to the player.", TargetMode = "optional", ValueFallback = true, Args = {{Name = "color", Type = "color"}}})
register("unoutline", {Rank = "VIP", Desc = "Removes the outline highlight.", TargetMode = "optional"})
register("chrome", {Rank = "VIP", Desc = "Makes the player look chrome.", TargetMode = "optional"})
register("unchrome", {Rank = "VIP", Desc = "Removes the chrome material.", TargetMode = "optional"})
register("unneon", {Rank = "VIP", Desc = "Removes the neon material.", TargetMode = "optional"})
register("fullbright", {Rank = "Admin", Desc = "Turns on a full-bright lighting preset.", TargetMode = "none"})
register("unfullbright", {Rank = "Admin", Desc = "Restores default lighting brightness.", TargetMode = "none"})
register("sepia", {Rank = "Admin", Desc = "Applies a sepia tone to the world.", TargetMode = "none"})
register("unsepia", {Rank = "Admin", Desc = "Removes the sepia tone.", TargetMode = "none"})
register("disco", {Rank = "Admin", Desc = "Cycles the world's lighting colors.", TargetMode = "none"})
register("undisco", {Rank = "Admin", Desc = "Stops the disco lighting loop.", TargetMode = "none"})
register("time", {Rank = "Admin", Desc = "Sets the server's clock time to a specific number.", TargetMode = "none", Args = {{Name = "hour", Type = "number", Hint = "14"}}})

-- // Hardened Expansion Registry //
registerBatch({
	{Name = "warn", ArgMode = "rest", Args = {{Name = "reason", Type = "text"}}},
	{Name = "unwarn", Args = {{Name = "warningIndex", Type = "number", Hint = "1"}}},
	"warnings",
	{Name = "tempmute", ArgMode = "words", Args = {{Name = "seconds", Type = "number", Hint = "60"}, {Name = "reason", Type = "text"}}},
	{Name = "tempban", Rank = "Owner", ArgMode = "words", Args = {{Name = "seconds", Type = "number", Hint = "600"}, {Name = "reason", Type = "text"}}},
	{Name = "softban", Rank = "Owner", ArgMode = "rest", Args = {{Name = "reason", Type = "text"}}},
	"banreason",
	{Name = "chatlogs", TargetMode = "none"},
	{Name = "joinlogs", TargetMode = "none"},
	{Name = "leavelogs", TargetMode = "none"},
	{Name = "deathlogs", TargetMode = "none"},
	{Name = "serverlock", Rank = "HeadAdmin", TargetMode = "none", Args = {{Name = "minimumRank", Type = "rank"}}},
	{Name = "unlockserver", Rank = "HeadAdmin", TargetMode = "none"},
	{Name = "whitelist", Rank = "Owner", TargetMode = "none", Args = {{Name = "username", Type = "text"}}},
	{Name = "unwhitelist", Rank = "Owner", TargetMode = "none", Args = {{Name = "username", Type = "text"}}},
	{Name = "shadowban", Rank = "Owner", ArgMode = "rest", Aliases = {"ghostban"}, Args = {{Name = "reason", Type = "text"}}},
	{Name = "unshadowban", Rank = "Owner", Aliases = {"unghostban"}},
}, {Rank = "Moderator", Category = "Moderation"})

registerBatch({
	{Name = "tospawn", Rank = "Moderator"},
	{Name = "setspawn", Rank = "Admin"},
	{Name = "removespawn", Rank = "Admin"},
	{Name = "waypoint", Rank = "Player", TargetMode = "none"},
	{Name = "clearwaypoint", Rank = "Player", TargetMode = "none"},
}, {Category = "Teleport"})

registerBatch({
	{Name = "jumppower", Rank = "VIP", ValueFallback = true, Args = {{Name = "jumpPower", Type = "number", Hint = "50"}}},
	{Name = "unjumppower", Rank = "VIP"},
	{Name = "hipheight", Rank = "VIP", ValueFallback = true, Args = {{Name = "hipHeight", Type = "number", Hint = "2"}}},
	{Name = "unhipheight", Rank = "VIP"},
	{Name = "depth", Rank = "VIP", ValueFallback = true, Args = {{Name = "scale", Type = "number", Hint = "1"}}},
	{Name = "undepth", Rank = "VIP"},
	{Name = "unboing", Rank = "VIP"},
	{Name = "knockback", Rank = "Moderator", Args = {{Name = "force", Type = "number", Hint = "120"}}},
	{Name = "stun", Rank = "Moderator"},
	{Name = "unstun", Rank = "Moderator"},
	{Name = "ragdoll", Rank = "Moderator"},
	{Name = "unragdoll", Rank = "Moderator"},
	{Name = "massless", Rank = "VIP"},
	{Name = "unmassless", Rank = "VIP"},
	{Name = "gravityscale", Rank = "Admin", ValueFallback = true, Args = {{Name = "scale", Type = "number", Hint = "1"}}},
}, {Category = "Movement"})

registerBatch({
	{Name = "headsize", Rank = "VIP", ValueFallback = true, Args = {{Name = "scale", Type = "number", Hint = "1.5"}}},
	{Name = "unheadsize", Rank = "VIP"},
	{Name = "shirt", Rank = "Admin", ValueFallback = true, Args = {{Name = "assetId", Type = "number", Hint = "123456"}}},
	{Name = "unshirt", Rank = "Admin"},
	{Name = "pants", Rank = "Admin", ValueFallback = true, Args = {{Name = "assetId", Type = "number", Hint = "123456"}}},
	{Name = "unpants", Rank = "Admin"},
	{Name = "face", Rank = "Admin", ValueFallback = true, Args = {{Name = "assetId", Type = "number", Hint = "123456"}}},
	{Name = "unface", Rank = "Admin"},
	{Name = "hat", Rank = "Admin", ValueFallback = true, Args = {{Name = "assetId", Type = "number", Hint = "123456"}}},
	{Name = "unhat", Rank = "Admin"},
	{Name = "displayname", Rank = "Admin", ValueFallback = true, ArgMode = "rest", Args = {{Name = "displayName", Type = "text"}}},
	{Name = "undisplayname", Rank = "Admin"},
	{Name = "transparency", Rank = "VIP", ValueFallback = true, Args = {{Name = "alpha", Type = "number", Hint = "0.5"}}},
	{Name = "untransparency", Rank = "VIP"},
	{Name = "reflectance", Rank = "VIP", ValueFallback = true, Args = {{Name = "value", Type = "number", Hint = "0.2"}}},
	{Name = "unreflectance", Rank = "VIP"},
	{Name = "bundle", Rank = "Admin", ValueFallback = true, Args = {{Name = "bundleId", Type = "number", Hint = "123456"}}},
}, {Category = "Avatar"})

registerBatch({
	{Name = "xray", Rank = "Admin"},
	{Name = "unxray", Rank = "Admin"},
}, {Category = "Visual"})

registerBatch({
	{Name = "ambient", Rank = "Admin", TargetMode = "none", ValueFallback = true, Args = {{Name = "color", Type = "color"}}},
	{Name = "outdoorambient", Rank = "Admin", TargetMode = "none", ValueFallback = true, Args = {{Name = "color", Type = "color"}}},
	{Name = "brightness", Rank = "Admin", TargetMode = "none", Args = {{Name = "value", Type = "number", Hint = "2"}}},
	{Name = "unshadows", Rank = "Admin", TargetMode = "none"},
	{Name = "music", Rank = "Admin", TargetMode = "none", ValueFallback = true, Args = {{Name = "audioId", Type = "number", Hint = "123456"}}},
	{Name = "volume", Rank = "Admin", TargetMode = "none", Args = {{Name = "value", Type = "number", Hint = "0.5"}}},
	{Name = "rain", Rank = "Admin", TargetMode = "none"},
	{Name = "unrain", Rank = "Admin", TargetMode = "none"},
	{Name = "snow", Rank = "Admin", TargetMode = "none"},
	{Name = "unsnow", Rank = "Admin", TargetMode = "none"},
	{Name = "unwind", Rank = "Admin", TargetMode = "none"},
	{Name = "eclipse", Rank = "Admin", TargetMode = "none"},
	{Name = "uneclipse", Rank = "Admin", TargetMode = "none"},
	{Name = "sunrise", Rank = "Admin", TargetMode = "none"},
	{Name = "sunset", Rank = "Admin", TargetMode = "none"},
	{Name = "rainbowworld", Rank = "Admin", TargetMode = "none"},
}, {Category = "World"})

registerBatch({
	{Name = "closevote", Rank = "Moderator", TargetMode = "none"},
	{Name = "credits", Rank = "Player", TargetMode = "none"},
	{Name = "banlist", Rank = "Moderator", TargetMode = "none"},
	{Name = "toolsui", Rank = "Moderator", TargetMode = "none"},
	{Name = "aliases", Rank = "Player", TargetMode = "none"},
	{Name = "hideguis", Rank = "VIP"},
	{Name = "showguis", Rank = "VIP"},
	{Name = "countdown", Rank = "Admin", TargetMode = "none", Args = {{Name = "seconds", Type = "number", Hint = "10"}, {Name = "message", Type = "text"}}},
	{Name = "cancelcountdown", Rank = "Admin", TargetMode = "none"},
}, {Category = "UI"})

registerBatch({
	{Name = "give", Rank = "Admin", ValueFallback = true, Args = {{Name = "toolName", Type = "text"}}},
	{Name = "toolrain", Rank = "Admin", ValueFallback = true, Args = {{Name = "toolName", Type = "text"}}},
	{Name = "cleargear", Rank = "Admin"},
	{Name = "refresh", Rank = "Moderator"},
	{Name = "resetstats", Rank = "Admin"},
	{Name = "setstat", Rank = "Admin", Args = {{Name = "statName", Type = "text"}, {Name = "value", Type = "number", Hint = "0"}}},
	{Name = "addstat", Rank = "Admin", Args = {{Name = "statName", Type = "text"}, {Name = "value", Type = "number", Hint = "1"}}},
	{Name = "removestat", Rank = "Admin", Args = {{Name = "statName", Type = "text"}}},
	{Name = "dance", Rank = "VIP"},
	{Name = "undance", Rank = "VIP"},
	{Name = "laugh", Rank = "VIP"},
	{Name = "cheer", Rank = "VIP"},
	{Name = "wave", Rank = "VIP"},
	{Name = "salute", Rank = "VIP"},
	{Name = "zombie", Rank = "VIP"},
	{Name = "unzombie", Rank = "VIP"},
}, {Category = "Gameplay"})

register("snapshot", {Rank = "Admin", Category = "World", TargetMode = "none", ArgMode = "words", Aliases = {"snap"}, Args = {{Name = "action", Type = "list", Values = {"save", "list", "clear"}}, {Name = "name", Type = "text", Optional = true}}})
register("rollback", {Rank = "HeadAdmin", Category = "World", TargetMode = "none", ArgMode = "words", Aliases = {"undomap", "maprestore"}, Args = {{Name = "name", Type = "text", Optional = true}}})
register("undo", {Rank = "HeadAdmin", Category = "World", TargetMode = "none"})
register("freecam", {Rank = "Moderator", Category = "Visual", TargetMode = "none", Aliases = {"cam", "cinematic"}})
register("drone", {Rank = "Moderator", Category = "Visual", TargetMode = "none"})
register("undrone", {Rank = "Moderator", Category = "Visual", TargetMode = "none", Aliases = {"unfreecam"}})
register("blackholecannon", {Rank = "HeadAdmin", Category = "Gameplay", Aliases = {"singularitycannon"}})
register("rewind", {Rank = "Moderator", Category = "Gameplay", ValueFallback = true, Aliases = {"timerewind", "timewarp"}, Args = {{Name = "seconds", Type = "number", Hint = "5"}}})
register("macro", {Rank = "HeadAdmin", Category = "Moderation", TargetMode = "none", ArgMode = "rest", Aliases = {"setmacro"}, Args = {{Name = "action", Type = "text"}}})

-- // Colors //
Settings.Colors = {
	red = Color3.fromRGB(255, 0, 0),
	green = Color3.fromRGB(0, 255, 0),
	blue = Color3.fromRGB(0, 0, 255),
	yellow = Color3.fromRGB(255, 255, 0),
	white = Color3.fromRGB(255, 255, 255),
	black = Color3.fromRGB(0, 0, 0),
	orange = Color3.fromRGB(255, 165, 0),
	purple = Color3.fromRGB(128, 0, 128),
	pink = Color3.fromRGB(255, 192, 203),
	brown = Color3.fromRGB(165, 42, 42),
	cyan = Color3.fromRGB(0, 255, 255),
	magenta = Color3.fromRGB(255, 0, 255),
	gray = Color3.fromRGB(128, 128, 128),
	lgray = Color3.fromRGB(211, 211, 211),
	dgray = Color3.fromRGB(169, 169, 169),
	lblue = Color3.fromRGB(173, 216, 230),
	lgreen = Color3.fromRGB(144, 238, 144),
	lyellow = Color3.fromRGB(255, 255, 224),
	lpink = Color3.fromRGB(255, 182, 193),
	dred = Color3.fromRGB(139, 0, 0),
	dgreen = Color3.fromRGB(0, 100, 0),
	dblue = Color3.fromRGB(0, 0, 139),
	dyellow = Color3.fromRGB(255, 215, 0),
	dpurple = Color3.fromRGB(75, 0, 130),
	dorange = Color3.fromRGB(255, 140, 0),
	dcyan = Color3.fromRGB(0, 139, 139),
	dmagenta = Color3.fromRGB(139, 0, 139),
	dpink = Color3.fromRGB(255, 105, 180),
	gold = Color3.fromRGB(255, 215, 0),
	silver = Color3.fromRGB(192, 192, 192),
	bronze = Color3.fromRGB(205, 127, 50),
	teal = Color3.fromRGB(0, 128, 128),
	indigo = Color3.fromRGB(75, 0, 130),
	violet = Color3.fromRGB(238, 130, 238),
	lavender = Color3.fromRGB(230, 230, 250),
	coral = Color3.fromRGB(255, 127, 80),
	salmon = Color3.fromRGB(250, 128, 114),
	plum = Color3.fromRGB(221, 160, 221),
	olive = Color3.fromRGB(128, 128, 0),
	khaki = Color3.fromRGB(240, 230, 140),
	mint = Color3.fromRGB(189, 252, 201),
	peach = Color3.fromRGB(255, 218, 185),
	chartreuse = Color3.fromRGB(127, 255, 0),
	sienna = Color3.fromRGB(160, 82, 45),
	rose = Color3.fromRGB(255, 0, 127),
	navy = Color3.fromRGB(0, 0, 128),
	taupe = Color3.fromRGB(72, 60, 50),
	periwinkle = Color3.fromRGB(204, 204, 255),
	azure = Color3.fromRGB(0, 127, 255),
	emerald = Color3.fromRGB(80, 200, 120),
	rust = Color3.fromRGB(183, 65, 14),
	mauve = Color3.fromRGB(224, 176, 255),
	apricot = Color3.fromRGB(251, 206, 177),
	amethyst = Color3.fromRGB(153, 102, 204),
	mintcream = Color3.fromRGB(245, 255, 250),
	antiqueWhite = Color3.fromRGB(250, 235, 215),
	beige = Color3.fromRGB(245, 245, 220),
	bisque = Color3.fromRGB(255, 228, 196),
	blanchedAlmond = Color3.fromRGB(255, 235, 205),
	cornflowerBlue = Color3.fromRGB(100, 149, 237),
	darkOliveGreen = Color3.fromRGB(85, 107, 47),
	aliceBlue = Color3.fromRGB(240, 248, 255),
	ivory = Color3.fromRGB(255, 255, 240),
	honeydew = Color3.fromRGB(240, 255, 240),
	lavenderBlush = Color3.fromRGB(255, 240, 245),
	lightCyan = Color3.fromRGB(224, 255, 255),
	lightGoldenrodYellow = Color3.fromRGB(250, 250, 210),
	lightPink = Color3.fromRGB(255, 182, 193),
	lightSalmon = Color3.fromRGB(255, 160, 122),
	lightSkyBlue = Color3.fromRGB(135, 206, 250),
	lightSlateGray = Color3.fromRGB(119, 136, 153),
	lightSteelBlue = Color3.fromRGB(176, 196, 222),
	mediumAquaMarine = Color3.fromRGB(102, 205, 170),
	mediumBlue = Color3.fromRGB(0, 0, 205),
	mediumOrchid = Color3.fromRGB(186, 85, 211),
	mediumPurple = Color3.fromRGB(147, 112, 219),
	mediumSeaGreen = Color3.fromRGB(60, 179, 113),
	mediumSlateBlue = Color3.fromRGB(123, 104, 238),
	mediumSpringGreen = Color3.fromRGB(0, 250, 154),
	mediumTurquoise = Color3.fromRGB(72, 209, 204),
	mediumVioletRed = Color3.fromRGB(199, 21, 133),
	midnightBlue = Color3.fromRGB(25, 25, 112),
	moccasin = Color3.fromRGB(255, 228, 181),
	oldLace = Color3.fromRGB(253, 245, 230),
	paleGoldenrod = Color3.fromRGB(252, 253, 150),
	paleGreen = Color3.fromRGB(152, 251, 152),
	paleTurquoise = Color3.fromRGB(175, 238, 238),
	paleVioletRed = Color3.fromRGB(219, 112, 147),
	papayaWhip = Color3.fromRGB(255, 239, 213),
	peachPuff = Color3.fromRGB(255, 218, 185),
	seashell = Color3.fromRGB(255, 245, 238),
	skyBlue = Color3.fromRGB(135, 206, 235),
	slateBlue = Color3.fromRGB(106, 90, 205),
	slateGray = Color3.fromRGB(112, 128, 144),
	snow = Color3.fromRGB(255, 250, 250),
	springGreen = Color3.fromRGB(0, 255, 127),
	steelBlue = Color3.fromRGB(70, 130, 180),
	tan = Color3.fromRGB(210, 180, 140),
	thistle = Color3.fromRGB(216, 191, 216),
	tomato = Color3.fromRGB(255, 99, 71),
	transparent = Color3.fromRGB(0, 0, 0),
	wheat = Color3.fromRGB(245, 222, 179),
	yellowGreen = Color3.fromRGB(154, 205, 50),
}

-- // Materials //
Settings.Materials = {
	neon = Enum.Material.Neon,
	glass = Enum.Material.Glass,
	forcefield = Enum.Material.ForceField,
	wood = Enum.Material.Wood,
	plastic = Enum.Material.Plastic,
	ice = Enum.Material.Ice,
	marble = Enum.Material.Marble,
	granite = Enum.Material.Granite,
	pebble = Enum.Material.Pebble,
	brick = Enum.Material.Brick,
	sand = Enum.Material.Sand,
	fabric = Enum.Material.Fabric,
	slate = Enum.Material.Slate,
	concrete = Enum.Material.Concrete,
	corrodedmetal = Enum.Material.CorrodedMetal,
	foil = Enum.Material.Foil,
	grass = Enum.Material.Grass,
	metal = Enum.Material.Metal,
	smoothplastic = Enum.Material.SmoothPlastic,
}

Settings.CommandRegistry = registry
Settings.CommandRanks = {}
Settings.Aliases = {}
Settings.Commands = {}
Settings.AllCommands = {}
Settings.HiddenCommands = {}
Settings.TotalCommands = 0
Settings.VisibleCommandCount = 0
Settings.RegistryCount = 0

local function inferCategory(name, meta)
	if meta and meta.Category then
		return meta.Category
	end

	if name:find("rank") or name:find("ban") or name:find("kick") or name:find("warn")
		or name:find("log") or name == "pm" or name == "whois"
		or name == "shutdown" or name:find("lock") or name:find("whitelist") then
		return "Moderation"
	end

	if name == "to" or name == "tp" or name:find("teleport") or name:find("bring")
		or name:find("spawn") or name == "swap" or name == "warp" or name == "follow"
		or name == "unfollow" or name == "stack"
		or name == "waypoint" or name == "clearwaypoint" then
		return "Teleport"
	end

	if name == "fly" or name == "unfly" or name == "noclip" or name == "clip"
		or name == "speed" or name == "jump" or name == "jumppower" or name == "unjumppower"
		or name == "hipheight" or name == "unhipheight" or name == "gravityscale" or name == "gravity"
		or name == "stun" or name == "unstun" or name == "ragdoll" or name == "unragdoll"
		or name == "unboing"
		or name == "knockback" or name == "slippery" or name == "unslippery" or name == "trip" or name == "slam"
		or name == "rocket" or name == "fling" or name == "superf" then
		return "Movement"
	end

	if name == "char" or name == "r6" or name == "r15" or name == "headless" or name == "unheadless"
		or name == "thin" or name == "unthin" or name == "fat" or name == "unfat"
		or name == "width" or name == "height" or name == "depth" or name == "undepth" or name == "size" or name == "bighead"
		or name == "dwarf" or name == "giant" or name == "headsize" or name == "unheadsize"
		or name == "shirt" or name == "unshirt" or name == "pants" or name == "unpants"
		or name == "face" or name == "unface" or name == "hat" or name == "unhat"
		or name == "displayname" or name == "undisplayname"
		or name == "bundle" or name == "transparency" or name == "untransparency"
		or name == "reflectance" or name == "unreflectance" then
		return "Avatar"
	end

	if name == "color" or name == "aura" or name == "unaura" or name == "smoke" or name == "unsmoke"
		or name == "fire" or name == "unfire" or name == "sparkles" or name == "unsparkles"
		or name == "trail" or name == "untrail" or name == "halo" or name == "unhalo"
		or name == "horns" or name == "unhorns" or name == "wings" or name == "unwings"
		or name == "cape" or name == "uncape" or name == "rainbow" or name == "unrainbow"
		or name == "outline" or name == "unoutline" or name == "chrome" or name == "unchrome"
		or name == "unneon" or name == "material"
		or name == "xray" or name == "unxray" then
		return "Visual"
	end

	if name == "day" or name == "night" or name == "midnight" or name == "noon"
		or name == "morning" or name == "evening" or name == "dawn" or name == "dusk"
		or name == "fullbright" or name == "unfullbright" or name == "sepia" or name == "unsepia"
		or name == "disco" or name == "undisco" or name == "time"
		or name == "unfog" or name == "ambient" or name == "outdoorambient"
		or name == "brightness" or name == "unshadows" or name == "music"
		or name == "volume" or name == "rain" or name == "unrain"
		or name == "snow" or name == "unsnow" or name == "unwind"
		or name == "eclipse" or name == "uneclipse"
		or name == "sunrise" or name == "sunset" or name == "rainbowworld" then
		return "World"
	end

	if name == "cmds" or name == "rlist" or name == "crl" or name == "notify" or name == "m"
		or name == "closevote" or name == "credits"
		or name == "banlist" or name == "toolsui" or name == "aliases"
		or name == "hideguis" or name == "showguis" or name == "countdown"
		or name == "cancelcountdown" or name == "image" or name == "blind"
		or name == "unblind" or name == "blur" or name == "unblur" or name == "colorcorrection"
		or name == "uncolorcorrection" then
		return "UI"
	end

	if name == "sword" or name == "pipe" or name == "rpg" or name == "btools" or name == "tptool" or name == "gear"
		or name == "give" or name == "toolrain" or name == "cleargear"
		or name == "clean" or name == "heal" or name == "kill" or name == "re"
		or name == "resetstats" or name == "setstat" or name == "addstat" or name == "removestat"
		or name == "dance" or name == "undance" or name == "laugh" or name == "cheer"
		or name == "wave" or name == "salute" or name == "zombie" or name == "unzombie"
		or name == "clone" or name == "explode" or name == "erain" or name == "flashbang"
		or name == "npc" or name == "blackhole" then
		return "Gameplay"
	end

	return "General"
end

for name, meta in pairs(Settings.CommandRegistry) do
	meta.Category = inferCategory(name, meta)
	Settings.CommandRanks[name] = meta.Rank
	local entry = {
		Name = name,
		Desc = meta.Desc,
		Rank = meta.Rank,
		Category = meta.Category,
		TargetMode = meta.TargetMode,
		ArgMode = meta.ArgMode,
		ValueFallback = meta.ValueFallback,
		Args = meta.Args,
		Aliases = meta.Aliases,
		Hidden = meta.Hidden,
	}
	table.insert(Settings.AllCommands, entry)
	if meta.Hidden then
		Settings.HiddenCommands[name] = true
	else
		table.insert(Settings.Commands, entry)
	end

	for _, alias in ipairs(meta.Aliases) do
		Settings.Aliases[alias] = name
	end
end

table.sort(Settings.AllCommands, function(a, b)
	return a.Name < b.Name
end)

table.sort(Settings.Commands, function(a, b)
	return a.Name < b.Name
end)

Settings.RegistryCount = #Settings.AllCommands
Settings.TotalCommands = #Settings.Commands
Settings.VisibleCommandCount = Settings.TotalCommands

return Settings
