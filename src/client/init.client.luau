--[[
	Client entry point.

	Wires the pieces together:
	- GameController (shared): game flow and state, no UI or world code.
	- World layer: interactions (prompts → controller), inventory (items and
	  Tools), zones and areas (where the character is), NPC animation and
	  scenes, doors, audio, movement feedback, objective marker, and player
	  control (camera/movement).
	- UI layer: App (HUD, dialogs, menus, settings), captions, transitions.
	- Settings: player comfort options read by the optional effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameController = require(Shared:WaitForChild("Game"):WaitForChild("GameController"))

local WorldFolder = script:WaitForChild("World")
local UIFolder = script:WaitForChild("UI")
local PlayerControl = require(WorldFolder:WaitForChild("PlayerControl"))
local EnvironmentEffects = require(WorldFolder:WaitForChild("EnvironmentEffects"))
local InteractionController = require(WorldFolder:WaitForChild("InteractionController"))
local InteractionFeedback = require(WorldFolder:WaitForChild("InteractionFeedback"))
local Inventory = require(WorldFolder:WaitForChild("Inventory"))
local ZoneController = require(WorldFolder:WaitForChild("ZoneController"))
local AreaController = require(WorldFolder:WaitForChild("AreaController"))
local AudioController = require(WorldFolder:WaitForChild("AudioController"))
local NpcAnimator = require(WorldFolder:WaitForChild("NpcAnimator"))
local SceneDirector = require(WorldFolder:WaitForChild("SceneDirector"))
local Doors = require(WorldFolder:WaitForChild("Doors"))
local MovementFeedback = require(WorldFolder:WaitForChild("MovementFeedback"))
local ObjectiveMarker = require(WorldFolder:WaitForChild("ObjectiveMarker"))
local App = require(UIFolder:WaitForChild("App"))
local Captions = require(UIFolder:WaitForChild("Hud"):WaitForChild("Captions"))
local Transitions = require(UIFolder:WaitForChild("Transitions"))

local Phase = GameController.Phase
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

PlayerControl.configure()

local controller = GameController.new()
local app = App.new(controller, playerGui)
local transitions = Transitions.new(playerGui)
local captions = Captions.new(playerGui)
local effects = EnvironmentEffects.new()
local feedback = InteractionFeedback.new()
local inventory = Inventory.new(controller)
local npcAnimator = NpcAnimator.new()

local interactions = InteractionController.new(controller, {
	inventory = inventory,
	feedback = feedback,
	transitions = transitions,
})
local zones = ZoneController.new(controller, effects)
local areas = AreaController.new(controller, transitions)
local audio = AudioController.new(controller)
local scenes = SceneDirector.new(controller, npcAnimator, captions, function(notification)
	app:notify(notification)
end)
local marker = ObjectiveMarker.new(controller)

-- Movement is paused and the hotbar hidden while menus or dialogs are open.
local function syncPhase()
	local phase = controller:getPhase()
	PlayerControl.setMovementEnabled(phase == Phase.Exploring)
	PlayerControl.setHotbarVisible(phase ~= Phase.CharacterSelect and phase ~= Phase.Results)
end
controller.Changed:Connect(syncPhase)
player.CharacterAdded:Connect(function()
	task.defer(function()
		effects:applyWalkSpeed()
	end)
end)

feedback:start()
inventory:start()
interactions:start()
zones:start()
areas:start()
audio:start()
npcAnimator:start()
scenes:start()
Doors.start()
MovementFeedback.start()
marker:start()
app:start()
syncPhase()
