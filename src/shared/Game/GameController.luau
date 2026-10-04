--[[
	GameController

	Owns the game flow and is the only place that changes GameState.

	Phases:
		CharacterSelect → Exploring ⇄ Scenario → Feedback → Exploring ... → Results
	Players spend most of their time in Exploring, walking around the world.
	Interactions (scenarios, activities) open a compact dialog (Scenario /
	Feedback) and then return to Exploring. Zones apply bounded effects while
	the player stands in them. When the day plan's objectives are complete,
	the day can be ended to see Results.

	The world layer (client) and UI call the public actions below. Every
	action checks the current phase and per-day limits first, so repeated or
	stale calls (double clicks, prompt spam) are ignored rather than applied
	twice. Listeners react through the signals:
		Changed(phase)               phase changed
		StateChanged()               anything in GameState changed
		MetersChanged(changes, source)
		Notified(notification)       { title, message, changes? } for toasts
		TeleportRequested(destinationId)
		InventoryChanged()           items collected or equipped/unequipped

	This module has no UI or client-only dependencies, so the same controller
	could later run on the server if the game needs authoritative state.
]]

local Shared = script.Parent.Parent
local Characters = require(Shared.Data.Characters)
local Scenarios = require(Shared.Data.Scenarios)
local Activities = require(Shared.Data.Activities)
local Inspectables = require(Shared.Data.Inspectables)
local Items = require(Shared.Data.Items)
local Zones = require(Shared.Data.Zones)
local DayPlans = require(Shared.Data.DayPlans)
local World = require(Shared.Constants.World)
local GameState = require(Shared.State.GameState)
local Signal = require(Shared.Util.Signal)
local Conditions = require(script.Parent.Conditions)
local Objectives = require(script.Parent.Objectives)
local Reflection = require(script.Parent.Reflection)
local Rules = require(script.Parent.Rules)

local InteractionType = World.InteractionTypes

local Phase = table.freeze({
	CharacterSelect = "CharacterSelect",
	Exploring = "Exploring",
	Scenario = "Scenario",
	Feedback = "Feedback",
	Results = "Results",
})

local FIRST_DAY = 1

local GameController = {}
GameController.__index = GameController
GameController.Phase = Phase

function GameController.new()
	local self = setmetatable({
		Changed = Signal.new(),
		StateChanged = Signal.new(),
		MetersChanged = Signal.new(),
		Notified = Signal.new(),
		TeleportRequested = Signal.new(),
		InventoryChanged = Signal.new(),

		_phase = Phase.CharacterSelect,
		_character = nil,
		_state = nil,
		_dayPlan = nil,
		_activeScenario = nil,
		_lastResult = nil,
		_activeZones = {},
		_lastObjective = nil,
	}, GameController)
	return self
end

---------------------------------------------------------------------------
-- Internals
---------------------------------------------------------------------------

function GameController:_setPhase(phase: string)
	self._phase = phase
	self.Changed:Fire(phase)
end

function GameController:_clearSession()
	self._character = nil
	self._state = nil
	self._dayPlan = nil
	self._activeScenario = nil
	self._lastResult = nil
	self._activeZones = {}
	self._lastObjective = nil
end

-- Fires StateChanged, and announces when the current objective advanced.
function GameController:_stateChanged()
	if self._state and self._dayPlan then
		local current = Objectives.getCurrent(self._dayPlan, self._state)
		local previous = self._lastObjective
		if previous and previous ~= current then
			self.Notified:Fire({ title = "Objective complete", message = previous.text })
		end
		self._lastObjective = current
	end
	self.StateChanged:Fire()
end

function GameController:_applyEffects(effects, source)
	local changes = self._state:applyEffects(effects)
	self.MetersChanged:Fire(changes, source)
	return changes
end

function GameController:_markArea(areaId: string)
	self._state.area = areaId
	self._state:setFlags({ [`visited:{areaId}`] = true })
end

function GameController:_resolve(entry)
	return Rules.resolve(entry, self._character.id, self._state)
end

-- First scenario at a location this character can play right now.
function GameController:_findScenarioAt(locationId: string)
	local state = self._state
	for _, scenario in Scenarios.getAtLocation(self._character.id, state.day, locationId) do
		local available = not state:hasChosen(scenario.id)
			and (scenario.condition == nil or scenario.condition(state))
		if available then
			return scenario
		end
	end
	return nil
end

function GameController:_isActivityAvailable(activity): boolean
	local uses = self._state:getCounter(`activity:{activity.id}`)
	return uses < (activity.maxUses or 1) and Conditions.evaluate(activity.requires, self._state)
end

function GameController:_isExploring(): boolean
	return self._phase == Phase.Exploring and self._state ~= nil
end

---------------------------------------------------------------------------
-- Session actions
---------------------------------------------------------------------------

function GameController:getPhase(): string
	return self._phase
end

function GameController:selectCharacter(characterId: string): boolean
	if self._phase ~= Phase.CharacterSelect then
		return false
	end
	local character = Characters.get(characterId)
	if not character then
		warn(`[GameController] Unknown character "{characterId}".`)
		return false
	end
	local plan = DayPlans.get(character.id, FIRST_DAY)
	if not plan then
		warn(`[GameController] No day plan for "{character.id}" on day {FIRST_DAY}.`)
		return false
	end

	self:_clearSession()
	self._character = character
	self._state = GameState.new(character)
	self._dayPlan = plan
	self:_markArea(plan.startArea)
	self._lastObjective = Objectives.getCurrent(plan, self._state)

	self:_setPhase(Phase.Exploring)
	self.TeleportRequested:Fire(plan.startDestination)
	self:_stateChanged()
	return true
end

-- Called by the world layer after the character has been moved to an area.
function GameController:arriveAt(areaId: string): boolean
	if not self._state or type(areaId) ~= "string" then
		return false
	end
	self:_markArea(areaId)
	self:_stateChanged()
	return true
end

function GameController:endDay(): boolean
	if not self:_isExploring() or not Objectives.isDayComplete(self._dayPlan, self._state) then
		return false
	end
	self:_setPhase(Phase.Results)
	return true
end

function GameController:restart(): boolean
	if self._phase == Phase.CharacterSelect then
		return false
	end
	self:_clearSession()
	self:_setPhase(Phase.CharacterSelect)
	self.StateChanged:Fire()
	return true
end

---------------------------------------------------------------------------
-- World interactions
---------------------------------------------------------------------------

--[[
	What an interaction point should show right now:
	{ available: boolean, actionText: string? }
	Travel is executed by the world layer; the controller only decides
	whether it is currently allowed.
]]
function GameController:getInteraction(interactionType: string, interactionId: string)
	local info = { available = false, actionText = nil }
	if not self:_isExploring() then
		return info
	end

	if interactionType == InteractionType.Scenario then
		local scenario = self:_findScenarioAt(interactionId)
		info.available = scenario ~= nil
		info.actionText = scenario and scenario.promptText
	elseif interactionType == InteractionType.Activity then
		local activity = Activities.get(interactionId)
		if activity then
			info.available = self:_isActivityAvailable(activity)
			info.actionText = self:_resolve(activity).actionText
		end
	elseif interactionType == InteractionType.Travel then
		info.available = true
	elseif interactionType == InteractionType.EndDay then
		info.available = Objectives.isDayComplete(self._dayPlan, self._state)
	elseif interactionType == InteractionType.Pickup then
		local item = Items.get(interactionId)
		if item then
			info.available = not self._state:hasItem(item.id)
			info.actionText = item.pickupActionText
		end
	elseif interactionType == InteractionType.Inspect then
		local inspectable = Inspectables[interactionId]
		if inspectable then
			info.available = true
			info.actionText = inspectable.actionText
		end
	elseif interactionType == InteractionType.Sit then
		info.available = true
	end
	return info
end

function GameController:interact(interactionType: string, interactionId: string): boolean
	if interactionType == InteractionType.Scenario then
		return self:startScenarioAt(interactionId)
	elseif interactionType == InteractionType.Activity then
		return self:performActivity(interactionId)
	elseif interactionType == InteractionType.EndDay then
		return self:endDay()
	elseif interactionType == InteractionType.Inspect then
		return self:inspect(interactionId)
	end
	-- Travel, Pickup and Sit need the server; the world layer handles them
	-- and reports back (arriveAt, collectItem).
	return false
end

function GameController:startScenarioAt(locationId: string): boolean
	if not self:_isExploring() then
		return false
	end
	local scenario = self:_findScenarioAt(locationId)
	if not scenario then
		return false
	end
	self._activeScenario = scenario
	self:_setPhase(Phase.Scenario)
	return true
end

-- Closes the scenario dialog without choosing; it can be reopened later.
function GameController:cancelScenario(): boolean
	if self._phase ~= Phase.Scenario then
		return false
	end
	self._activeScenario = nil
	self:_setPhase(Phase.Exploring)
	return true
end

function GameController:submitChoice(choiceId: string): boolean
	-- Phase guard: once a choice is accepted the phase becomes Feedback, so
	-- any further submissions for this scenario are rejected here.
	if self._phase ~= Phase.Scenario or not self._activeScenario then
		return false
	end
	local scenario = self._activeScenario
	local choice = Scenarios.getChoice(scenario, choiceId)
	if not choice then
		warn(`[GameController] Unknown choice "{choiceId}" for scenario "{scenario.id}".`)
		return false
	end

	local state = self._state
	local changes = self:_applyEffects(choice.effects, { kind = "scenario", id = scenario.id, title = scenario.title })
	state:setFlags(choice.setFlags)
	state:setFlags({ [`completed:{scenario.id}`] = true })
	if scenario.location then
		state:setFlags({ [`completedAt:{scenario.location}`] = true })
	end
	state:recordChoice({
		day = state.day,
		scenarioId = scenario.id,
		scenarioTitle = scenario.title,
		choiceId = choice.id,
		choiceText = choice.text,
		changes = changes,
	})

	self._activeScenario = nil
	self._lastResult = {
		kind = "scenario",
		title = scenario.title,
		heading = choice.text,
		feedback = choice.feedback,
		changes = changes,
	}
	self:_setPhase(Phase.Feedback)
	self:_stateChanged()
	return true
end

function GameController:performActivity(activityId: string): boolean
	if not self:_isExploring() then
		return false
	end
	local activity = Activities.get(activityId)
	if not activity or not self:_isActivityAvailable(activity) then
		return false
	end

	local state = self._state
	local resolved = self:_resolve(activity)
	state:incrementCounter(`activity:{activity.id}`)
	local changes = self:_applyEffects(resolved.effects, { kind = "activity", id = activity.id, title = resolved.title })
	state:setFlags(resolved.setFlags)
	state:recordEvent({
		kind = "activity",
		id = activity.id,
		title = resolved.title,
		summary = resolved.resultText,
	})

	if resolved.presentation == "toast" then
		-- Small moments: a notification, and the player keeps exploring.
		self.Notified:Fire({ title = resolved.title, message = resolved.feedback, changes = changes })
		self:_stateChanged()
		return true
	end

	self._lastResult = {
		kind = "activity",
		title = resolved.title,
		heading = resolved.resultText,
		feedback = resolved.feedback,
		changes = changes,
	}
	self:_setPhase(Phase.Feedback)
	self:_stateChanged()
	return true
end

-- Shows a short note about a world detail. Never changes meters.
function GameController:inspect(inspectableId: string): boolean
	local inspectable = Inspectables[inspectableId]
	if not self:_isExploring() or not inspectable then
		return false
	end
	self.Notified:Fire({ title = inspectable.title, message = inspectable.text })
	return true
end

---------------------------------------------------------------------------
-- Inventory (ownership and equip state; Tools themselves are created by
-- the server and reported back by the world layer)
---------------------------------------------------------------------------

function GameController:canCollect(itemId: string): boolean
	return self:getInteraction(InteractionType.Pickup, itemId).available
end

-- Called after the server has granted the item's Tool.
function GameController:collectItem(itemId: string): boolean
	local item = Items.get(itemId)
	if not self._state or not item or not self._state:addItem(itemId) then
		return false
	end
	self._state:recordEvent({ kind = "item", id = itemId, title = item.name, summary = `Brought the {string.lower(item.name)}` })
	self.Notified:Fire({ title = "Item collected", message = item.collectedMessage })
	self.InventoryChanged:Fire()
	self:_stateChanged()
	return true
end

-- Mirrors the Tool's equip state. Sets the "equipped:<id>" flag that data
-- (zone modifiers etc.) reacts to. No meter changes happen here.
function GameController:setItemEquipped(itemId: string, equipped: boolean): boolean
	local state = self._state
	if not state or not state:setEquipped(itemId, equipped) then
		return false
	end
	if equipped then
		state:setFlags({ [Items.equippedFlag(itemId)] = true })
	else
		state:clearFlag(Items.equippedFlag(itemId))
	end
	local item = Items.get(itemId)
	if equipped and item and item.equipMessage and state:incrementCounter(`equipped:{itemId}`) == 1 then
		self.Notified:Fire({ title = item.name, message = item.equipMessage })
	end
	self.InventoryChanged:Fire()
	self:_stateChanged()
	return true
end

function GameController:hasItem(itemId: string): boolean
	return self._state ~= nil and self._state:hasItem(itemId)
end

-- Definitions of the items currently equipped.
function GameController:getEquippedItems(): { any }
	local list = {}
	if self._state then
		for _, itemId in self._state:getEquipped() do
			local item = Items.get(itemId)
			if item then
				table.insert(list, item)
			end
		end
	end
	return list
end

-- The character respawned at the start area (e.g. after a reset): Tools
-- are re-created unequipped, so equip state is cleared. Meters persist.
function GameController:onRespawn(): boolean
	local state = self._state
	if not state then
		return false
	end
	for _, itemId in state:getEquipped() do
		state:setEquipped(itemId, false)
		state:clearFlag(Items.equippedFlag(itemId))
	end
	self._activeZones = {}
	self:_markArea(self._dayPlan.startArea)
	self.InventoryChanged:Fire()
	self:_stateChanged()
	return true
end

-- Leaves the feedback panel and returns to exploring.
function GameController:continue(): boolean
	if self._phase ~= Phase.Feedback then
		return false
	end
	self._lastResult = nil
	self:_setPhase(Phase.Exploring)
	return true
end

---------------------------------------------------------------------------
-- Zones (called by the world layer as the player moves)
---------------------------------------------------------------------------

-- The version of a zone that applies right now (character overrides and
-- modifiers such as headphones resolved). Used for visuals and movement.
function GameController:getResolvedZone(zoneId: string)
	local zone = Zones.get(zoneId)
	if not zone or not self._state then
		return zone
	end
	return self:_resolve(zone)
end

function GameController:enterZone(zoneId: string): boolean
	if not self._state or self._activeZones[zoneId] then
		return false
	end
	local zone = Zones.get(zoneId)
	if not zone then
		return false
	end
	self._activeZones[zoneId] = true

	-- Entry effects and the entry message happen once per day, and only
	-- while exploring (not while a dialog is open).
	local state = self._state
	if self._phase ~= Phase.Exploring or state:getCounter(`zoneVisit:{zoneId}`) > 0 then
		return true
	end
	state:incrementCounter(`zoneVisit:{zoneId}`)

	local resolved = self:_resolve(zone)
	state:recordEvent({ kind = "zone", id = zone.id, title = zone.title, summary = resolved.eventSummary })
	local changes = nil
	if resolved.entryEffects then
		changes = self:_applyEffects(resolved.entryEffects, { kind = "zone", id = zone.id, title = zone.title })
	end
	if resolved.enterMessage then
		self.Notified:Fire({ title = zone.title, message = resolved.enterMessage, changes = changes })
	end
	self:_stateChanged()
	return true
end

function GameController:exitZone(zoneId: string): boolean
	if not self._activeZones[zoneId] then
		return false
	end
	self._activeZones[zoneId] = nil
	return true
end

-- One step of a zone's ongoing effect. Capped at maxTicks per day.
function GameController:tickZone(zoneId: string): boolean
	if not self:_isExploring() or not self._activeZones[zoneId] then
		return false
	end
	local zone = Zones.get(zoneId)
	local state = self._state
	local maxTicks = zone.maxTicks or 1
	if not zone.effects or state:getCounter(`zoneTick:{zoneId}`) >= maxTicks then
		return false
	end

	local resolved = self:_resolve(zone)
	self:_applyEffects(resolved.effects, { kind = "zone", id = zone.id, title = zone.title })
	local ticks = state:incrementCounter(`zoneTick:{zoneId}`)
	if ticks >= maxTicks and resolved.capMessage then
		self.Notified:Fire({ title = zone.title, message = resolved.capMessage })
	end
	self:_stateChanged()
	return true
end

---------------------------------------------------------------------------
-- View data (read by the UI)
---------------------------------------------------------------------------

function GameController:getArea(): string?
	return if self._state then self._state.area else nil
end

function GameController:getMeters()
	return if self._state then self._state:getMeters() else nil
end

function GameController:getObjectiveText(): string?
	if not self._state or not self._dayPlan then
		return nil
	end
	return Objectives.getText(self._dayPlan, self._state)
end

-- Target of the objective indicator for the current area, as
-- "InteractionType:InteractionId", or nil.
function GameController:getObjectiveMarker(): string?
	if not self._state or not self._dayPlan then
		return nil
	end
	local current = Objectives.getCurrent(self._dayPlan, self._state)
	local marker = if current then current.marker else self._dayPlan.finalMarker
	if not marker then
		return nil
	end
	return marker[self._state.area] or marker.default
end

-- Plain data describing what the current screen should show. Content
-- tables (character, scenario) are frozen; meters and history are copies.
function GameController:getView()
	local phase = self._phase

	if phase == Phase.CharacterSelect then
		return {
			phase = phase,
			characters = Characters.getAll(),
		}
	end

	local state = self._state
	local view = {
		phase = phase,
		character = self._character,
		day = state.day,
		area = state.area,
		meters = state:getMeters(),
		objective = self:getObjectiveText(),
	}

	if phase == Phase.Scenario then
		view.scenario = self._activeScenario
	elseif phase == Phase.Feedback then
		view.result = self._lastResult
	elseif phase == Phase.Results then
		local startingMeters = state:getStartingMeters()
		view.startingMeters = startingMeters
		view.history = state:getHistory()
		view.events = state:getEvents()
		view.reflection = Reflection.build(self._character, startingMeters, view.meters)
	end

	return view
end

return GameController
