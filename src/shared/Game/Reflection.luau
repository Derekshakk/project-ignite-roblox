--[[
	Reflection

	Builds the supportive reflection text shown on the results screen from
	the session's starting and final meter values. Kept separate from the UI
	and controller so the final Project Ignite results page can replace or
	extend it without touching game flow.
]]

local Meters = require(script.Parent.Parent.Constants.Meters)

local Reflection = {}

function Reflection.build(character: any, startingMeters: Meters.MeterValues, finalMeters: Meters.MeterValues): string
	local name = character.name

	local largest, largestDelta = nil, 0
	for _, definition in Meters.List do
		local delta = (finalMeters[definition.id] or 0) - (startingMeters[definition.id] or 0)
		if math.abs(delta) > math.abs(largestDelta) then
			largest, largestDelta = definition, delta
		end
	end

	local lines = {}
	if largest then
		local direction = if largestDelta > 0 then "rose" else "dropped"
		table.insert(
			lines,
			`The biggest shift for {name} was in {largest.label}, which {direction} by {math.abs(largestDelta)}.`
		)
	else
		table.insert(lines, `{name}'s meters ended the day close to where they started.`)
	end

	table.insert(
		lines,
		"Every option came with tradeoffs. There's no single right answer — what matters is noticing "
			.. "how each choice affected energy, stress and capacity."
	)
	table.insert(lines, `What helped {name} protect their capacity? What might you try next time?`)

	return table.concat(lines, "\n\n")
end

return Reflection
