--[[
	Scenarios registry

	Loads every scenario module placed next to this file. Each module returns
	a list of scenarios (by convention, one module per character). Adding
	scenarios means editing or adding data files only.

	Scenarios are placed in the world by `location`: the world has an
	interaction point with that location id (e.g. "bedroom_desk"), and the
	scenario shown there depends on which character is playing and which day
	it is. The same desk can host Alex's scenario today and Jordan's later.

	Scenario shape:
		id: string                  unique across all scenarios
		characterId: string         matches a character id
		day: number                 1, 2, ...
		order: number               sort order within the day/location
		location: string?           world interaction point id
		promptText: string?         interaction prompt label ("Check planner")
		speaker: string?            NPC id (Data/Npcs) who talks to the player
		introLines: { string | { text: string, reaction: string? } }?
		                            spoken (speech bubble) before the choices
		                            appear; a reaction ("nod", "wave",
		                            "point", "shrug") plays with that line
		leadInSeconds: number?      minimum time the intro plays for
		crowdReaction: "chat"?      nearby NPCs turn to each other and talk
		                            while the choices are open
		title, timeOfDay, situation, innerThoughts: string
		                            (timeOfDay: opening the scenario moves
		                            the clock to at least this time)
		condition: ((state) -> boolean)?
		                            optional; scenario is unavailable when it
		                            returns false (used for branching)
		sceneImage: string?         future artwork asset id
		choices: { Choice }         3–4 recommended

	Choice shape:
		id: string                  unique within the scenario
		text: string
		description: string?
		effects: { [meterId]: number }   deltas, applied then clamped 0–100
		feedback: string            educational, nonjudgmental
		setFlags: { [string]: any }?     optional; stored on the session so
		                                 later scenarios can react to it
		npcReaction: string?        the speaker's animation while the
		                            feedback is shown ("nod", "wave", ...)
		npcLine: string?            the speaker's reply once the feedback
		                            panel closes

	When a choice is made, the controller also sets the flags
	"completed:<scenarioId>" and "completedAt:<location>", which activities,
	objectives and later scenarios can depend on.
]]

local DataLoader = require(script.Parent.Parent.Util.DataLoader)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local REQUIRED_STRINGS = { "id", "characterId", "title", "timeOfDay", "situation", "innerThoughts" }
local OPTIONAL_STRINGS = { "location", "promptText" }
local MIN_CHOICES = 2
local MAX_CHOICES = 4

local function validateChoice(choice: any, label: string, seenIds: { [string]: boolean }): boolean
	if type(choice) ~= "table" then
		warn(`[Scenarios] {label} is not a table.`)
		return false
	end
	if type(choice.id) ~= "string" or seenIds[choice.id] then
		warn(`[Scenarios] {label} needs a unique string id.`)
		return false
	end
	seenIds[choice.id] = true
	if type(choice.text) ~= "string" or type(choice.feedback) ~= "string" then
		warn(`[Scenarios] {label} needs "text" and "feedback" strings.`)
		return false
	end
	if type(choice.effects) ~= "table" then
		warn(`[Scenarios] {label} has no effects table.`)
		return false
	end
	for _, field in { "npcReaction", "npcLine" } do
		if choice[field] ~= nil and type(choice[field]) ~= "string" then
			warn(`[Scenarios] {label} "{field}" must be a string.`)
			return false
		end
	end
	return DataLoader.validateEffects(choice.effects, label)
end

local function validateScenario(scenario: any, source: string): boolean
	if type(scenario) ~= "table" then
		warn(`[Scenarios] Non-table entry in {source}; skipped.`)
		return false
	end
	for _, field in REQUIRED_STRINGS do
		if type(scenario[field]) ~= "string" or scenario[field] == "" then
			warn(`[Scenarios] Scenario in {source} is missing "{field}"; skipped.`)
			return false
		end
	end
	for _, field in OPTIONAL_STRINGS do
		if scenario[field] ~= nil and type(scenario[field]) ~= "string" then
			warn(`[Scenarios] {scenario.id} "{field}" must be a string; skipped.`)
			return false
		end
	end
	if type(scenario.day) ~= "number" or type(scenario.order) ~= "number" then
		warn(`[Scenarios] {scenario.id} needs numeric "day" and "order"; skipped.`)
		return false
	end
	for index, line in scenario.introLines or {} do
		local text = if type(line) == "table" then line.text else line
		if type(text) ~= "string" then
			warn(`[Scenarios] {scenario.id} intro line #{index} needs text; skipped.`)
			return false
		end
	end
	if scenario.condition ~= nil and type(scenario.condition) ~= "function" then
		warn(`[Scenarios] {scenario.id} "condition" must be a function; skipped.`)
		return false
	end
	local choices = scenario.choices
	if type(choices) ~= "table" or #choices < MIN_CHOICES or #choices > MAX_CHOICES then
		warn(`[Scenarios] {scenario.id} must have {MIN_CHOICES}–{MAX_CHOICES} choices; skipped.`)
		return false
	end
	local seenIds = {}
	for index, choice in choices do
		if not validateChoice(choice, `{scenario.id} choice #{index}`, seenIds) then
			warn(`[Scenarios] {scenario.id} skipped because of an invalid choice.`)
			return false
		end
	end
	return true
end

local byId = {}
-- byCharacter[characterId][day] = { scenario, ... } sorted by order
local byCharacter = {}
-- byLocation["characterId|day|location"] = { scenario, ... } sorted by order
local byLocation = {}

local function locationKey(characterId: string, day: number, location: string): string
	return `{characterId}|{day}|{location}`
end

local function insertInto(map, key, scenario)
	map[key] = map[key] or {}
	table.insert(map[key], scenario)
end

DataLoader.forEachModule(script, function(list, source)
	if type(list) ~= "table" then
		warn(`[Scenarios] {source} must return a list of scenarios.`)
		return
	end
	for _, scenario in list do
		if not validateScenario(scenario, source) then
			continue
		end
		if byId[scenario.id] then
			warn(`[Scenarios] Duplicate scenario id "{scenario.id}"; skipped.`)
			continue
		end
		TableUtil.deepFreeze(scenario)
		byId[scenario.id] = scenario

		byCharacter[scenario.characterId] = byCharacter[scenario.characterId] or {}
		insertInto(byCharacter[scenario.characterId], scenario.day, scenario)
		if scenario.location then
			insertInto(byLocation, locationKey(scenario.characterId, scenario.day, scenario.location), scenario)
		end
	end
end)

local function byOrder(a, b)
	return a.order < b.order
end

for _, days in byCharacter do
	for _, list in days do
		table.sort(list, byOrder)
		table.freeze(list)
	end
end
for _, list in byLocation do
	table.sort(list, byOrder)
	table.freeze(list)
end

local EMPTY = table.freeze({})

local Scenarios = {}

function Scenarios.get(id: string)
	return byId[id]
end

-- Ordered, read-only list of a character's scenarios for one day.
function Scenarios.getForDay(characterId: string, day: number): { any }
	local days = byCharacter[characterId]
	return (days and days[day]) or EMPTY
end

-- Ordered, read-only list of a character's scenarios at one world location.
function Scenarios.getAtLocation(characterId: string, day: number, location: string): { any }
	return byLocation[locationKey(characterId, day, location)] or EMPTY
end

function Scenarios.getChoice(scenario: any, choiceId: string)
	for _, choice in scenario.choices do
		if choice.id == choiceId then
			return choice
		end
	end
	return nil
end

return Scenarios
