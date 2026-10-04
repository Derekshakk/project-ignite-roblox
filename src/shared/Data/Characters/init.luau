--[[
	Characters registry

	Loads every character module placed next to this file (Alex.luau,
	Jordan.luau, ...). Adding a character means adding one data file — no
	changes here or in the UI are needed.

	Character shape:
		id: string                         unique, lowercase (e.g. "alex")
		sortOrder: number                  order on the selection screen
		name, pronouns, shortDescription: string
		age: number
		neurodivergentExperiences: { string }
		strengths, burnoutTriggers, recoveryStrategies: { string }
		startingMeters: { [meterId]: number }   0–100, missing → default
		portraitImage: string?             future asset id
		accentColor: Color3?
]]

local Meters = require(script.Parent.Parent.Constants.Meters)
local DataLoader = require(script.Parent.Parent.Util.DataLoader)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local REQUIRED_STRINGS = { "id", "name", "pronouns", "shortDescription" }
local REQUIRED_LISTS = { "neurodivergentExperiences", "strengths", "burnoutTriggers", "recoveryStrategies" }

local function validate(character: any, source: string): boolean
	if type(character) ~= "table" then
		warn(`[Characters] {source} did not return a table; skipped.`)
		return false
	end
	for _, field in REQUIRED_STRINGS do
		if type(character[field]) ~= "string" or character[field] == "" then
			warn(`[Characters] {source} is missing string field "{field}"; skipped.`)
			return false
		end
	end
	for _, field in REQUIRED_LISTS do
		if type(character[field]) ~= "table" then
			warn(`[Characters] {source} is missing list field "{field}"; using an empty list.`)
			character[field] = {}
		end
	end
	if type(character.startingMeters) ~= "table" then
		character.startingMeters = {}
	end
	for meterId in character.startingMeters do
		if not Meters.isValidId(meterId) then
			warn(`[Characters] {source} has unknown starting meter "{meterId}"; it will be ignored.`)
		end
	end
	-- Normalise so every meter has a clamped starting value.
	character.startingMeters = Meters.createValues(character.startingMeters)
	character.sortOrder = character.sortOrder or math.huge
	return true
end

local byId = {}
local ordered = {}

DataLoader.forEachModule(script, function(loaded, source)
	local character = if type(loaded) == "table" then table.clone(loaded) else loaded
	if not validate(character, source) then
		return
	end
	if byId[character.id] then
		warn(`[Characters] Duplicate character id "{character.id}" in {source}; skipped.`)
		return
	end
	TableUtil.deepFreeze(character)
	byId[character.id] = character
	table.insert(ordered, character)
end)

table.sort(ordered, function(a, b)
	if a.sortOrder == b.sortOrder then
		return a.name < b.name
	end
	return a.sortOrder < b.sortOrder
end)
table.freeze(ordered)

local Characters = {}

function Characters.get(id: string)
	return byId[id]
end

-- Returns every character in display order. The list is read-only.
function Characters.getAll()
	return ordered
end

return Characters
