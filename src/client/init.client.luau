--[[
	Client entry point.

	Wires the pieces together:
	- GameController (shared): game flow and state, no UI or world code.
	- UIState: which major interaction is on screen (one at a time); prompts,
	  panels, NPC speech and tasks all follow it.
	- World layer: interactions (prompts → controller), inventory (items and
	  Tools), zones and areas (where the character is), NPCs (animation,
	  speech bubbles, background chatter, scenes), guided tasks (breathing,
	  stretching, waiting), doors, crosswalk signals, time of day (sky),
	  audio, movement feedback, objective marker, flag-driven visibility,
	  player control (camera/movement), and ambient life (traffic,
	  passers-by, swaying trees and other small world motion; visual only).
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
local NpcSpeech = require(WorldFolder:WaitForChild("NpcSpeech"))
local AmbientChatter = require(WorldFolder:WaitForChild("AmbientChatter"))
local SceneDirector = require(WorldFolder:WaitForChild("SceneDirector"))
local GuidedTask = require(WorldFolder:WaitForChild("GuidedTask"))
local Crosswalks = require(WorldFolder:WaitForChild("Crosswalks"))
local TimeOfDay = require(WorldFolder:WaitForChild("TimeOfDay"))
local FlagVisibility = require(WorldFolder:WaitForChild("FlagVisibility"))
local Doors = require(WorldFolder:WaitForChild("Doors"))
local MovementFeedback = require(WorldFolder:WaitForChild("MovementFeedback"))
local ObjectiveMarker = require(WorldFolder:WaitForChild("ObjectiveMarker"))
local AmbientLife = require(WorldFolder:WaitForChild("Ambient"):WaitForChild("AmbientLife"))
local App = require(UIFolder:WaitForChild("App"))
local Captions = require(UIFolder:WaitForChild("Hud"):WaitForChild("Captions"))
local Transitions = require(UIFolder:WaitForChild("Transitions"))
local UIState = require(script:WaitForChild("UIState"))

local Phase = GameController.Phase
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

PlayerControl.configure()

local controller = GameController.new()
local uiState = UIState.new()
local app = App.new(controller, playerGui, uiState)
local transitions = Transitions.new(playerGui)
local captions = Captions.new(playerGui)
local effects = EnvironmentEffects.new()
local feedback = InteractionFeedback.new()
local inventory = Inventory.new(controller)
local npcAnimator = NpcAnimator.new()
local speech = NpcSpeech.new(npcAnimator, playerGui)
local tasks = GuidedTask.new(controller, uiState, feedback, playerGui)
local crosswalks = Crosswalks.new()
local timeOfDay = TimeOfDay.new(controller)

local interactions = InteractionController.new(controller, {
	inventory = inventory,
	feedback = feedback,
	transitions = transitions,
	uiState = uiState,
	tasks = tasks,
	crosswalks = crosswalks,
	notify = function(notification)
		app:notify(notification)
	end,
})
local zones = ZoneController.new(controller, effects)
local areas = AreaController.new(controller, transitions)
local audio = AudioController.new(controller)
local scenes = SceneDirector.new(controller, uiState, npcAnimator, speech, captions, function(notification)
	app:notify(notification)
end)
local chatter = AmbientChatter.new(controller, uiState, speech)
local flagVisibility = FlagVisibility.new(controller)
local marker = ObjectiveMarker.new(controller)
local ambientLife = AmbientLife.new(controller, crosswalks)

-- Movement is paused and the hotbar hidden while menus or dialogs are open.
local function syncPhase()
	local phase = controller:getPhase()
	PlayerControl.setMovementEnabled(phase == Phase.Exploring)
	PlayerControl.setHotbarVisible(phase ~= Phase.CharacterSelect and phase ~= Phase.Results)
end
controller.Changed:Connect(syncPhase)
-- A new run puts the world back: doors and covers close again.
controller.Changed:Connect(function(phase)
	if phase == Phase.CharacterSelect then
		Doors.resetAll()
	end
end)
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
speech:start()
scenes:start()
chatter:start()
tasks:start()
crosswalks:start()
timeOfDay:start()
flagVisibility:start()
Doors.start()
MovementFeedback.start()
marker:start()
ambientLife:start()
app:start()
syncPhase()
