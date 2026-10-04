--[[
	Meters

	Single source of truth for the status meters tracked during a session.
	Everything that touches meter values (state, data validation, UI) reads
	from here, so adding or renaming a meter only happens in one place.

	`strainWhenHigh` describes how a meter reads, not whether a value is "good"
	or "bad": for burnout and stress a higher number means more strain, for the
	others a higher number means more available capacity. The UI uses it to
	pick neutral colors and wording for changes.

	`primary` meters are always visible in the gameplay HUD.
]]

export type MeterId = string

export type MeterDefinition = {
	id: MeterId,
	label: string,
	description: string,
	strainWhenHigh: boolean,
	primary: boolean, -- shown in the compact HUD; others sit in its expandable section
}

export type MeterValues = { [MeterId]: number }

local Meters = {}

Meters.MIN = 0
Meters.MAX = 100
Meters.DEFAULT_VALUE = 50

-- Display order is the order of this list.
Meters.List = table.freeze({
	table.freeze({
		id = "burnout",
		label = "Burnout",
		description = "How close the character is to running out of capacity.",
		strainWhenHigh = true,
		primary = true,
	}),
	table.freeze({
		id = "energy",
		label = "Energy",
		description = "Physical and mental energy available right now.",
		strainWhenHigh = false,
		primary = true,
	}),
	table.freeze({
		id = "focus",
		label = "Focus",
		description = "Ability to direct attention where the character wants it.",
		strainWhenHigh = false,
		primary = true,
	}),
	table.freeze({
		id = "stress",
		label = "Stress",
		description = "Pressure the character is carrying in this moment.",
		strainWhenHigh = true,
		primary = true,
	}),
	table.freeze({
		id = "motivation",
		label = "Motivation",
		description = "Drive to start and keep going with tasks.",
		strainWhenHigh = false,
		primary = true,
	}),
	table.freeze({
		id = "lifeSatisfaction",
		label = "Life Satisfaction",
		description = "How the character feels about their day and life overall.",
		strainWhenHigh = false,
		primary = false,
	}),
	table.freeze({
		id = "selfAdvocacy",
		label = "Self-Advocacy",
		description = "Confidence and practice in asking for what they need.",
		strainWhenHigh = false,
		primary = false,
	}),
} :: { MeterDefinition })

local byId: { [MeterId]: MeterDefinition } = {}
for _, definition in Meters.List do
	byId[definition.id] = definition
end

function Meters.get(id: MeterId): MeterDefinition?
	return byId[id]
end

function Meters.isValidId(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

-- Clamps any input to a whole number in [MIN, MAX]. Non-numbers and NaN fall
-- back to MIN so a bad data entry can never push a meter out of range.
function Meters.clamp(value: any): number
	if type(value) ~= "number" or value ~= value then
		return Meters.MIN
	end
	return math.clamp(math.round(value), Meters.MIN, Meters.MAX)
end

-- Builds a complete, clamped set of meter values. Missing meters get the
-- default value, unknown keys are ignored.
function Meters.createValues(source: MeterValues?): MeterValues
	local values = {}
	for _, definition in Meters.List do
		local raw = if source then source[definition.id] else nil
		values[definition.id] = Meters.clamp(if raw == nil then Meters.DEFAULT_VALUE else raw)
	end
	return values
end

return Meters
