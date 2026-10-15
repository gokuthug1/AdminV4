local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local controls = nil
pcall(function()
	local playerScripts = Player:WaitForChild("PlayerScripts", 10)
	local playerModuleScript = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
	if playerModuleScript then
		local PlayerModule = require(playerModuleScript)
		controls = PlayerModule:GetControls()
	end
end)

local settingsModule = ReplicatedStorage:WaitForChild("AdminSettings", 10)
if not settingsModule then return end
local Settings = require(settingsModule)

local AdminUiAssets = ReplicatedStorage:WaitForChild("AdminUiAssets", 15)
if not AdminUiAssets then
	warn("AdminUiAssets was not found in ReplicatedStorage. Generate it with Json2GUI before running AdminV4.")
	return
end

local function getUiTemplate(name, className)
	if not AdminUiAssets then
		AdminUiAssets = ReplicatedStorage:FindFirstChild("AdminUiAssets") or ReplicatedStorage:WaitForChild("AdminUiAssets", 5)
	end
	if not AdminUiAssets then
		warn(string.format("AdminUiAssets was not found when requesting UI asset '%s'.", name))
		return nil
	end
	local template = AdminUiAssets:FindFirstChild(name) or AdminUiAssets:WaitForChild(name, 5)
	if not template then
		warn(string.format("Admin UI asset '%s' was not found in AdminUiAssets.", name))
		return nil
	end
	if className and not template:IsA(className) then
		warn(string.format("Admin UI asset '%s' must be a %s.", name, className))
		return nil
	end
	return template
end

local function cloneUiAsset(name, className)
	local template = getUiTemplate(name, className)
	return template and template:Clone() or nil
end

local Gui = PlayerGui:FindFirstChild("CmdBar")
if Gui and not Gui:IsA("ScreenGui") then
	warn("PlayerGui.CmdBar must be a ScreenGui generated from AdminUiAssets.CmdBar.")
	return
end
if not Gui then
	Gui = cloneUiAsset("CmdBar", "ScreenGui")
	if not Gui then
		return
	end
	Gui.Name = "CmdBar"
	Gui.Parent = PlayerGui
end

local MainFrame = Gui:WaitForChild("MainFrame")
local InputBox = MainFrame:WaitForChild("InputBox")
local SuggestionFrame = MainFrame:WaitForChild("SuggestionFrame")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local ExecuteRemote = Remotes:WaitForChild("ExecuteCommand")
local ClientAction = Remotes:WaitForChild("ClientAction")
local TeamRequest = Remotes:WaitForChild("TeamRequest")

local isOpen = false
local noclipConnection = nil
local flyConnection = nil
local isFlying = false
local FLY_SPEED = Settings.FlySpeed or 50
local currentTopSuggestion = ""
local activeScreenEffects = {}
local laydownReleasePending = false

local currentPrefix = Settings.Prefix
local commandBarKey = Settings.CommandBarKey or Enum.KeyCode.Semicolon
local bannerRegistry = {}
local modalRegistry = {}
local guiVisibilityCache = {}
local xrayConnection = nil

local ScreenEffectDefinitions = {
	blur = {
		ClassName = "BlurEffect",
		InstanceName = "AdminBlurEffect",
		Properties = {Size = 24},
	},
	colorcorrection = {
		ClassName = "ColorCorrectionEffect",
		InstanceName = "AdminColorCorrectionEffect",
		Properties = {Brightness = 0.05, Contrast = 0.15, Saturation = 0.25},
	},
	nightvision = {
		ClassName = "ColorCorrectionEffect",
		InstanceName = "AdminNightVisionEffect",
		Properties = {Brightness = 0.08, Contrast = 0.25, Saturation = -0.1, TintColor = Color3.fromRGB(185, 255, 185)},
	},
	grayscale = {
		ClassName = "ColorCorrectionEffect",
		InstanceName = "AdminGrayscaleEffect",
		Properties = {Saturation = -1},
	},
	invert = {
		ClassName = "ColorCorrectionEffect",
		InstanceName = "AdminInvertEffect",
		Properties = {Brightness = 0.08, Contrast = 0.45, Saturation = -1, TintColor = Color3.fromRGB(255, 255, 255)},
	},
	sepiascreen = {
		ClassName = "ColorCorrectionEffect",
		InstanceName = "AdminSepiaScreenEffect",
		Properties = {Brightness = 0.02, Contrast = 0.15, Saturation = -0.35, TintColor = Color3.fromRGB(231, 210, 170)},
	},
	pixelate = {
		ClassName = "BlurEffect",
		InstanceName = "AdminPixelateEffect",
		Properties = {Size = 8},
	},
	static = {
		ClassName = "BlurEffect",
		InstanceName = "AdminStaticEffect",
		Properties = {Size = 4},
	},
	vignette = {
		ClassName = "ColorCorrectionEffect",
		InstanceName = "AdminVignetteEffect",
		Properties = {Brightness = -0.08, Contrast = 0.2},
	},
	bloom = {
		ClassName = "BlurEffect",
		InstanceName = "AdminBloomEffect",
		Properties = {Size = 2},
	},
}

local function findElement(parent, targetName, className)
	for _, v in pairs(parent:GetDescendants()) do
		if (v.Name == targetName) or (className and v:IsA(className) and v.Name == targetName) then
			return v
		end
	end
	return nil
end

local function trimText(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function updatePrefixUI()
	currentPrefix = Player:GetAttribute("CustomPrefix") or Settings.Prefix
	InputBox.PlaceholderText = "Command... (" .. currentPrefix .. ")"

	-- Looks for a physical UI element called 'PrefixIcon' or 'Icon' to update dynamically
	local PrefixIcon = MainFrame:FindFirstChild("PrefixIcon") or MainFrame:FindFirstChild("Icon")
	if PrefixIcon and PrefixIcon:IsA("TextLabel") then
		PrefixIcon.Text = currentPrefix
	end
end
Player:GetAttributeChangedSignal("CustomPrefix"):Connect(updatePrefixUI)
updatePrefixUI()

local function requestUnlaydown()
	if laydownReleasePending or not Player:GetAttribute("LaydownActive") then
		return
	end

	laydownReleasePending = true
	local character = Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid.Jump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	ExecuteRemote:FireServer((Player:GetAttribute("CustomPrefix") or Settings.Prefix) .. "unlaydown me")
	task.delay(0.3, function()
		laydownReleasePending = false
	end)
end

local function clearScreenEffects()
	local camera = workspace.CurrentCamera
	if camera then
		for _, definition in pairs(ScreenEffectDefinitions) do
			local effect = camera:FindFirstChild(definition.InstanceName)
			if effect then
				effect:Destroy()
			end
		end
	end

	for key in pairs(activeScreenEffects) do
		activeScreenEffects[key] = nil
	end
end

local function removeScreenEffect(effectName)
	activeScreenEffects[effectName] = nil

	local definition = ScreenEffectDefinitions[effectName]
	local camera = workspace.CurrentCamera
	if definition and camera then
		local effect = camera:FindFirstChild(definition.InstanceName)
		if effect then
			effect:Destroy()
		end
	end
end

local function applyScreenEffect(effectName, properties)
	removeScreenEffect(effectName)
	activeScreenEffects[effectName] = true

	local definition = ScreenEffectDefinitions[effectName]
	local camera = workspace.CurrentCamera
	if not definition or not camera then
		return
	end

	local effect = Instance.new(definition.ClassName)
	effect.Name = definition.InstanceName
	for propertyName, value in pairs(definition.Properties) do
		effect[propertyName] = value
	end
	for propertyName, value in pairs(properties or {}) do
		effect[propertyName] = value
	end
	effect.Parent = camera
end

local function CreateListGui(uiName, titleText, itemsTable, options)
	local ui = cloneUiAsset("List", "ScreenGui")
	if not ui then
		return
	end

	options = options or {}
	local scrollFrame = findElement(ui, "Container", "ScrollingFrame") or findElement(ui, "List", "ScrollingFrame")
	local closeBtn = findElement(ui, "Close", "TextButton")
	local titleLbl = findElement(ui, "Title", "TextLabel")
	local header = findElement(ui, "Header", "Frame")
	local divider = findElement(ui, "Divider", "Frame")
	local searchBox = findElement(ui, "SearchBox", "TextBox")
	local template = scrollFrame and scrollFrame:FindFirstChild("Template")
	local layout = scrollFrame and scrollFrame:FindFirstChildOfClass("UIListLayout")

	if not scrollFrame or not template or not template:IsA("TextLabel") or not layout then
		warn("AdminUiAssets.List is missing Container, Template, or UIListLayout.")
		ui:Destroy()
		return
	end

	if PlayerGui:FindFirstChild(uiName) then
		PlayerGui[uiName]:Destroy()
	end

	ui.Name = uiName
	ui.Parent = PlayerGui

	if titleLbl then titleLbl.Text = titleText end
	if closeBtn then closeBtn.MouseButton1Click:Connect(function() ui:Destroy() end) end

	local searchable = options.Searchable == true and searchBox ~= nil
	if searchBox then
		searchBox.Visible = searchable
		searchBox.Text = ""
		searchBox.PlaceholderText = tostring(options.Placeholder or "Search...")
	end

	if header and divider then
		local headerHeight = searchable and 104 or 62
		header.Size = UDim2.new(1, 0, 0, headerHeight)
		divider.Position = UDim2.new(0, 0, 0, headerHeight)
		scrollFrame.Position = UDim2.new(0, 16, 0, headerHeight + 14)
		scrollFrame.Size = UDim2.new(1, -32, 1, -(headerHeight + 30))
	end

	local sourceRows = {}
	for _, item in ipairs(itemsTable or {}) do
		local text = type(item) == "table" and item.Text or item
		local searchText = type(item) == "table" and item.SearchText or item
		table.insert(sourceRows, {
			Text = tostring(text or ""),
			SearchText = tostring(searchText or text or ""),
		})
	end

	local padding = scrollFrame:FindFirstChildOfClass("UIPadding")
	local topInset = padding and padding.PaddingTop.Offset or 0
	local bottomInset = padding and padding.PaddingBottom.Offset or 0
	local function updateCanvasSize()
		if scrollFrame.Parent then
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + topInset + bottomInset)
		end
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

	local function renderRows(query)
		for _, v in pairs(scrollFrame:GetChildren()) do
			if v:IsA("GuiObject") and v.Name ~= "Template" then
				v:Destroy()
			end
		end

		template.Visible = false
		query = tostring(query or ""):lower():match("^%s*(.-)%s*$") or ""
		local visibleRows = {}

		for _, row in ipairs(sourceRows) do
			if query == "" or row.SearchText:lower():find(query, 1, true) then
				table.insert(visibleRows, row)
			end
		end

		for i, row in ipairs(visibleRows) do
			local label = template:Clone()
			label.Visible = true
			label.Name = "Item_" .. i
			label.Text = row.Text
			label.LayoutOrder = i
			label.Parent = scrollFrame
		end

		updateCanvasSize()
		task.defer(updateCanvasSize)
	end

	if searchable then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			renderRows(searchBox.Text)
		end)
	end

	renderRows("")
end

local function destroyGuiByName(uiName)
	local existing = PlayerGui:FindFirstChild(uiName)
	if existing then
		existing:Destroy()
	end
end

local function CreateBannerGui(uiName, payload)
	local ui = cloneUiAsset("Banner", "ScreenGui")
	if not ui then
		return nil
	end

	destroyGuiByName(uiName)
	ui.Name = uiName
	ui.Parent = PlayerGui

	local frame = findElement(ui, "BackgroundFrame", "Frame") or ui:FindFirstChildOfClass("Frame")
	local titleLbl = findElement(ui, "TitleLabel", "TextLabel")
	local messageLbl = findElement(ui, "MessageLabel", "TextLabel") or findElement(ui, "TextLabel", "TextLabel")
	local timerLbl = findElement(ui, "TimerLabel", "TextLabel")
	local closeBtn = findElement(ui, "CloseButton", "TextButton")

	if frame and payload and payload.Style == "warning" then
		frame.BackgroundColor3 = Color3.fromRGB(91, 36, 32)
	elseif frame and payload and payload.Style == "success" then
		frame.BackgroundColor3 = Color3.fromRGB(31, 74, 50)
	elseif frame and payload and payload.Style == "info" then
		frame.BackgroundColor3 = Color3.fromRGB(34, 57, 90)
	end

	if titleLbl then
		titleLbl.Text = tostring((payload and payload.Title) or "Admin")
	end
	if messageLbl then
		messageLbl.Text = tostring((payload and payload.Message) or "")
	end
	if closeBtn then
		closeBtn.MouseButton1Click:Connect(function()
			ui:Destroy()
		end)
	end

	local duration = payload and tonumber(payload.Duration)
	if duration and duration > 0 then
		task.spawn(function()
			local remaining = math.max(0, math.floor(duration))
			while ui.Parent and remaining >= 0 do
				if timerLbl then
					timerLbl.Text = remaining > 0 and (tostring(remaining) .. "s") or ""
				end
				if remaining == 0 then
					break
				end
				task.wait(1)
				remaining -= 1
			end
			if ui.Parent then
				ui:Destroy()
			end
		end)
	elseif timerLbl then
		timerLbl.Text = ""
	end

	bannerRegistry[uiName] = ui
	return ui
end

local function CreateModalGui(uiName, payload)
	local ui = cloneUiAsset("Modal", "ScreenGui")
	if not ui then
		return nil
	end

	destroyGuiByName(uiName)
	ui.Name = uiName
	ui.Parent = PlayerGui

	local frame = ui:FindFirstChild("Frame") or ui:FindFirstChildOfClass("Frame")
	local titleLbl = findElement(ui, "TitleLabel", "TextLabel")
	local messageLbl = findElement(ui, "MessageLabel", "TextLabel")
	local inputBox = findElement(ui, "InputBox", "TextBox")
	local primaryBtn = findElement(ui, "PrimaryButton", "TextButton")
	local secondaryBtn = findElement(ui, "SecondaryButton", "TextButton")
	local closeBtn = findElement(ui, "CloseButton", "TextButton")

	if titleLbl then
		titleLbl.Text = tostring((payload and payload.Title) or "Admin")
	end
	if messageLbl then
		messageLbl.Text = tostring((payload and payload.Message) or "")
	end
	if inputBox then
		local showInput = payload and payload.ShowInput
		inputBox.Visible = showInput == true
		inputBox.PlaceholderText = tostring((payload and payload.Placeholder) or "")
		inputBox.Text = ""
	end
	if primaryBtn then
		primaryBtn.Text = tostring((payload and payload.PrimaryText) or "Close")
		primaryBtn.MouseButton1Click:Connect(function()
			ui:Destroy()
		end)
	end
	if secondaryBtn then
		local hasSecondary = payload and payload.SecondaryText and payload.SecondaryText ~= ""
		secondaryBtn.Visible = hasSecondary == true
		if hasSecondary then
			secondaryBtn.Text = tostring(payload.SecondaryText)
			secondaryBtn.MouseButton1Click:Connect(function()
				ui:Destroy()
			end)
		end
	end
	if closeBtn then
		closeBtn.MouseButton1Click:Connect(function()
			ui:Destroy()
		end)
	end
	if frame and payload and payload.Style == "warning" then
		frame.BackgroundColor3 = Color3.fromRGB(54, 27, 24)
	elseif frame and payload and payload.Style == "info" then
		frame.BackgroundColor3 = Color3.fromRGB(22, 24, 36)
	end

	modalRegistry[uiName] = ui
	return ui
end

local function CreateTeamCreatorGui()
	local uiName = "TeamCreator"
	local ui = cloneUiAsset("TeamCreator", "ScreenGui")
	if not ui then
		return nil
	end

	local nameBox = findElement(ui, "TeamNameBox", "TextBox")
	local valueBox = findElement(ui, "TeamValueBox", "TextBox")
	local colorSearchBox = findElement(ui, "ColorSearchBox", "TextBox")
	local colorList = findElement(ui, "ColorList", "ScrollingFrame")
	local colorTemplate = colorList and colorList:FindFirstChild("ColorOptionTemplate")
	local colorPreview = findElement(ui, "ColorPreview", "Frame")
	local colorPreviewLabel = findElement(ui, "ColorPreviewLabel", "TextLabel")
	local autoAssignableButton = findElement(ui, "AutoAssignableButton", "TextButton")
	local assignCreatorButton = findElement(ui, "AssignCreatorButton", "TextButton")
	local statusLabel = findElement(ui, "StatusLabel", "TextLabel")
	local cancelButton = findElement(ui, "CancelButton", "TextButton")
	local createButton = findElement(ui, "CreateButton", "TextButton")
	local closeButton = findElement(ui, "CloseButton", "TextButton")

	if not nameBox or not valueBox or not colorSearchBox or not colorList
		or not colorTemplate or not colorTemplate:IsA("TextButton")
		or not colorPreview or not colorPreviewLabel
		or not autoAssignableButton or not assignCreatorButton
		or not statusLabel or not cancelButton or not createButton or not closeButton then
		warn("AdminUiAssets.TeamCreator is missing one or more required controls.")
		ui:Destroy()
		return nil
	end

	destroyGuiByName(uiName)
	ui.Name = uiName
	ui.Enabled = true
	ui.Parent = PlayerGui

	local colorNames = {}
	for colorName, color in pairs(Settings.Colors or {}) do
		if typeof(color) == "Color3" and colorName:lower() ~= "transparent" then
			table.insert(colorNames, colorName)
		end
	end
	table.sort(colorNames, function(a, b)
		return a:lower() < b:lower()
	end)

	local selectedColor = Settings.Colors.blue and "blue" or colorNames[1]
	local autoAssignable = false
	local assignCreator = true
	local busy = false
	local colorRows = {}

	local function getReadableTextColor(color)
		local luminance = (color.R * 0.299) + (color.G * 0.587) + (color.B * 0.114)
		return luminance > 0.62 and Color3.fromRGB(20, 23, 28) or Color3.fromRGB(255, 255, 255)
	end

	local function setStatus(message, style)
		statusLabel.Text = tostring(message or "")
		if style == "error" then
			statusLabel.TextColor3 = Color3.fromRGB(255, 132, 132)
		elseif style == "success" then
			statusLabel.TextColor3 = Color3.fromRGB(129, 225, 164)
		else
			statusLabel.TextColor3 = Color3.fromRGB(143, 153, 169)
		end
	end

	local function updateSelectedColor()
		local color = selectedColor and Settings.Colors[selectedColor]
		if not color then
			return
		end
		colorPreview.BackgroundColor3 = color
		colorPreviewLabel.Text = "Selected color: " .. selectedColor
		colorPreviewLabel.TextColor3 = getReadableTextColor(color)
		for colorName, row in pairs(colorRows) do
			row.BackgroundTransparency = colorName == selectedColor and 0 or 0.22
		end
	end

	local function updateToggles()
		autoAssignableButton.Text = "Auto-assign: " .. (autoAssignable and "On" or "Off")
		autoAssignableButton.BackgroundColor3 = autoAssignable and Color3.fromRGB(41, 126, 76) or Color3.fromRGB(48, 54, 64)
		assignCreatorButton.Text = "Join after creation: " .. (assignCreator and "On" or "Off")
		assignCreatorButton.BackgroundColor3 = assignCreator and Color3.fromRGB(41, 126, 76) or Color3.fromRGB(48, 54, 64)
	end

	local function refreshColorFilter()
		local query = trimText(colorSearchBox.Text):lower():gsub("[%s_%-]+", "")
		for colorName, row in pairs(colorRows) do
			local searchable = colorName:lower():gsub("[%s_%-]+", "")
			row.Visible = query == "" or searchable:find(query, 1, true) ~= nil
		end
	end

	for index, colorName in ipairs(colorNames) do
		local color = Settings.Colors[colorName]
		local row = colorTemplate:Clone()
		row.Name = "ColorOption_" .. colorName
		row.LayoutOrder = index
		row.Text = colorName
		row.BackgroundColor3 = color
		row.TextColor3 = getReadableTextColor(color)
		row.Visible = true
		row.Parent = colorList
		colorRows[colorName] = row

		row.MouseButton1Click:Connect(function()
			selectedColor = colorName
			updateSelectedColor()
			setStatus("", "neutral")
		end)
	end

	colorSearchBox:GetPropertyChangedSignal("Text"):Connect(refreshColorFilter)
	autoAssignableButton.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		autoAssignable = not autoAssignable
		updateToggles()
	end)
	assignCreatorButton.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		assignCreator = not assignCreator
		updateToggles()
	end)

	local function close()
		if ui.Parent then
			ui:Destroy()
		end
	end

	cancelButton.MouseButton1Click:Connect(close)
	closeButton.MouseButton1Click:Connect(close)
	createButton.MouseButton1Click:Connect(function()
		if busy then
			return
		end

		local teamName = trimText(nameBox.Text)
		if teamName == "" then
			setStatus("Enter a team name.", "error")
			nameBox:CaptureFocus()
			return
		end
		if #teamName > 32 then
			setStatus("Team names must be 32 characters or fewer.", "error")
			nameBox:CaptureFocus()
			return
		end
		if not selectedColor or not Settings.Colors[selectedColor] then
			setStatus("Select a valid team color.", "error")
			return
		end

		local rawValue = trimText(valueBox.Text)
		local numericValue = nil
		if rawValue ~= "" then
			numericValue = tonumber(rawValue)
			if numericValue == nil or numericValue ~= numericValue
				or numericValue == math.huge or numericValue == -math.huge then
				setStatus("The optional value must be a finite number.", "error")
				valueBox:CaptureFocus()
				return
			end
			if numericValue < -1000000000 or numericValue > 1000000000 then
				setStatus("The optional value is outside the allowed range.", "error")
				valueBox:CaptureFocus()
				return
			end
		end

		busy = true
		createButton.Text = "Creating..."
		createButton.AutoButtonColor = false
		setStatus("Creating team...", "neutral")

		task.spawn(function()
			local invoked, success, message = pcall(function()
				return TeamRequest:InvokeServer({
					Name = teamName,
					Value = numericValue,
					Color = selectedColor,
					AutoAssignable = autoAssignable,
					AssignCreator = assignCreator,
				})
			end)

			if not ui.Parent then
				return
			end

			if invoked and success == true then
				setStatus(message or "Team created.", "success")
				task.delay(0.75, function()
					if ui.Parent then
						ui:Destroy()
					end
				end)
				return
			end

			busy = false
			createButton.Text = "Create team"
			createButton.AutoButtonColor = true
			setStatus(invoked and (message or "Unable to create the team.") or "The team request failed.", "error")
		end)
	end)

	updateSelectedColor()
	updateToggles()
	refreshColorFilter()
	task.defer(function()
		if ui.Parent then
			nameBox:CaptureFocus()
		end
	end)

	return ui
end

local function destroyBannerGui(uiName)
	bannerRegistry[uiName] = nil
	destroyGuiByName(uiName)
end

local function destroyModalGui(uiName)
	modalRegistry[uiName] = nil
	destroyGuiByName(uiName)
end

local function setAllPlayerGuisVisible(visible)
	if visible then
		for gui, state in pairs(guiVisibilityCache) do
			if gui and gui.Parent == PlayerGui then
				gui.Enabled = state
			end
		end
		for gui in pairs(guiVisibilityCache) do
			guiVisibilityCache[gui] = nil
		end
		return
	end

	for _, gui in ipairs(PlayerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= Gui then
			guiVisibilityCache[gui] = gui.Enabled
			gui.Enabled = false
		end
	end
end

local function destroyHighlightsByName(name)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local highlight = character:FindFirstChild(name)
			if highlight then
				highlight:Destroy()
			end
		end
	end
end

local function setXrayEnabled(enabled)
	if xrayConnection then
		xrayConnection:Disconnect()
		xrayConnection = nil
	end

	destroyHighlightsByName("AdminXrayHighlight")
	if not enabled then
		return
	end

	xrayConnection = RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= Player then
				local character = player.Character
				if character and not character:FindFirstChild("AdminXrayHighlight") then
					local highlight = Instance.new("Highlight")
					highlight.Name = "AdminXrayHighlight"
					highlight.FillColor = Color3.fromRGB(255, 72, 72)
					highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
					highlight.FillTransparency = 0.65
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = character
				end
			end
		end
	end)
end

--// ARGUMENT SUGGESTION HELPERS //--

local function getArgValueList(argDef)
	if not argDef then
		return {}
	end

	local values = {}
	local seen = {}
	local function add(value, selectable, insertValue, searchValue)
		local text = tostring(value)
		local insertion = tostring(insertValue or value)
		local key = text:lower() .. "\0" .. insertion:lower()
		if seen[key] then
			return
		end
		seen[key] = true
		table.insert(values, {
			Value = text,
			InsertValue = insertion,
			SearchValue = tostring(searchValue or text),
			Selectable = selectable ~= false,
		})
	end

	local argType = tostring(argDef.Type or "text"):lower()
	if argType ~= "list" and type(argDef.Values) == "table" then
		for _, value in ipairs(argDef.Values) do
			add(value)
		end
	end

	if argType == "color" then
		local commonNames = {
			"red",
			"pink",
			"blue",
			"green",
			"yellow",
			"white",
			"black",
			"orange",
			"purple",
			"cyan",
		}
		for _, name in ipairs(commonNames) do
			if (Settings.Colors or {})[name] then
				add(name)
			end
		end
		local names = {}
		for name in pairs(Settings.Colors or {}) do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in ipairs(names) do
			add(name)
		end
	elseif argType == "material" then
		local names = {}
		for name in pairs(Settings.Materials or {}) do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in ipairs(names) do
			add(name)
		end
	elseif argType == "rank" then
		local names = {}
		for name in pairs(Settings.Ranks or {}) do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in ipairs(names) do
			add(name)
		end
	elseif argType == "player" then
		add("me")
		add("all")
		add("others")
		add("random")
		for _, player in ipairs(Players:GetPlayers()) do
			local playerName = player.Name
			local displayName = player.DisplayName
			add(playerName)
			if displayName ~= playerName then
				add(displayName .. " (@" .. playerName .. ")", true, playerName, displayName)
			end
		end
	elseif argType == "command" then
		local names = {"all"}
		local seenCommands = {all = true}
		for _, command in ipairs(Settings.Commands or {}) do
			local name = command.Name:lower()
			if not seenCommands[name] then
				seenCommands[name] = true
				table.insert(names, command.Name)
			end
		end
		for alias in pairs(Settings.Aliases or {}) do
			local name = alias:lower()
			if not seenCommands[name] then
				seenCommands[name] = true
				table.insert(names, alias)
			end
		end
		table.sort(names)
		for _, name in ipairs(names) do
			add(name)
		end
	elseif argType == "list" and type(argDef.Values) == "table" then
		for _, value in ipairs(argDef.Values) do
			add(value)
		end
	elseif argType == "number" then
		add(argDef.Hint and ("[" .. tostring(argDef.Hint) .. "]") or "<number>", false)
	elseif argType == "text" then
		add("<" .. tostring(argDef.Name or "text") .. ">", false)
	else
		add("<" .. tostring(argDef.Name or argType) .. ">", false)
	end

	return values
end

local function findCommandData(cmdName)
	local lowered = tostring(cmdName or ""):lower()
	local canonical = Settings.Aliases and Settings.Aliases[lowered]
	if canonical then lowered = canonical end

	for _, cmdData in ipairs(Settings.Commands or {}) do
		if cmdData.Name:lower() == lowered then
			return cmdData
		end
	end
	return nil
end

local function isTargetToken(token)
	local lowered = tostring(token or ""):lower()
	if lowered == "me" or lowered == "all" or lowered == "others" or lowered == "random" then
		return true
	end
	if lowered == "" then
		return false
	end

	local matches = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local name = player.Name:lower()
		local displayName = player.DisplayName:lower()
		if name == lowered or displayName == lowered
			or name:sub(1, #lowered) == lowered
			or displayName:sub(1, #lowered) == lowered then
			matches = matches + 1
		end
	end
	return matches > 0
end

local function appendCandidates(destination, argDef, label)
	for _, value in ipairs(getArgValueList(argDef)) do
		table.insert(destination, {
			Value = value.Value,
			InsertValue = value.InsertValue,
			SearchValue = value.SearchValue,
			Selectable = value.Selectable,
			Label = label or argDef.Name or argDef.Type or "argument",
		})
	end
end

local TargetSelectorValues = {
	me = true,
	all = true,
	others = true,
	random = true,
}

local function appendTargetAndFallbackCandidates(destination, argDef)
	local targetCandidates = {}
	local fallbackCandidates = {}
	appendCandidates(targetCandidates, {Name = "target", Type = "player"}, "target")
	appendCandidates(fallbackCandidates, argDef)

	for _, candidate in ipairs(targetCandidates) do
		if TargetSelectorValues[candidate.Value:lower()] then
			table.insert(destination, candidate)
		end
	end

	local priorityPlayerCount = 0
	for _, candidate in ipairs(targetCandidates) do
		if not TargetSelectorValues[candidate.Value:lower()] and priorityPlayerCount < 3 then
			table.insert(destination, candidate)
			priorityPlayerCount = priorityPlayerCount + 1
		end
	end

	local priorityFallbackCount = math.min(3, #fallbackCandidates)
	for index = 1, priorityFallbackCount do
		table.insert(destination, fallbackCandidates[index])
	end

	for index = priorityFallbackCount + 1, #fallbackCandidates do
		table.insert(destination, fallbackCandidates[index])
	end

	local skippedPlayers = 0
	for _, candidate in ipairs(targetCandidates) do
		if not TargetSelectorValues[candidate.Value:lower()] then
			if skippedPlayers >= priorityPlayerCount then
				table.insert(destination, candidate)
			end
			skippedPlayers = skippedPlayers + 1
		end
	end
end

local function getArgumentCandidates(cmdData, completedArgs)
	local candidates = {}
	local hasTarget = cmdData.TargetMode == "optional"
	local argDefinitions = cmdData.Args or {}
	local firstCompleted = completedArgs[1]
	local targetConsumed = hasTarget and firstCompleted ~= nil and isTargetToken(firstCompleted)
	local valueFallbackConsumed = hasTarget
		and cmdData.ValueFallback == true
		and firstCompleted ~= nil
		and not targetConsumed

	if hasTarget and firstCompleted == nil then
		if cmdData.ValueFallback and argDefinitions[1] then
			appendTargetAndFallbackCandidates(candidates, argDefinitions[1])
		else
			appendCandidates(candidates, {Name = "target", Type = "player"}, "target")
		end
		return candidates
	end

	if hasTarget and not targetConsumed and not valueFallbackConsumed then
		if cmdData.ValueFallback and argDefinitions[1] then
			appendTargetAndFallbackCandidates(candidates, argDefinitions[1])
		else
			appendCandidates(candidates, {Name = "target", Type = "player"}, "target")
		end
		return candidates
	end

	local argumentOffset = targetConsumed and 1 or 0
	for index, argDef in ipairs(argDefinitions) do
		local completedValue = completedArgs[index + argumentOffset]
		if completedValue and type(argDef.TerminalValues) == "table" then
			local loweredCompletedValue = completedValue:lower()
			for _, terminalValue in ipairs(argDef.TerminalValues) do
				if loweredCompletedValue == tostring(terminalValue):lower() then
					return candidates
				end
			end
		end
	end

	local definitionIndex = #completedArgs + 1
	if targetConsumed then
		definitionIndex = #completedArgs
	end
	if definitionIndex >= 1 and definitionIndex <= #argDefinitions then
		appendCandidates(candidates, argDefinitions[definitionIndex])
	end

	return candidates
end

local function clearSuggestions()
	for _, child in ipairs(SuggestionFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Template" and not child:IsA("UILayout") then
			child:Destroy()
		end
	end
end

local function resizeSuggestions(template, count)
	local itemHeight = (template and template.Size.Y.Offset) or 25
	local layout = SuggestionFrame:FindFirstChildOfClass("UIListLayout")
	local padOffset = layout and layout.Padding.Offset or 0
	local matchCount = math.min(count, 10)
	SuggestionFrame.Size = UDim2.new(1, 0, 0, (matchCount * itemHeight) + (math.max(0, matchCount - 1) * padOffset))
end

local function updateSuggestions()
	clearSuggestions()
	currentTopSuggestion = ""

	local text = InputBox.Text:gsub("\t", ""):lower()
	if text:sub(1, #currentPrefix) == currentPrefix:lower() then
		text = text:sub(#currentPrefix + 1)
	end

	if text == "" or text:match("^%s*$") then
		SuggestionFrame.Visible = false
		currentTopSuggestion = ""
		return
	end

	local count = 0
	local template = SuggestionFrame:FindFirstChild("Template")
	local maxSuggestions = 10
	if not template or not template:IsA("TextButton") then
		warn("AdminUiAssets.CmdBar is missing SuggestionFrame.Template.")
		SuggestionFrame.Visible = false
		return
	end

	local commandToken, remainder = text:match("^(%S+)%s+(.*)$")
	if commandToken then
		local cmdData = findCommandData(commandToken)
		if cmdData then
			local hasTrailingSpace = remainder:sub(-1) == " "
			local allTokens = {}
			for word in string.gmatch(remainder, "%S+") do
				table.insert(allTokens, word)
			end

			local partialToken = ""
			local completedArgs = {}
			for index, word in ipairs(allTokens) do
				if index == #allTokens and not hasTrailingSpace then
					partialToken = word
				else
					table.insert(completedArgs, word)
				end
			end

			local candidates = getArgumentCandidates(cmdData, completedArgs)
			local loweredPartial = partialToken:lower()
			local beforePartial = commandToken
			for _, word in ipairs(completedArgs) do
				beforePartial = beforePartial .. " " .. word
			end

			for _, candidate in ipairs(candidates) do
				local displayValue = candidate.Value
				local insertValue = candidate.InsertValue or displayValue
				local searchValue = candidate.SearchValue or displayValue
				local matchesPartial = loweredPartial == ""
					or (
						candidate.Selectable
						and (
							displayValue:lower():sub(1, #loweredPartial) == loweredPartial
							or searchValue:lower():sub(1, #loweredPartial) == loweredPartial
						)
					)
				if matchesPartial then
					count = count + 1
					if currentTopSuggestion == "" and candidate.Selectable then
						currentTopSuggestion = beforePartial .. " " .. insertValue
					end
					if count <= maxSuggestions then
						local button = template:Clone()
						button.Visible = true
						button.Name = "ArgSuggestion_" .. count
						button.Text = "  -> " .. tostring(candidate.Label) .. ": " .. displayValue
						button.Parent = SuggestionFrame
						button.LayoutOrder = count

						if candidate.Selectable then
							local capturedValue = insertValue
							button.MouseButton1Down:Connect(function()
								InputBox.Text = beforePartial .. " " .. capturedValue .. " "
								task.defer(function()
									InputBox:CaptureFocus()
									InputBox.CursorPosition = #InputBox.Text + 1
									updateSuggestions()
								end)
							end)
						end
					end
				end
			end

			if count == 0 then
				currentTopSuggestion = ""
			end
			SuggestionFrame.Visible = count > 0
			resizeSuggestions(template, count)
			return
		end
	end

	local exactCommand = findCommandData(text)
	if exactCommand then
		local candidates = getArgumentCandidates(exactCommand, {})
		if #candidates > 0 then
			for _, candidate in ipairs(candidates) do
				local insertValue = candidate.InsertValue or candidate.Value
				count = count + 1
				if currentTopSuggestion == "" and candidate.Selectable then
					currentTopSuggestion = text .. " " .. insertValue
				end
				if count <= maxSuggestions then
					local button = template:Clone()
					button.Visible = true
					button.Name = "ArgSuggestion_" .. count
					button.Text = "  -> " .. tostring(candidate.Label) .. ": " .. candidate.Value
					button.Parent = SuggestionFrame
					button.LayoutOrder = count

					if candidate.Selectable then
						local capturedValue = insertValue
						button.MouseButton1Down:Connect(function()
							InputBox.Text = text .. " " .. capturedValue .. " "
							task.defer(function()
								InputBox:CaptureFocus()
								InputBox.CursorPosition = #InputBox.Text + 1
								updateSuggestions()
							end)
						end)
					end
				end
			end

			SuggestionFrame.Visible = count > 0
			resizeSuggestions(template, count)
			return
		end
	end

	for _, cmdData in ipairs(Settings.Commands or {}) do
		local matchedName = nil
		if cmdData.Name:lower():sub(1, #text) == text then
			matchedName = cmdData.Name
		else
			for _, alias in ipairs(cmdData.Aliases or {}) do
				if alias:lower():sub(1, #text) == text then
					matchedName = alias
					break
				end
			end
		end

		if matchedName then
			count += 1
			if count == 1 then
				currentTopSuggestion = matchedName
			end

			if count <= maxSuggestions then
				local btn = template:Clone()
				btn.Visible = true
				btn.Name = "Suggestion_" .. matchedName
				local aliasSuffix = matchedName ~= cmdData.Name and (" -> " .. currentPrefix .. cmdData.Name) or ""
				btn.Text = " " .. currentPrefix .. matchedName .. aliasSuffix .. " - " .. (cmdData.Desc or "")
				btn.Parent = SuggestionFrame
				btn.LayoutOrder = count
				btn.MouseButton1Down:Connect(function()
					InputBox.Text = matchedName .. " "
					task.defer(function()
						InputBox:CaptureFocus()
						InputBox.CursorPosition = #InputBox.Text + 1
						updateSuggestions()
					end)
				end)
			end
		end
	end

	if count == 0 then
		currentTopSuggestion = ""
	end

	SuggestionFrame.Visible = (count > 0)
	resizeSuggestions(template, count)
end

local function toggleBar()
	isOpen = not isOpen
	Gui.Enabled = isOpen
	if isOpen then
		InputBox:CaptureFocus()
		InputBox.Text = ""
		currentTopSuggestion = ""
		SuggestionFrame.Visible = false
		task.defer(function() InputBox.CursorPosition = 1 end)
	else
		InputBox:ReleaseFocus()
		InputBox.Text = ""
		SuggestionFrame.Visible = false
	end
end

--// FLIGHT SYSTEM //--
local function startFlight()
	if isFlying then return end
	local char = Player.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	isFlying = true; hum.PlatformStand = true
	local att = Instance.new("Attachment", root); att.Name = "FlightAtt"

	local velocity = Instance.new("LinearVelocity", root)
	velocity.Name = "FlightVelocity"
	velocity.Attachment0 = att
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World

	local gyro = Instance.new("AlignOrientation", root)
	gyro.Name = "FlightGyro"
	gyro.Attachment0 = att
	gyro.Mode = Enum.OrientationAlignmentMode.OneAttachment
	gyro.MaxTorque = math.huge
	gyro.Responsiveness = 200

	flyConnection = RunService.RenderStepped:Connect(function()
		if not isFlying or not root.Parent or hum.Health <= 0 then stopFlight() return end
		local cam = workspace.CurrentCamera
		local move = Vector3.zero
		local moveVector = controls:GetMoveVector()

		if moveVector.Magnitude > 0 then
			move += cam.CFrame.LookVector * -moveVector.Z
			move += cam.CFrame.RightVector * moveVector.X
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
		if move.Magnitude > 0 then move = move.Unit * FLY_SPEED end

		velocity.VectorVelocity = move
		gyro.CFrame = cam.CFrame
	end)
end

function stopFlight()
	if not isFlying then return end
	isFlying = false
	if flyConnection then 
		flyConnection:Disconnect()
		flyConnection = nil 
	end

	local char = Player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if root then
			for _, n in ipairs({"FlightAtt", "FlightVelocity", "FlightGyro"}) do
				local o = root:FindFirstChild(n)
				if o then o:Destroy() end
			end
		end
		if hum then hum.PlatformStand = false end
	end
end

Player.CharacterAdded:Connect(function(char)
	laydownReleasePending = false
	clearScreenEffects()
	char:WaitForChild("Humanoid").Died:Connect(function()
		clearScreenEffects()
		if isFlying then stopFlight() end
	end)
end)

if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
	Player.Character.Humanoid.Died:Connect(function()
		clearScreenEffects()
		if isFlying then stopFlight() end
	end)
end

Player:GetAttributeChangedSignal("LaydownActive"):Connect(function()
	if not Player:GetAttribute("LaydownActive") then
		laydownReleasePending = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	if Player:GetAttribute("LaydownActive") then
		requestUnlaydown()
	end
end)

--// EXECUTIVE ADMIN DASHBOARD CONTROLLER (Json2GUI Remastered) //--
local dashboardGui = nil
local dashboardTelemetryRunning = false
local selectedDashboardPlayer = nil
local dashboardRefreshPlayers = nil
local isServerLocked = false

-- Persistent toggle states per player
local playerToggleStates: {[string]: {[string]: boolean}} = {}

local function getPlayerState(playerName: string)
	if not playerToggleStates[playerName] then
		playerToggleStates[playerName] = {
			Frozen = false,
			Jailed = false,
			Muted = false,
			Blind = false,
			God = false,
			Spectating = false,
			Banned = false,
		}
	end
	return playerToggleStates[playerName]
end

local function toggleDashboard()
	if not dashboardGui or not dashboardGui.Parent then
		dashboardGui = PlayerGui:FindFirstChild("AdminDashboard")
		if not dashboardGui then
			dashboardGui = cloneUiAsset("AdminDashboard", "ScreenGui")
			if not dashboardGui then
				warn("AdminDashboard UI asset not found in AdminUiAssets. Generate it with Json2GUI before using ;panel.")
				return
			end
			dashboardGui.Name = "AdminDashboard"
			dashboardGui.Parent = PlayerGui
		end
	end

	local isNowEnabled = not dashboardGui.Enabled
	dashboardGui.Enabled = isNowEnabled

	if not isNowEnabled then
		dashboardTelemetryRunning = false
		return
	end

	local mainContainer = dashboardGui:FindFirstChild("MainContainer")
	if not mainContainer then return end

	local header = mainContainer:FindFirstChild("Header")
	local tabBar = mainContainer:FindFirstChild("TabBar")
	local playerTab = mainContainer:FindFirstChild("PlayerTab")
	local healthTab = mainContainer:FindFirstChild("HealthTab")
	local worldTab = mainContainer:FindFirstChild("WorldTab")

	if not header or not tabBar or not playerTab or not healthTab or not worldTab then
		return
	end

	local closeBtn = header:FindFirstChild("CloseBtn") :: TextButton?
	local targetPill = header:FindFirstChild("TargetPill") :: TextLabel?
	local fpsPill = header:FindFirstChild("FpsPill") :: TextLabel?
	local pingPill = header:FindFirstChild("PingPill") :: TextLabel?

	if closeBtn and not closeBtn:GetAttribute("Hooked") then
		closeBtn:SetAttribute("Hooked", true)
		closeBtn.MouseButton1Click:Connect(function()
			dashboardGui.Enabled = false
			dashboardTelemetryRunning = false
		end)
	end

	-- Tab Switcher
	local playerTabBtn = tabBar:FindFirstChild("PlayerTabBtn") :: TextButton?
	local healthTabBtn = tabBar:FindFirstChild("HealthTabBtn") :: TextButton?
	local worldTabBtn = tabBar:FindFirstChild("WorldTabBtn") :: TextButton?

	local function selectTab(tabName: string)
		playerTab.Visible = (tabName == "player")
		healthTab.Visible = (tabName == "health")
		worldTab.Visible = (tabName == "world")

		if playerTabBtn then
			playerTabBtn.BackgroundColor3 = (tabName == "player") and Color3.fromRGB(37, 99, 235) or Color3.fromRGB(17, 24, 39)
			playerTabBtn.TextColor3 = (tabName == "player") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(148, 163, 184)
		end
		if healthTabBtn then
			healthTabBtn.BackgroundColor3 = (tabName == "health") and Color3.fromRGB(37, 99, 235) or Color3.fromRGB(17, 24, 39)
			healthTabBtn.TextColor3 = (tabName == "health") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(148, 163, 184)
		end
		if worldTabBtn then
			worldTabBtn.BackgroundColor3 = (tabName == "world") and Color3.fromRGB(37, 99, 235) or Color3.fromRGB(17, 24, 39)
			worldTabBtn.TextColor3 = (tabName == "world") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(148, 163, 184)
		end
	end

	if playerTabBtn and not playerTabBtn:GetAttribute("Hooked") then
		playerTabBtn:SetAttribute("Hooked", true)
		playerTabBtn.MouseButton1Click:Connect(function() selectTab("player") end)
	end
	if healthTabBtn and not healthTabBtn:GetAttribute("Hooked") then
		healthTabBtn:SetAttribute("Hooked", true)
		healthTabBtn.MouseButton1Click:Connect(function() selectTab("health") end)
	end
	if worldTabBtn and not worldTabBtn:GetAttribute("Hooked") then
		worldTabBtn:SetAttribute("Hooked", true)
		worldTabBtn.MouseButton1Click:Connect(function() selectTab("world") end)
	end

	-- Player Management Tab Logic
	local playerListPanel = playerTab:FindFirstChild("PlayerListPanel")
	local searchBox = playerListPanel and playerListPanel:FindFirstChild("PlayerSearchBox") :: TextBox?
	local playerListFrame = playerListPanel and playerListPanel:FindFirstChild("PlayerListFrame") :: ScrollingFrame?
	local template = playerListFrame and playerListFrame:FindFirstChild("Template") :: TextButton?

	local actionPanel = playerTab:FindFirstChild("ActionPanel")
	local targetHeader = actionPanel and actionPanel:FindFirstChild("TargetHeader")
	local selectedTargetLabel = targetHeader and targetHeader:FindFirstChild("SelectedTargetLabel") :: TextLabel?
	local badgesRow = targetHeader and targetHeader:FindFirstChild("BadgesRow")

	local freezeBadge = badgesRow and badgesRow:FindFirstChild("FreezeBadge") :: TextLabel?
	local jailBadge = badgesRow and badgesRow:FindFirstChild("JailBadge") :: TextLabel?
	local muteBadge = badgesRow and badgesRow:FindFirstChild("MuteBadge") :: TextLabel?
	local blindBadge = badgesRow and badgesRow:FindFirstChild("BlindBadge") :: TextLabel?
	local godBadge = badgesRow and badgesRow:FindFirstChild("GodBadge") :: TextLabel?

	local togglesCard = actionPanel and actionPanel:FindFirstChild("TogglesCard")
	local togglesGrid = togglesCard and togglesCard:FindFirstChild("TogglesGrid")

	local freezeToggleBtn = togglesGrid and togglesGrid:FindFirstChild("FreezeToggleBtn") :: TextButton?
	local jailToggleBtn = togglesGrid and togglesGrid:FindFirstChild("JailToggleBtn") :: TextButton?
	local muteToggleBtn = togglesGrid and togglesGrid:FindFirstChild("MuteToggleBtn") :: TextButton?
	local blindToggleBtn = togglesGrid and togglesGrid:FindFirstChild("BlindToggleBtn") :: TextButton?
	local godToggleBtn = togglesGrid and togglesGrid:FindFirstChild("GodToggleBtn") :: TextButton?
	local spectateToggleBtn = togglesGrid and togglesGrid:FindFirstChild("SpectateToggleBtn") :: TextButton?

	local actionsCard = actionPanel and actionPanel:FindFirstChild("ActionsCard")
	local actionsBtnRow = actionsCard and actionsCard:FindFirstChild("BtnRow")
	local kickBtn = actionsBtnRow and actionsBtnRow:FindFirstChild("KickBtn") :: TextButton?
	local banToggleBtn = actionsBtnRow and actionsBtnRow:FindFirstChild("BanToggleBtn") :: TextButton?
	local tpToBtn = actionsBtnRow and actionsBtnRow:FindFirstChild("TpToBtn") :: TextButton?
	local bringBtn = actionsBtnRow and actionsBtnRow:FindFirstChild("BringBtn") :: TextButton?

	local weaponsCard = actionPanel and actionPanel:FindFirstChild("WeaponsCard")
	local weaponsBtnRow = weaponsCard and weaponsCard:FindFirstChild("BtnRow")
	local giveHammerBtn = weaponsBtnRow and weaponsBtnRow:FindFirstChild("GiveHammerBtn") :: TextButton?
	local giveGravBtn = weaponsBtnRow and weaponsBtnRow:FindFirstChild("GiveGravBtn") :: TextButton?
	local giveFreezeBtn = weaponsBtnRow and weaponsBtnRow:FindFirstChild("GiveFreezeBtn") :: TextButton?
	local givePipeBtn = weaponsBtnRow and weaponsBtnRow:FindFirstChild("GivePipeBtn") :: TextButton?
	local giveBlackHoleBtn = weaponsBtnRow and weaponsBtnRow:FindFirstChild("GiveBlackHoleBtn") :: TextButton?

	-- Update all toggle button visuals and badges for current selected target
	local function updateTargetVisuals()
		if not selectedDashboardPlayer or selectedDashboardPlayer == "" then
			if selectedTargetLabel then
				selectedTargetLabel.Text = "Target: [Select a Player]"
				selectedTargetLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
			end
			if targetPill then targetPill.Text = "🎯 None Selected" end

			if freezeBadge then freezeBadge.Visible = false end
			if jailBadge then jailBadge.Visible = false end
			if muteBadge then muteBadge.Visible = false end
			if blindBadge then blindBadge.Visible = false end
			if godBadge then godBadge.Visible = false end

			if freezeToggleBtn then freezeToggleBtn.Text = "🧊 Freeze: OFF"; freezeToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59); freezeToggleBtn.TextColor3 = Color3.fromRGB(56, 189, 248) end
			if jailToggleBtn then jailToggleBtn.Text = "⛓️ Jail: OFF"; jailToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59); jailToggleBtn.TextColor3 = Color3.fromRGB(245, 158, 11) end
			if muteToggleBtn then muteToggleBtn.Text = "🔇 Mute: OFF"; muteToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59); muteToggleBtn.TextColor3 = Color3.fromRGB(239, 68, 68) end
			if blindToggleBtn then blindToggleBtn.Text = "🙈 Blind: OFF"; blindToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59); blindToggleBtn.TextColor3 = Color3.fromRGB(192, 132, 252) end
			if godToggleBtn then godToggleBtn.Text = "🛡️ Godmode: OFF"; godToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59); godToggleBtn.TextColor3 = Color3.fromRGB(52, 211, 153) end
			if spectateToggleBtn then spectateToggleBtn.Text = "🎥 Spectate: OFF"; spectateToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59); spectateToggleBtn.TextColor3 = Color3.fromRGB(6, 182, 212) end
			if banToggleBtn then banToggleBtn.Text = "🔨 Ban Player"; banToggleBtn.BackgroundColor3 = Color3.fromRGB(153, 27, 27) end
			return
		end

		local targetPlayer = Players:FindFirstChild(selectedDashboardPlayer)
		local displayName = targetPlayer and targetPlayer.DisplayName or selectedDashboardPlayer
		local username = targetPlayer and targetPlayer.Name or selectedDashboardPlayer
		local state = getPlayerState(username)

		if selectedTargetLabel then
			selectedTargetLabel.Text = string.format("Target: %s (@%s)", displayName, username)
			selectedTargetLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
		end
		if targetPill then
			targetPill.Text = string.format("🎯 @%s", username:sub(1, 12))
		end

		-- Badges
		if freezeBadge then freezeBadge.Visible = (state.Frozen == true) end
		if jailBadge then jailBadge.Visible = (state.Jailed == true) end
		if muteBadge then muteBadge.Visible = (state.Muted == true) end
		if blindBadge then blindBadge.Visible = (state.Blind == true) end
		if godBadge then godBadge.Visible = (state.God == true) end

		-- Toggles Visual Updates
		if freezeToggleBtn then
			if state.Frozen then
				freezeToggleBtn.Text = "🔥 Unfreeze\n[Status: ON]"
				freezeToggleBtn.BackgroundColor3 = Color3.fromRGB(2, 132, 199)
				freezeToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				freezeToggleBtn.Text = "🧊 Freeze\n[Status: OFF]"
				freezeToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
				freezeToggleBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
			end
		end

		if jailToggleBtn then
			if state.Jailed then
				jailToggleBtn.Text = "🔓 Unjail\n[Status: ON]"
				jailToggleBtn.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
				jailToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				jailToggleBtn.Text = "⛓️ Jail\n[Status: OFF]"
				jailToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
				jailToggleBtn.TextColor3 = Color3.fromRGB(245, 158, 11)
			end
		end

		if muteToggleBtn then
			if state.Muted then
				muteToggleBtn.Text = "🔊 Unmute\n[Status: ON]"
				muteToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
				muteToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				muteToggleBtn.Text = "🔇 Mute\n[Status: OFF]"
				muteToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
				muteToggleBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
			end
		end

		if blindToggleBtn then
			if state.Blind then
				blindToggleBtn.Text = "👁️ Unblind\n[Status: ON]"
				blindToggleBtn.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
				blindToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				blindToggleBtn.Text = "🙈 Blind\n[Status: OFF]"
				blindToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
				blindToggleBtn.TextColor3 = Color3.fromRGB(192, 132, 252)
			end
		end

		if godToggleBtn then
			if state.God then
				godToggleBtn.Text = "💔 Ungod\n[Status: ON]"
				godToggleBtn.BackgroundColor3 = Color3.fromRGB(5, 150, 105)
				godToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				godToggleBtn.Text = "🛡️ Godmode\n[Status: OFF]"
				godToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
				godToggleBtn.TextColor3 = Color3.fromRGB(52, 211, 153)
			end
		end

		if spectateToggleBtn then
			if state.Spectating then
				spectateToggleBtn.Text = "❌ Stop View\n[Status: ON]"
				spectateToggleBtn.BackgroundColor3 = Color3.fromRGB(8, 145, 178)
				spectateToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				spectateToggleBtn.Text = "🎥 Spectate\n[Status: OFF]"
				spectateToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
				spectateToggleBtn.TextColor3 = Color3.fromRGB(6, 182, 212)
			end
		end

		if banToggleBtn then
			if state.Banned then
				banToggleBtn.Text = "🔓 Unban"
				banToggleBtn.BackgroundColor3 = Color3.fromRGB(5, 150, 105)
			else
				banToggleBtn.Text = "🔨 Ban"
				banToggleBtn.BackgroundColor3 = Color3.fromRGB(153, 27, 27)
			end
		end
	end

	-- Populate Online Players List
	local function refreshPlayerList()
		if not playerListFrame or not template then return end

		for _, child in ipairs(playerListFrame:GetChildren()) do
			if child:IsA("TextButton") and child.Name ~= "Template" then
				child:Destroy()
			end
		end

		template.Visible = false

		local onlinePlayers = Players:GetPlayers()
		for _, targetP in ipairs(onlinePlayers) do
			local btn = template:Clone()
			btn.Name = "Player_" .. targetP.Name
			btn.Visible = true

			local nameLabel = btn:FindFirstChild("PlayerName") :: TextLabel?
			if nameLabel then
				nameLabel.Text = string.format("%s (@%s)", targetP.DisplayName, targetP.Name)
			end

			if selectedDashboardPlayer == targetP.Name then
				btn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
			else
				btn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
			end

			btn.MouseButton1Click:Connect(function()
				selectedDashboardPlayer = targetP.Name
				updateTargetVisuals()

				for _, otherBtn in ipairs(playerListFrame:GetChildren()) do
					if otherBtn:IsA("TextButton") and otherBtn.Name ~= "Template" then
						if otherBtn.Name == "Player_" .. targetP.Name then
							otherBtn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
						else
							otherBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
						end
					end
				end
			end)

			btn.Parent = playerListFrame
		end

		updateTargetVisuals()
	end

	dashboardRefreshPlayers = refreshPlayerList
	refreshPlayerList()

	-- Live Filter by SearchBox
	if searchBox and not searchBox:GetAttribute("Hooked") then
		searchBox:SetAttribute("Hooked", true)
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local query = searchBox.Text:lower():gsub("%s+", "")
			if not playerListFrame then return end
			for _, child in ipairs(playerListFrame:GetChildren()) do
				if child:IsA("TextButton") and child.Name ~= "Template" then
					local nameLabel = child:FindFirstChild("PlayerName") :: TextLabel?
					local text = nameLabel and nameLabel.Text:lower():gsub("%s+", "") or child.Name:lower()
					child.Visible = (query == "" or text:find(query, 1, true) ~= nil)
				end
			end
		end)
	end

	local function requireTarget(): string?
		if not selectedDashboardPlayer or selectedDashboardPlayer == "" then
			if selectedTargetLabel then
				selectedTargetLabel.Text = "⚠️ Please select a player from the list first!"
				selectedTargetLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
				task.delay(2, updateTargetVisuals)
			end
			return nil
		end
		return selectedDashboardPlayer
	end

	-- Hook Interactive Toggles (State-Driven with Undo)
	if freezeToggleBtn and not freezeToggleBtn:GetAttribute("Hooked") then
		freezeToggleBtn:SetAttribute("Hooked", true)
		freezeToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.Frozen = not state.Frozen
			if state.Frozen then
				ExecuteRemote:FireServer(currentPrefix .. "freeze " .. target)
			else
				ExecuteRemote:FireServer(currentPrefix .. "unfreeze " .. target)
			end
			updateTargetVisuals()
		end)
	end

	if jailToggleBtn and not jailToggleBtn:GetAttribute("Hooked") then
		jailToggleBtn:SetAttribute("Hooked", true)
		jailToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.Jailed = not state.Jailed
			if state.Jailed then
				ExecuteRemote:FireServer(currentPrefix .. "jail " .. target)
			else
				ExecuteRemote:FireServer(currentPrefix .. "unjail " .. target)
			end
			updateTargetVisuals()
		end)
	end

	if muteToggleBtn and not muteToggleBtn:GetAttribute("Hooked") then
		muteToggleBtn:SetAttribute("Hooked", true)
		muteToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.Muted = not state.Muted
			if state.Muted then
				ExecuteRemote:FireServer(currentPrefix .. "mute " .. target)
			else
				ExecuteRemote:FireServer(currentPrefix .. "unmute " .. target)
			end
			updateTargetVisuals()
		end)
	end

	if blindToggleBtn and not blindToggleBtn:GetAttribute("Hooked") then
		blindToggleBtn:SetAttribute("Hooked", true)
		blindToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.Blind = not state.Blind
			if state.Blind then
				ExecuteRemote:FireServer(currentPrefix .. "blind " .. target)
			else
				ExecuteRemote:FireServer(currentPrefix .. "unblind " .. target)
			end
			updateTargetVisuals()
		end)
	end

	if godToggleBtn and not godToggleBtn:GetAttribute("Hooked") then
		godToggleBtn:SetAttribute("Hooked", true)
		godToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.God = not state.God
			if state.God then
				ExecuteRemote:FireServer(currentPrefix .. "god " .. target)
			else
				ExecuteRemote:FireServer(currentPrefix .. "ungod " .. target)
			end
			updateTargetVisuals()
		end)
	end

	if spectateToggleBtn and not spectateToggleBtn:GetAttribute("Hooked") then
		spectateToggleBtn:SetAttribute("Hooked", true)
		spectateToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.Spectating = not state.Spectating

			local camera = Workspace.CurrentCamera
			if state.Spectating then
				local targetPlayer = Players:FindFirstChild(target)
				local targetChar = targetPlayer and targetPlayer.Character
				local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
				if camera and targetHum then
					camera.CameraSubject = targetHum
				end
			else
				local localChar = Player.Character
				local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
				if camera and localHum then
					camera.CameraSubject = localHum
				end
			end
			updateTargetVisuals()
		end)
	end

	-- Hook Dispatch & Teleport Actions
	if kickBtn and not kickBtn:GetAttribute("Hooked") then
		kickBtn:SetAttribute("Hooked", true)
		kickBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "kick " .. target)
			end
		end)
	end

	if banToggleBtn and not banToggleBtn:GetAttribute("Hooked") then
		banToggleBtn:SetAttribute("Hooked", true)
		banToggleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if not target then return end
			local state = getPlayerState(target)
			state.Banned = not state.Banned
			if state.Banned then
				ExecuteRemote:FireServer(currentPrefix .. "ban " .. target)
			else
				ExecuteRemote:FireServer(currentPrefix .. "unban " .. target)
			end
			updateTargetVisuals()
		end)
	end

	if tpToBtn and not tpToBtn:GetAttribute("Hooked") then
		tpToBtn:SetAttribute("Hooked", true)
		tpToBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "to " .. target)
			end
		end)
	end

	if bringBtn and not bringBtn:GetAttribute("Hooked") then
		bringBtn:SetAttribute("Hooked", true)
		bringBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "bring " .. target)
			end
		end)
	end

	-- Hook Weapons Arsenal Distribution
	if giveHammerBtn and not giveHammerBtn:GetAttribute("Hooked") then
		giveHammerBtn:SetAttribute("Hooked", true)
		giveHammerBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "banhammer " .. target)
			end
		end)
	end

	if giveGravBtn and not giveGravBtn:GetAttribute("Hooked") then
		giveGravBtn:SetAttribute("Hooked", true)
		giveGravBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "gravitygun " .. target)
			end
		end)
	end

	if giveFreezeBtn and not giveFreezeBtn:GetAttribute("Hooked") then
		giveFreezeBtn:SetAttribute("Hooked", true)
		giveFreezeBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "freezeray " .. target)
			end
		end)
	end

	if givePipeBtn and not givePipeBtn:GetAttribute("Hooked") then
		givePipeBtn:SetAttribute("Hooked", true)
		givePipeBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "pipe " .. target)
			end
		end)
	end

	if giveBlackHoleBtn and not giveBlackHoleBtn:GetAttribute("Hooked") then
		giveBlackHoleBtn:SetAttribute("Hooked", true)
		giveBlackHoleBtn.MouseButton1Click:Connect(function()
			local target = requireTarget()
			if target then
				ExecuteRemote:FireServer(currentPrefix .. "blackholecannon " .. target)
			end
		end)
	end

	-- World Controls Tab Logic
	if worldTab and not worldTab:GetAttribute("Hooked") then
		worldTab:SetAttribute("Hooked", true)

		local timeBox = worldTab:FindFirstChild("TimeBox")
		local timeBtnRow = timeBox and timeBox:FindFirstChild("BtnRow")
		if timeBtnRow then
			local timePresets = {
				NoonBtn = "14",
				SunsetBtn = "18",
				MidnightBtn = "0",
				SunriseBtn = "6",
			}
			for btnName, tVal in pairs(timePresets) do
				local btn = timeBtnRow:FindFirstChild(btnName) :: TextButton?
				if btn and btn:IsA("TextButton") then
					btn.MouseButton1Click:Connect(function()
						ExecuteRemote:FireServer(currentPrefix .. "time " .. tVal)
					end)
				end
			end
		end

		local gravBox = worldTab:FindFirstChild("GravBox")
		local gravBtnRow = gravBox and gravBox:FindFirstChild("BtnRow")
		if gravBtnRow then
			local gravPresets = {
				NormalGravBtn = "196.2",
				LowGravBtn = "50",
				ZeroGravBtn = "0",
				HeavyGravBtn = "400",
			}
			for btnName, gVal in pairs(gravPresets) do
				local btn = gravBtnRow:FindFirstChild(btnName) :: TextButton?
				if btn and btn:IsA("TextButton") then
					btn.MouseButton1Click:Connect(function()
						ExecuteRemote:FireServer(currentPrefix .. "gravity " .. gVal)
					end)
				end
			end
		end

		local actionBox = worldTab:FindFirstChild("ActionBox")
		local actionBtnRow = actionBox and actionBox:FindFirstChild("BtnRow")
		if actionBtnRow then
			local lockBtn = actionBtnRow:FindFirstChild("LockServerToggleBtn") :: TextButton?
			if lockBtn and lockBtn:IsA("TextButton") then
				lockBtn.MouseButton1Click:Connect(function()
					isServerLocked = not isServerLocked
					if isServerLocked then
						ExecuteRemote:FireServer(currentPrefix .. "serverlock")
						lockBtn.Text = "🔓 Server Lock: ON (Active)"
						lockBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
					else
						ExecuteRemote:FireServer(currentPrefix .. "unlockserver")
						lockBtn.Text = "🔒 Server Lock: OFF"
						lockBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
					end
				end)
			end

			local clearBtn = actionBtnRow:FindFirstChild("ClearDebrisBtn") :: TextButton?
			if clearBtn and clearBtn:IsA("TextButton") then
				clearBtn.MouseButton1Click:Connect(function()
					ExecuteRemote:FireServer(currentPrefix .. "clean")
				end)
			end

			local reloadBtn = actionBtnRow:FindFirstChild("ReloadMapBtn") :: TextButton?
			if reloadBtn and reloadBtn:IsA("TextButton") then
				reloadBtn.MouseButton1Click:Connect(function()
					ExecuteRemote:FireServer(currentPrefix .. "reloadmap")
				end)
			end
		end
	end

	-- Health Tab Telemetry Loop
	local fpsCard = healthTab:FindFirstChild("FpsCard")
	local pingCard = healthTab:FindFirstChild("PingCard")
	local memCard = healthTab:FindFirstChild("MemCard")
	local instCard = healthTab:FindFirstChild("InstCard")

	local fpsVal = fpsCard and fpsCard:FindFirstChild("FpsVal") :: TextLabel?
	local pingVal = pingCard and pingCard:FindFirstChild("PingVal") :: TextLabel?
	local memVal = memCard and memCard:FindFirstChild("MemVal") :: TextLabel?
	local instVal = instCard and instCard:FindFirstChild("InstVal") :: TextLabel?

	dashboardTelemetryRunning = true
	task.spawn(function()
		local frameCount = 0
		local accumTime = 0

		while dashboardTelemetryRunning and dashboardGui and dashboardGui.Enabled and dashboardGui.Parent do
			local step = RunService.RenderStepped:Wait()
			frameCount += 1
			accumTime += step

			if accumTime >= 0.5 then
				local currentFps = math.floor((frameCount / accumTime) + 0.5)
				frameCount = 0
				accumTime = 0

				local fpsText = string.format("%d FPS", currentFps)
				if fpsVal then fpsVal.Text = fpsText end
				if fpsPill then fpsPill.Text = "⚡ " .. tostring(currentFps) .. " FPS" end

				local pingMs = 30
				pcall(function()
					pingMs = math.floor((Player:GetNetworkPing() * 1000) + 0.5)
				end)
				local pingText = string.format("%d ms", pingMs)
				if pingVal then pingVal.Text = pingText end
				if pingPill then pingPill.Text = "📶 " .. pingText end

				local memMb = 125
				pcall(function()
					memMb = math.floor((gcinfo() / 1024) + 0.5)
				end)
				if memVal then memVal.Text = string.format("%d MB", memMb) end

				local instCount = #Workspace:GetDescendants()
				if instVal then instVal.Text = string.format("%d", instCount) end
			end
		end
	end)
end

Players.PlayerAdded:Connect(function()
	if dashboardGui and dashboardGui.Enabled and dashboardRefreshPlayers then
		task.defer(dashboardRefreshPlayers)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	if selectedDashboardPlayer == p.Name then
		selectedDashboardPlayer = nil
	end
	playerToggleStates[p.Name] = nil
	if dashboardGui and dashboardGui.Enabled and dashboardRefreshPlayers then
		task.defer(dashboardRefreshPlayers)
	end
end)

--// CINEMATIC FREECAM & ADMIN DRONE CONTROLLER //--
local isFreecamActive = false
local freecamMode = "Freecam"
local freecamConn: RBXScriptConnection? = nil
local freecamInputConn: RBXScriptConnection? = nil
local freecamPos = Vector3.new(0, 50, 0)
local freecamYaw = 0
local freecamPitch = 0
local keysDown = {}
local isNightVision = false
local isThermalVision = false
local nightVisionEffect: ColorCorrectionEffect? = nil
local thermalHighlights = {}

local function cleanupVisionEffects()
	if nightVisionEffect then
		nightVisionEffect:Destroy()
		nightVisionEffect = nil
	end
	for _, hl in pairs(thermalHighlights) do
		if hl and hl.Parent then hl:Destroy() end
	end
	thermalHighlights = {}
	isNightVision = false
	isThermalVision = false
end

local function toggleNightVision()
	isNightVision = not isNightVision
	local Lighting = game:GetService("Lighting")
	if isNightVision then
		if not nightVisionEffect then
			nightVisionEffect = Instance.new("ColorCorrectionEffect")
			nightVisionEffect.Name = "DroneNightVision"
			nightVisionEffect.TintColor = Color3.fromRGB(160, 255, 170)
			nightVisionEffect.Brightness = 0.35
			nightVisionEffect.Contrast = 0.5
			nightVisionEffect.Parent = Lighting
		end
	else
		if nightVisionEffect then
			nightVisionEffect:Destroy()
			nightVisionEffect = nil
		end
	end
end

local function toggleThermalVision()
	isThermalVision = not isThermalVision
	if isThermalVision then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player and p.Character then
				local hl = Instance.new("Highlight")
				hl.Name = "DroneThermalHL"
				hl.FillColor = Color3.fromRGB(249, 115, 22)
				hl.OutlineColor = Color3.fromRGB(56, 189, 248)
				hl.FillTransparency = 0.3
				hl.OutlineTransparency = 0
				hl.Adornee = p.Character
				hl.Parent = p.Character
				table.insert(thermalHighlights, hl)
			end
		end
	else
		for _, hl in pairs(thermalHighlights) do
			if hl and hl.Parent then hl:Destroy() end
		end
		thermalHighlights = {}
	end
end

local function toggleFreecam(enable: boolean, mode: string?)
	local camera = Workspace.CurrentCamera
	if not camera then return end

	if not enable then
		if not isFreecamActive then return end
		isFreecamActive = false
		if freecamConn then freecamConn:Disconnect(); freecamConn = nil end
		if freecamInputConn then freecamInputConn:Disconnect(); freecamInputConn = nil end
		cleanupVisionEffects()
		keysDown = {}

		camera.CameraType = Enum.CameraType.Custom
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end

	if isFreecamActive and mode == freecamMode then
		toggleFreecam(false)
		return
	end

	isFreecamActive = true
	freecamMode = mode or "Freecam"
	freecamPos = camera.CFrame.Position
	local rx, ry, _ = camera.CFrame:ToOrientation()
	freecamPitch = rx
	freecamYaw = ry

	camera.CameraType = Enum.CameraType.Scriptable

	freecamConn = RunService.RenderStepped:Connect(function(dt)
		if not isFreecamActive then return end

		local speed = 40
		if keysDown[Enum.KeyCode.LeftShift] or keysDown[Enum.KeyCode.RightShift] then
			speed = 130
		end

		local lookCF = CFrame.Angles(0, freecamYaw, 0) * CFrame.Angles(freecamPitch, 0, 0)
		local moveDir = Vector3.zero

		if keysDown[Enum.KeyCode.W] then moveDir += lookCF.LookVector end
		if keysDown[Enum.KeyCode.S] then moveDir -= lookCF.LookVector end
		if keysDown[Enum.KeyCode.D] then moveDir += lookCF.RightVector end
		if keysDown[Enum.KeyCode.A] then moveDir -= lookCF.RightVector end
		if keysDown[Enum.KeyCode.E] or keysDown[Enum.KeyCode.Space] then moveDir += Vector3.new(0, 1, 0) end
		if keysDown[Enum.KeyCode.Q] then moveDir -= Vector3.new(0, 1, 0) end

		if moveDir.Magnitude > 0 then
			freecamPos += moveDir.Unit * (speed * dt)
		end

		camera.CFrame = CFrame.new(freecamPos) * lookCF
	end)

	freecamInputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			keysDown[input.KeyCode] = true
			if input.KeyCode == Enum.KeyCode.N then
				toggleNightVision()
			elseif input.KeyCode == Enum.KeyCode.T then
				toggleThermalVision()
			elseif input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.X then
				toggleFreecam(false)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePos = UserInputService:GetMouseLocation()
			local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { Player.Character }

			local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
			if hit and hit.Instance then
				local targetModel = hit.Instance:FindFirstAncestorOfClass("Model")
				local targetPlayer = targetModel and Players:GetPlayerFromCharacter(targetModel)
				if targetPlayer then
					ExecuteRemote:FireServer(currentPrefix .. "freeze " .. targetPlayer.Name)
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keysDown[input.KeyCode] = nil
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not isFreecamActive then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition or freecamMode == "Drone" then
				local delta = input.Delta
				local sensitivity = 0.0035
				freecamYaw -= delta.X * sensitivity
				freecamPitch = math.clamp(freecamPitch - delta.Y * sensitivity, math.rad(-89), math.rad(89))
			end
		end
	end)
end

--// CLIENT ACTION HANDLERS //--
ClientAction.OnClientEvent:Connect(function(action, data)
	if action == "ToggleFreecam" then
		toggleFreecam(true, data and data.Mode or "Freecam")
	elseif action == "DisableFreecam" then
		toggleFreecam(false)
	elseif action == "noclip" then
		if noclipConnection then noclipConnection:Disconnect() end
		if data then
			noclipConnection = RunService.Stepped:Connect(function()
				if Player.Character then
					for _, v in pairs(Player.Character:GetDescendants()) do
						if v:IsA("BasePart") then v.CanCollide = false end
					end
				end
			end)
		end
	elseif action == "fly" then
		if data then startFlight() else stopFlight() end

	elseif action == "screenEffect" then
		local effectName = data and data.Effect
		if data and data.Enabled then
			applyScreenEffect(effectName, data.Properties)
		elseif effectName then
			removeScreenEffect(effectName)
		end

	elseif action == "blind" then
		local blindGui = PlayerGui:FindFirstChild("Blind")
		if data then
			if not blindGui then
				blindGui = cloneUiAsset("Blind", "ScreenGui")
				if blindGui then
					blindGui.Name = "Blind"
					blindGui.Parent = PlayerGui
				end
			end
		elseif blindGui then
			blindGui:Destroy()
		end

	elseif action == "flashbang" then
		local flashGui = cloneUiAsset("Flashbang", "ScreenGui")
		if flashGui then
			flashGui.Name = "Flashbang"
			flashGui.Parent = PlayerGui
			local frame = flashGui:FindFirstChildOfClass("Frame")
			if frame then
				local tween = TweenService:Create(frame, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
				tween:Play()
				tween.Completed:Connect(function() flashGui:Destroy() end)
			else
				task.delay(3, function() flashGui:Destroy() end)
			end
		end

	elseif action == "updateCharacterState" then
		local char = data.Char
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CameraSubject = hum
			end
			local animate = char:FindFirstChild("Animate")
			if animate then 
				animate.Enabled = false
				task.wait(0.1)
				animate.Enabled = true 
			end
		end
		if data.IsControlling == false then
			local PM = Player.PlayerScripts:FindFirstChild("PlayerModule")
			if PM then require(PM):GetControls():Enable() end
		end
	elseif action == "setControlState" then
		local playerModuleScript = Player.PlayerScripts:FindFirstChild("PlayerModule")
		if playerModuleScript then
			local Controls = require(playerModuleScript):GetControls()
			if data == false then Controls:Disable() else Controls:Enable() end
		end
	elseif action == "chatimage" then
		local tcs = game:GetService("TextChatService")
		if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
			local channel = tcs:FindFirstChild("TextChannels") and tcs.TextChannels:FindFirstChild("RBXSystem")
			if channel then
				local imageTag = string.format("<image src='rbxassetid://%s' width='100' height='100' />", data.ImageId)
				channel:DisplaySystemMessage(string.format("<font color='#AAAAAA'>[%s sent an image]:</font>\n%s", data.Sender, imageTag))
			end
		end
	elseif action == "UpdateLogs" then
		local logs = (typeof(data) == "table" and data.Logs) or data or {}
		local count = (typeof(data) == "table" and data.Count) or #logs
		local f = {}
		if #logs == 0 then
			table.insert(f, "No logs recorded.")
		else
			for _, l in ipairs(logs) do
				local timestamp = l.Timestamp and os.date("%m/%d/%Y %I:%M:%S %p", l.Timestamp) or "Unknown time"
				local idText = l.Id and ("#" .. tostring(l.Id) .. " | ") or ""
				table.insert(f, string.format("%s%s | %s: %s", idText, timestamp, l.User or "Unknown", l.Cmd or ""))
			end
		end
		CreateListGui("LogsGui", string.format("Server Logs (%d)", count), f)
	elseif action == "ShowCmds" then
		local cmdList = data.Commands or data
		local count = data.Count or #cmdList
		local f = {}
		for _, entry in ipairs(cmdList) do
			if typeof(entry) == "table" and entry.Name then
				local argumentParts = {}
				local aliases = entry.Aliases or {}
				if entry.TargetMode == "optional" then
					table.insert(argumentParts, "me|user|all|others|random")
				end
				for _, argDef in ipairs(entry.Args or {}) do
					local argumentText = "<" .. tostring(argDef.Name or argDef.Type or "value") .. ">"
					if argDef.Optional then
						argumentText = "[" .. argumentText .. "]"
					end
					table.insert(argumentParts, argumentText)
				end
				local syntax = currentPrefix .. tostring(entry.Name)
				if #argumentParts > 0 then
					syntax = syntax .. " " .. table.concat(argumentParts, " ")
				end
				local aliasText = #aliases > 0 and (" [aliases: " .. table.concat(aliases, ", ") .. "]") or ""
				table.insert(f, {
					Text = string.format("%s%s - %s", syntax, aliasText, entry.Desc or ""),
					SearchText = table.concat({
						tostring(entry.Name),
						table.concat(aliases, " "),
						tostring(entry.Desc or ""),
						tostring(entry.Category or ""),
						syntax,
					}, " "),
				})
			else
				table.insert(f, {
					Text = currentPrefix .. tostring(entry),
					SearchText = tostring(entry),
				})
			end
		end
		CreateListGui("CommandsGui", "Commands List (" .. tostring(count) .. ")", f, {
			Searchable = true,
			Placeholder = "Search commands, aliases, or descriptions...",
		})
	elseif action == "ShowList" then
		CreateListGui("InfoListGui", data.Title or "List", data.Data or {})
	elseif action == "ShowTeamCreator" then
		CreateTeamCreatorGui()
	elseif action == "ShowUnban" then
		local f = {}
		for _, n in ipairs(data) do table.insert(f, "User: " .. n) end
		CreateListGui("UnbanGui", "Ban List", f)
	elseif action == "ShowBanner" then
		local bannerId = (data and data.Id) or "AdminBanner"
		CreateBannerGui(bannerId, data)
	elseif action == "HideBanner" then
		local bannerId = (data and data.Id) or "AdminBanner"
		destroyBannerGui(bannerId)
	elseif action == "ShowModal" then
		local modalId = (data and data.Id) or "AdminModal"
		CreateModalGui(modalId, data)
	elseif action == "CloseModal" then
		local modalId = (data and data.Id) or "AdminModal"
		destroyModalGui(modalId)
	elseif action == "ToggleAllGuis" then
		setAllPlayerGuisVisible(data == true)
	elseif action == "xray" then
		setXrayEnabled(data == true)
	elseif action == "mute" then
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not data) end)
	elseif action == "ToggleDashboard" then
		toggleDashboard()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == commandBarKey and not processed then
		toggleBar()
	elseif input.KeyCode == Enum.KeyCode.F2 and not processed then
		toggleDashboard()
	end
	if input.KeyCode == Enum.KeyCode.Tab and InputBox:IsFocused() then
		if currentTopSuggestion ~= "" then
			InputBox.Text = currentTopSuggestion .. " "
			task.defer(function()
				InputBox.Text = InputBox.Text:gsub("\t", "")
				InputBox.CursorPosition = #InputBox.Text + 1
				updateSuggestions()
			end)
		end
	end
end)

InputBox:GetPropertyChangedSignal("Text"):Connect(function()
	if InputBox.Text:sub(1, #currentPrefix * 2) == currentPrefix .. currentPrefix then
		InputBox.Text = currentPrefix
		InputBox.CursorPosition = #currentPrefix + 1
	end
	updateSuggestions()
end)

InputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local txt = InputBox.Text:gsub("\t", "")
		if txt ~= "" then
			if txt:sub(1, #currentPrefix) ~= currentPrefix then
				txt = currentPrefix .. txt
			end
			ExecuteRemote:FireServer(txt)
		end
		toggleBar()
	else
		isOpen = false
		Gui.Enabled = false
		InputBox.Text = ""
		SuggestionFrame.Visible = false
	end
end)

--// TEXT CHAT SERVICE FORMATTER //--
local TextChatService = game:GetService("TextChatService")
if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		if message.TextSource then
			local player = Players:GetPlayerByUserId(message.TextSource.UserId)
			if player then
				local chatColor = player:GetAttribute("ChatColor")
				if chatColor then
					local hexColor = "#" .. chatColor:ToHex()
					properties.Text = string.format("<font color='%s'>%s</font>", hexColor, message.Text)
				end
			end
		end
		return properties
	end
end

--// PM UI HANDLER //--
-- Centralized event to detect when the Server sends a PM GUI to the player
local function hookPmGui(gui)
	if not gui or not gui:IsA("ScreenGui") then return end
	task.defer(function()
		local frame = gui:FindFirstChild("Frame") or gui:FindFirstChildOfClass("Frame")
		if frame and frame:FindFirstChild("ReplyBox") and frame:FindFirstChild("ReplyButton") then
			local replyBox = frame:WaitForChild("ReplyBox")
			local replyBtn = frame:WaitForChild("ReplyButton")
			local closeBtn = frame:WaitForChild("CloseButton")

			replyBtn.MouseButton1Click:Connect(function()
				local replyText = replyBox.Text
				local senderValue = gui:FindFirstChild("SenderName") 

				if replyText ~= "" and senderValue then
					ExecuteRemote:FireServer(currentPrefix .. "pm " .. senderValue.Value .. " " .. replyText)
					gui:Destroy()
				end
			end)

			closeBtn.MouseButton1Click:Connect(function()
				gui:Destroy()
			end)
		end
	end)
end

PlayerGui.ChildAdded:Connect(hookPmGui)
for _, child in ipairs(PlayerGui:GetChildren()) do
	hookPmGui(child)
end
