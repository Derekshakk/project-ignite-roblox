--[[
	InteractionController

	Connects tagged ProximityPrompts in the world to the GameController.
	Prompts carry an InteractionType and InteractionId (Constants/World); this
	module only routes them. Whether a prompt is available, and what it says,
	comes from the controller, so prompts disable themselves while a dialog
	is open, after a scenario is done, or before an activity is unlocked.
	On top of that, every prompt is disabled whenever UIState is not Idle
	(an NPC is talking, a panel is open, a task is running) and comes back
	when the interaction ends.

	Routing:
		Scenario, Activity, Inspect, EndDay → controller:interact
		Activity with a `guided` task → GuidedTask (a short physical
		           action; the activity is performed when it finishes)
		Door     → Doors.toggle (prompt reads "Open Door"/"Close Door")
		Signal   → Crosswalks.request (walk-signal buttons)
		Travel   → fade, server moves the character, controller:arriveAt
		Pickup   → Inventory:collect (server grants the Tool first)
		Sit      → server seats the character; if the prompt has a
		           ScenarioLocation with an available scenario, it starts
	Double triggers are blocked three ways: a busy flag while a server
	request is in flight, a short global cooldown between triggers, and the
	triggered prompt being disabled immediately until state is refreshed.

	Enabling/disabling happens locally, so each player sees their own
	progress.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local ServerRequests = require(script.Parent.ServerRequests)
local Doors = require(script.Parent.Doors)
local GuidedTask = require(script.Parent.GuidedTask)
local PlayerControl = require(script.Parent.PlayerControl)

local Tags = World.Tags
local Attributes = World.Attributes
local InteractionType = World.InteractionTypes

-- Minimum time between two triggers (any prompts).
local TRIGGER_COOLDOWN = 0.45
-- Let a door start swinging before the screen fades.
local DOOR_LEAD_SECONDS = 0.25

local localPlayer = Players.LocalPlayer

local InteractionController = {}
InteractionController.__index = InteractionController

--[[
	services:
		inventory     Inventory (client)
		feedback      InteractionFeedback
		transitions   Transitions (fades)
		uiState       UIState
		tasks         GuidedTask
		crosswalks    Crosswalks
		notify        (notification) -> () for short messages
]]
function InteractionController.new(controller, services)
	return setmetatable({
		_controller = controller,
		_inventory = services.inventory,
		_feedback = services.feedback,
		_transitions = services.transitions,
		_uiState = services.uiState,
		_tasks = services.tasks,
		_crosswalks = services.crosswalks,
		_notify = services.notify,
		_bindings = {} :: { [ProximityPrompt]: { connection: RBXScriptConnection, defaultActionText: string } },
		_busy = false,
		_lastTrigger = 0,
	}, InteractionController)
end

function InteractionController:start()
	for _, instance in CollectionService:GetTagged(Tags.Interactable) do
		self:_bind(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Interactable):Connect(function(instance)
		self:_bind(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.Interactable):Connect(function(instance)
		self:_unbind(instance)
	end)

	local function refresh()
		self:refreshAll()
	end
	self._controller.Changed:Connect(refresh)
	self._controller.StateChanged:Connect(refresh)
	self._uiState.Changed:Connect(refresh)
	Doors.Changed:Connect(refresh)

	-- Sit prompts hide while you're sitting in that seat.
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Seated:Connect(refresh)
		end
		refresh()
	end
	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end

	-- The controller asks for the character to be placed at the start of
	-- the day (new run or restart).
	self._controller.TeleportRequested:Connect(function(destinationId)
		self:_travel(destinationId)
	end)
end

function InteractionController:_bind(instance: Instance)
	if not instance:IsA("ProximityPrompt") or self._bindings[instance] then
		return
	end
	local prompt = instance :: ProximityPrompt
	local connection = prompt.Triggered:Connect(function(playerWhoTriggered)
		if playerWhoTriggered == localPlayer then
			self:_onTriggered(prompt)
		end
	end)
	self._bindings[prompt] = { connection = connection, defaultActionText = prompt.ActionText }
	self:_refresh(prompt)
end

function InteractionController:_unbind(instance: Instance)
	local binding = self._bindings[instance :: any]
	if binding then
		binding.connection:Disconnect()
		self._bindings[instance :: any] = nil
	end
end

local function currentSeat(): Instance?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.SeatPart
end

-- What a prompt should show: { available, actionText }.
function InteractionController:_describe(prompt: ProximityPrompt)
	local interactionType = prompt:GetAttribute(Attributes.InteractionType)
	local interactionId = prompt:GetAttribute(Attributes.InteractionId)
	local info = self._controller:getInteraction(interactionType, interactionId)
	if interactionType == InteractionType.Door then
		local leaf = prompt.Parent
		if leaf and leaf:IsA("BasePart") then
			info.actionText = if Doors.isLocked(leaf) then "Try Door" elseif Doors.isOpen(leaf) then "Close Door" else "Open Door"
		end
	end
	if interactionType == InteractionType.Sit then
		if currentSeat() == prompt.Parent then
			info.available = false
		end
		-- A seat can host a scenario: use its prompt text while available.
		local location = prompt:GetAttribute(Attributes.ScenarioLocation)
		if info.available and type(location) == "string" then
			local scenario = self._controller:getInteraction(InteractionType.Scenario, location)
			if scenario.available then
				info.actionText = scenario.actionText
			end
		end
		-- A seat can host a short recovery task; once done it's just a seat.
		local seat = prompt.Parent
		local activityId = seat and seat:GetAttribute(Attributes.RecoveryActivity)
		if info.available and type(activityId) == "string" then
			local activity = self._controller:getInteraction(InteractionType.Activity, activityId)
			if not activity.available then
				info.actionText = "Sit"
			end
		end
	end
	return info
end

function InteractionController:_refresh(prompt: ProximityPrompt)
	local binding = self._bindings[prompt]
	if not binding then
		return
	end
	local info = self:_describe(prompt)
	prompt.Enabled = info.available and not self._busy and self._uiState:isIdle()
	prompt.ActionText = info.actionText or binding.defaultActionText
end

function InteractionController:refreshAll()
	for prompt in self._bindings do
		self:_refresh(prompt)
	end
end

-- Runs `work` with interactions blocked (server round-trips).
function InteractionController:_withBusy(work: () -> any): any
	if self._busy then
		return nil
	end
	self._busy = true
	self:refreshAll()
	local ok, result = pcall(work)
	self._busy = false
	self:refreshAll()
	if not ok then
		warn(`[InteractionController] {result}`)
		return nil
	end
	return result
end

-- Fades, moves the character via the server; returns the area id.
function InteractionController:_travel(destinationId: string): string?
	return self:_withBusy(function()
		self._transitions:fadeOut()
		local ok, areaId = ServerRequests.travel(destinationId)
		self._transitions:fadeIn()
		return if ok then areaId else nil
	end)
end

function InteractionController:_onTriggered(prompt: ProximityPrompt)
	local interactionType = prompt:GetAttribute(Attributes.InteractionType)
	local interactionId = prompt:GetAttribute(Attributes.InteractionId)
	if type(interactionType) ~= "string" or type(interactionId) ~= "string" then
		return
	end
	-- Re-check everything: the prompt may have been triggered in the same
	-- frame something else changed, or pressed again before it hid.
	local now = os.clock()
	if self._busy or not self._uiState:isIdle() or now - self._lastTrigger < TRIGGER_COOLDOWN then
		return
	end
	if not self:_describe(prompt).available then
		return
	end
	self._lastTrigger = now
	-- Hide this prompt right away; the refresh below (or the state change
	-- the interaction causes) brings it back if it's still available.
	prompt.Enabled = false
	task.delay(TRIGGER_COOLDOWN, function()
		self:_refresh(prompt)
	end)
	local controller = self._controller

	if interactionType == InteractionType.Door then
		local leaf = prompt.Parent
		if leaf and leaf:IsA("BasePart") and Doors.toggle(leaf) == "locked" then
			local message = leaf:GetAttribute(World.Attributes.LockedMessage)
			self._notify({ title = prompt.ObjectText, message = if type(message) == "string" then message else "It's locked." })
		end
	elseif interactionType == InteractionType.Signal then
		self._feedback:cue("use")
		self._crosswalks:request(interactionId)
	elseif interactionType == InteractionType.Activity and GuidedTask.isGuided(interactionId) then
		-- Walking away from where the task started stops it.
		local part = prompt.Parent
		local anchor = PlayerControl.getRootPosition() or (if part and part:IsA("BasePart") then part.Position else nil)
		if anchor and self._tasks:begin(interactionId, anchor) then
			self._feedback:play(prompt)
		end
	elseif interactionType == InteractionType.Travel then
		self._feedback:play(prompt)
		if prompt:FindFirstChild("AnimatedDoor") then
			task.wait(DOOR_LEAD_SECONDS)
		end
		local areaId = self:_travel(interactionId)
		if areaId then
			controller:arriveAt(areaId)
		end
	elseif interactionType == InteractionType.Pickup then
		-- Snapshot the item before it hides, so it can animate away.
		local ghost = self._feedback:snapshot(prompt)
		local collected = self:_withBusy(function()
			return self._inventory:collect(interactionId)
		end)
		if collected then
			self._feedback:play(prompt, ghost)
		elseif ghost then
			ghost:Destroy()
		end
	elseif interactionType == InteractionType.Sit then
		local seated = self:_withBusy(function()
			return ServerRequests.sit(interactionId)
		end)
		if seated then
			self._feedback:cue("use")
			local location = prompt:GetAttribute(Attributes.ScenarioLocation)
			if type(location) == "string" and controller:getInteraction(InteractionType.Scenario, location).available then
				controller:startScenarioAt(location)
			end
		end
	else
		local ghost = self._feedback:snapshot(prompt)
		if controller:interact(interactionType, interactionId) then
			self._feedback:play(prompt, ghost)
		elseif ghost then
			ghost:Destroy()
		end
	end
end

return InteractionController
