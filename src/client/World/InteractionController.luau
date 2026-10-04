--[[
	InteractionController

	Connects tagged ProximityPrompts in the world to the GameController.
	Prompts carry an InteractionType and InteractionId (Constants/World); this
	module only routes them. Whether a prompt is available, and what it says,
	comes from the controller, so prompts disable themselves while a dialog
	is open, after a scenario is done, or before an activity is unlocked.

	Routing:
		Scenario, Activity, Inspect, EndDay → controller:interact
		Travel   → fade, server moves the character, controller:arriveAt
		Pickup   → Inventory:collect (server grants the Tool first)
		Sit      → server seats the character; if the prompt has a
		           ScenarioLocation with an available scenario, it starts
	A single busy flag blocks new interactions while a server request is in
	flight, so prompts can't be triggered twice by accident.

	Enabling/disabling happens locally, so each player sees their own
	progress.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local ServerRequests = require(script.Parent.ServerRequests)

local Tags = World.Tags
local Attributes = World.Attributes
local InteractionType = World.InteractionTypes

local localPlayer = Players.LocalPlayer

local InteractionController = {}
InteractionController.__index = InteractionController

--[[
	services:
		inventory     Inventory (client)
		feedback      InteractionFeedback
		transitions   Transitions (fades)
]]
function InteractionController.new(controller, services)
	return setmetatable({
		_controller = controller,
		_inventory = services.inventory,
		_feedback = services.feedback,
		_transitions = services.transitions,
		_bindings = {} :: { [ProximityPrompt]: { connection: RBXScriptConnection, defaultActionText: string } },
		_busy = false,
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
	end
	return info
end

function InteractionController:_refresh(prompt: ProximityPrompt)
	local binding = self._bindings[prompt]
	if not binding then
		return
	end
	local info = self:_describe(prompt)
	prompt.Enabled = info.available and not self._busy
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
	-- Re-check availability: the prompt may have been triggered in the same
	-- frame something else changed.
	if self._busy or not self:_describe(prompt).available then
		return
	end
	local controller = self._controller

	if interactionType == InteractionType.Travel then
		self._feedback:play(prompt)
		local areaId = self:_travel(interactionId)
		if areaId then
			controller:arriveAt(areaId)
		end
	elseif interactionType == InteractionType.Pickup then
		local collected = self:_withBusy(function()
			return self._inventory:collect(interactionId)
		end)
		if collected then
			self._feedback:play(prompt)
			local part = prompt.Parent
			if part and part:IsA("BasePart") then
				self._feedback:sparkle(part.Position)
			end
		end
	elseif interactionType == InteractionType.Sit then
		local seated = self:_withBusy(function()
			return ServerRequests.sit(interactionId)
		end)
		if seated then
			local location = prompt:GetAttribute(Attributes.ScenarioLocation)
			if type(location) == "string" and controller:getInteraction(InteractionType.Scenario, location).available then
				controller:startScenarioAt(location)
			end
		end
	elseif controller:interact(interactionType, interactionId) then
		self._feedback:play(prompt)
	end
end

return InteractionController
