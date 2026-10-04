--[[
	Zones registry

	Zones are areas of the world that place demands on (or give relief to)
	the character just by being there: a crowded hallway, a quiet alcove.
	Effects are deliberately bounded: a one-time entry effect plus a small
	effect every `tickSeconds` while inside, up to `maxTicks` per day.

	Zone shape:
		id, title: string
		entryEffects: { [meterId]: number }?   once per day, on first entry
		effects: { [meterId]: number }?        each tick while inside
		tickSeconds: number                     default 2
		maxTicks: number                        per day, default 1
		walkSpeedMultiplier: number?            e.g. 0.65 in a crowd
		ambientSound: { soundId, volume }?      looping 3D sound at the zone
		enterMessage, capMessage: string?       supportive notifications
		eventSummary: string?                   line for the results screen
		ambience: {                             subtle client-side visuals
			saturation, contrast, brightness: number?,
			tint: Color3?,
		}?
		modifiers: { { when: Condition, ...overrides } }?
		                                        first matching modifier
		                                        replaces fields (e.g. headphones)
		byCharacter: { [characterId]: partial Zone }?
]]

local DataLoader = require(script.Parent.Parent.Util.DataLoader)

local function validate(zone: any, source: string): boolean
	local label = `Zone "{zone.id}" ({source})`
	if type(zone.title) ~= "string" then
		warn(`[Zones] {label} is missing "title"; skipped.`)
		return false
	end
	if zone.tickSeconds ~= nil and (type(zone.tickSeconds) ~= "number" or zone.tickSeconds <= 0) then
		warn(`[Zones] {label} "tickSeconds" must be a positive number; skipped.`)
		return false
	end
	local variants = { zone }
	for _, modifier in zone.modifiers or {} do
		table.insert(variants, modifier)
	end
	for _, override in zone.byCharacter or {} do
		table.insert(variants, override)
	end
	for _, variant in variants do
		if
			not DataLoader.validateEffects(variant.entryEffects, label)
			or not DataLoader.validateEffects(variant.effects, label)
		then
			return false
		end
	end
	return true
end

local byId = DataLoader.loadById(script, "Zones", validate)

local Zones = {}

Zones.DEFAULT_TICK_SECONDS = 2

function Zones.get(id: string)
	return byId[id]
end

return Zones
