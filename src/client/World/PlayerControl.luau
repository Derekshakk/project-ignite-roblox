--[[
	PlayerControl

	Local player setup for the prototype: camera limits, which Roblox core
	UI is shown, and pausing movement while a dialog or menu is open.
	First person is allowed (scroll in, or press I/O); dialog and menu
	buttons are Modal, so the mouse is freed whenever one is open.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- Zooming all the way in gives first person; the max keeps the camera
-- close enough to work well indoors.
local CAMERA_MIN_ZOOM = 0.5
local CAMERA_MAX_ZOOM = 22

local PlayerControl = {}

local controls = nil
local movementEnabled = true

local function getControls()
	if controls then
		return controls
	end
	local ok, result = pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		return playerModule:GetControls()
	end)
	if ok then
		controls = result
	else
		warn(`[PlayerControl] Could not access movement controls: {result}`)
	end
	return controls
end

local function applyMovement()
	local current = getControls()
	if not current then
		return
	end
	if movementEnabled then
		current:Enable()
	else
		current:Disable()
	end
end

function PlayerControl.configure()
	player.CameraMinZoomDistance = CAMERA_MIN_ZOOM
	player.CameraMaxZoomDistance = CAMERA_MAX_ZOOM
	-- Single-player prototype: no player list. The Backpack (hotbar) stays
	-- on so items like headphones can be equipped.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	-- Re-apply the movement lock if the character respawns.
	player.CharacterAdded:Connect(function()
		task.defer(applyMovement)
	end)
end

-- Hides the hotbar during menus (character select, results).
function PlayerControl.setHotbarVisible(visible: boolean)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible)
end

function PlayerControl.setMovementEnabled(enabled: boolean)
	movementEnabled = enabled
	applyMovement()
end

function PlayerControl.getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function PlayerControl.getRootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

return PlayerControl
