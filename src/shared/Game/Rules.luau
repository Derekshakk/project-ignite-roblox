--[[
	Rules

	Resolves data entries (activities, zones) into the version that applies
	right now: first character-specific overrides (`byCharacter`), then the
	first `modifiers` entry whose `when` condition passes. This keeps
	character- and state-dependent variations in data instead of code.
]]

local Conditions = require(script.Parent.Conditions)

local Rules = {}

local function merge(base: any, override: any)
	local merged = table.clone(base)
	for key, value in override do
		merged[key] = value
	end
	return merged
end

function Rules.resolve(entry: any, characterId: string, state: any)
	local resolved = entry
	local characterOverride = entry.byCharacter and entry.byCharacter[characterId]
	if characterOverride then
		resolved = merge(resolved, characterOverride)
	end
	if resolved.modifiers then
		for _, modifier in resolved.modifiers do
			if Conditions.evaluate(modifier.when, state) then
				resolved = merge(resolved, modifier)
				break
			end
		end
	end
	return resolved
end

return Rules
