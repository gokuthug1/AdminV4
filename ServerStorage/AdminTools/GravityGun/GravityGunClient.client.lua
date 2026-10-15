--!strict
-- GravityGunClient.client.lua
-- Client controller for the Gravity Gun. Handles mouse raycasting, levitation tracking, and fling input.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local tool = script.Parent :: Tool
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local remote = tool:WaitForChild("GravRemote", 5) :: RemoteEvent?
local isEquipped = false
local isHolding = false
local holdDistance = 14
local renderConn: RBXScriptConnection? = nil

local function getTarget(): BasePart?
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 60, params)
	if result and result.Instance and result.Instance:IsA("BasePart") then
		local hit = result.Instance
		if not hit.Anchored then
			return hit
		end
	end
	return nil
end

tool.Equipped:Connect(function()
	isEquipped = true
	isHolding = false

	renderConn = RunService.RenderStepped:Connect(function()
		if not isHolding or not remote then return end
		local camera = workspace.CurrentCamera
		if not camera or not player.Character then return end
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end

		local aimRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
		local targetPos = root.Position + (aimRay.Direction.Unit * holdDistance)
		local targetCF = CFrame.new(targetPos, targetPos + aimRay.Direction)

		remote:FireServer("UpdateHolder", { CFrame = targetCF })
	end)
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	isHolding = false
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if remote then
		remote:FireServer("Release")
	end
end)

tool.Activated:Connect(function()
	if not remote or not isEquipped then return end

	if not isHolding then
		local target = getTarget()
		if target then
			isHolding = true
			remote:FireServer("Grab", { TargetPart = target })
		end
	else
		-- Fling the held object!
		local camera = workspace.CurrentCamera
		local aimRay = camera and camera:ScreenPointToRay(mouse.X, mouse.Y)
		local dir = if aimRay then aimRay.Direction.Unit else Vector3.new(0, 0, -1)

		remote:FireServer("Fling", { Direction = dir })
		isHolding = false
	end
end)

-- Right click to release gently without flinging
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not isEquipped or not isHolding then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if remote then
			remote:FireServer("Release")
		end
		isHolding = false
	end
end)
