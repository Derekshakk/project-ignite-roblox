--[[
	Conditions

	Small declarative checks against GameState, used by data files so content
	writers can express "after the group project" or "while wearing
	headphones" without writing code.

	Condition shape (every key present must pass; nil always passes):
		scenario: string?   a choice has been made in this scenario
		flag: string?       this flag is set (truthy)
		notFlag: string?    this flag is not set
]]

local Conditions = {}

function Conditions.evaluate(condition: any, state: any): boolean
	if condition == nil then
		return true
	end
	if condition.scenario ~= nil and not state:hasChosen(condition.scenario) then
		return false
	end
	if condition.flag ~= nil and not state:getFlag(condition.flag) then
		return false
	end
	if condition.notFlag ~= nil and state:getFlag(condition.notFlag) then
		return false
	end
	return true
end

return Conditions
