--[[
	GameState

	Holds everything about one play session: which character, which day,
	which area they are in, the in-game time (minutes since midnight, see
	Game/Clock), current meter values, the choices made so far,
	other notable moments (activities, environments), usage counters, the
	inventory (owned and equipped items), and story flags that later
	scenarios can react to. It contains no UI code and
	no game-flow decisions; GameController drives it.

	All meter writes go through Meters.clamp, so values can never leave 0–100.
	Getters return copies so callers cannot change the live state by accident.
	A fresh GameState is created for every new run, which is how restart
	returns to a clean initial state.
]]

local Meters = require(script.Parent.Parent.Constants.Meters)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type MeterChange = {
	id: string,
	before: number,
	after: number,
	delta: number, -- actual change after clamping
}

export type EventEntry = {
	kind: string, -- "activity" | "zone"
	id: string,
	title: string,
	summary: string?,
}

export type HistoryEntry = {
	day: number,
	scenarioId: string,
	scenarioTitle: string,
	choiceId: string,
	choiceText: string,
	changes: { MeterChange },
}

local GameState = {}
GameState.__index = GameState

function GameState.new(character: any)
	assert(type(character) == "table" and type(character.id) == "string", "GameState.new needs a character")

	local startingMeters = Meters.createValues(character.startingMeters)
	local self = setmetatable({
		characterId = character.id,
		day = 1,
		area = nil :: string?,
		_time = nil :: number?,
		_startingMeters = startingMeters,
		_meters = table.clone(startingMeters),
		_history = {} :: { HistoryEntry },
		_flags = {} :: { [string]: any },
		_counters = {} :: { [string]: number },
		_events = {} :: { EventEntry },
		_items = {} :: { [string]: boolean }, -- owned
		_equipped = {} :: { [string]: boolean },
	}, GameState)
	return self
end

function GameState:getMeter(id: string): number?
	return self._meters[id]
end

function GameState:getMeters(): Meters.MeterValues
	return table.clone(self._meters)
end

function GameState:getStartingMeters(): Meters.MeterValues
	return table.clone(self._startingMeters)
end

--[[
	Applies meter deltas, clamping each result. Returns one MeterChange per
	meter (in display order) so the UI can show exactly what moved, including
	cases where clamping limited the change.
]]
function GameState:applyEffects(effects: { [string]: number }?): { MeterChange }
	effects = effects or {}
	local changes = {}
	for _, definition in Meters.List do
		local before = self._meters[definition.id]
		local delta = (effects :: any)[definition.id]
		-- Non-numeric or NaN deltas leave the meter unchanged.
		local isValidDelta = type(delta) == "number" and delta == delta
		local after = if isValidDelta then Meters.clamp(before + delta) else before
		self._meters[definition.id] = after
		table.insert(changes, {
			id = definition.id,
			before = before,
			after = after,
			delta = after - before,
		})
	end
	return changes
end

function GameState:recordChoice(entry: HistoryEntry)
	table.insert(self._history, TableUtil.deepCopy(entry))
end

function GameState:getHistory(): { HistoryEntry }
	return TableUtil.deepCopy(self._history)
end

function GameState:hasChosen(scenarioId: string, choiceId: string?): boolean
	for _, entry in self._history do
		if entry.scenarioId == scenarioId and (choiceId == nil or entry.choiceId == choiceId) then
			return true
		end
	end
	return false
end

function GameState:recordEvent(entry: EventEntry)
	table.insert(self._events, TableUtil.deepCopy(entry))
end

function GameState:getEvents(): { EventEntry }
	return TableUtil.deepCopy(self._events)
end

-- Counters track how often something happened this session (activity uses,
-- zone ticks, ...). They are how per-day limits are enforced.
function GameState:getCounter(key: string): number
	return self._counters[key] or 0
end

function GameState:incrementCounter(key: string): number
	local value = (self._counters[key] or 0) + 1
	self._counters[key] = value
	return value
end

-- Inventory ---------------------------------------------------------------

function GameState:addItem(itemId: string): boolean
	if self._items[itemId] then
		return false
	end
	self._items[itemId] = true
	return true
end

function GameState:hasItem(itemId: string): boolean
	return self._items[itemId] == true
end

function GameState:getItems(): { string }
	local list = {}
	for itemId in self._items do
		table.insert(list, itemId)
	end
	table.sort(list)
	return list
end

-- Equipping is only possible for owned items. Returns true if it changed.
function GameState:setEquipped(itemId: string, equipped: boolean): boolean
	if equipped and not self._items[itemId] then
		return false
	end
	local current = self._equipped[itemId] == true
	if current == equipped then
		return false
	end
	self._equipped[itemId] = if equipped then true else nil
	return true
end

function GameState:isEquipped(itemId: string): boolean
	return self._equipped[itemId] == true
end

function GameState:getEquipped(): { string }
	local list = {}
	for itemId in self._equipped do
		table.insert(list, itemId)
	end
	table.sort(list)
	return list
end

-- Time ----------------------------------------------------------------------

function GameState:getTime(): number?
	return self._time
end

-- Time only moves forward within a day. Returns true if it changed.
function GameState:setTime(minutes: number): boolean
	if type(minutes) ~= "number" or minutes ~= minutes then
		return false
	end
	if self._time ~= nil and minutes <= self._time then
		return false
	end
	self._time = minutes
	return true
end

-- Flags ---------------------------------------------------------------------

function GameState:setFlags(flags: { [string]: any }?)
	if flags then
		for key, value in flags do
			self._flags[key] = value
		end
	end
end

function GameState:clearFlag(key: string)
	self._flags[key] = nil
end

function GameState:getFlag(key: string): any
	return self._flags[key]
end

return GameState
