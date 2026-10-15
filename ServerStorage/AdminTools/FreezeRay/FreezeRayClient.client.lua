--!strict
-- FreezeRayClient.client.lua
-- Client controller for the Freeze Ray / Ice Wand.
-- Raycasts from camera to mouse position and transmits aim coordinates to server.

local Players = game:GetService("Players")

local tool = script.Parent :: Tool
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local isEquipped = false
local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent?
	if remote and remote.Parent then return remote end
	remote = tool:FindFirstChild("FreezeRemote") :: RemoteEvent?
	if not remote then
		remote = tool:WaitForChild("FreezeRemote", 4) :: RemoteEvent?
	end
	return remote
end

local function getAimTarget(): Vector3
	local camera = workspace.CurrentCamera
	if camera then
		local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }

		local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
		if result then
			return result.Position
		else
			return ray.Origin + (ray.Direction.Unit * 300)
		end
	end
	return mouse.Hit.Position
end

tool.Equipped:Connect(function()
	isEquipped = true
	-- Crosshair aim cursor
	mouse.Icon = "rbxassetid://6034304897"
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	mouse.Icon = ""
end)

tool.Activated:Connect(function()
	if not isEquipped then return end
	local targetPos = getAimTarget()
	local r = getRemote()
	if r then
		r:FireServer(targetPos)
	end
end)
