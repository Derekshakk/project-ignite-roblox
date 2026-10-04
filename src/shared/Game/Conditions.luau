--[[
	Conditions

	Small declarative checks against GameState, used by data files so content
	writers can express "after the group project", "while wearing
	headphones" or "before 8:10 AM" without writing code.

	Condition shape (every key present must pass; nil always passes):
		scenario: string?   a choice has been made in this scenario
		flag: string?       this flag is set (truthy)
		flags: { string }?  all of these flags are set
		notFlag: string?    this flag is not set
		before: string?     the in-game time is earlier than this ("8:10 AM")
		after: string?      the in-game time is this or later
]]

local Clock = require(script.Parent.Clock)

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
	if condition.flags ~= nil then
		for _, flag in condition.flags do
			if not state:getFlag(flag) then
				return false
			end
		end
	end
	if condition.notFlag ~= nil and state:getFlag(condition.notFlag) then
		return false
	end
	if condition.before ~= nil or condition.after ~= nil then
		local now = state:getTime()
		if now == nil then
			return false
		end
		local before = Clock.parse(condition.before)
		local after = Clock.parse(condition.after)
		if before and now >= before then
			return false
		end
		if after and now < after then
			return false
		end
	end
	return true
end

return Conditions
