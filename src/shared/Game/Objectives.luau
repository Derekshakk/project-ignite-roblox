--[[
	Objectives

	Reads a DayPlan against GameState to work out what the player should do
	next. Objectives are listed in order; the current one is the first that
	is not yet complete.
]]

local Conditions = require(script.Parent.Conditions)

local Objectives = {}

function Objectives.getCurrent(plan: any, state: any)
	for _, objective in plan.objectives do
		if not Conditions.evaluate(objective.completeWhen, state) then
			return objective
		end
	end
	return nil
end

function Objectives.isDayComplete(plan: any, state: any): boolean
	return Objectives.getCurrent(plan, state) == nil
end

-- The text the player should see right now.
function Objectives.getText(plan: any, state: any): string
	local current = Objectives.getCurrent(plan, state)
	return if current then current.text else plan.finalObjectiveText
end

return Objectives
