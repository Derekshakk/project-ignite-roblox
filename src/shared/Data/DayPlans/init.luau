--[[
	DayPlans registry

	A day plan describes one character's day: where it starts and the
	objectives that guide the player through the world. Objectives are
	completed by game state (see Game/Conditions), not by scripts in the
	world, so the same rooms can host different days and characters.

	DayPlan shape:
		characterId: string
		day: number
		startArea: string              area id (e.g. "bedroom")
		startDestination: string       destination id the player is moved to
		startTime: string?             in-game time the day starts ("7:05 AM")
		objectives: { { id: string, text: string, completeWhen: Condition } }
		finalObjectiveText: string     shown once every objective is complete;
		                               the day can then be ended
		Objectives (and `finalMarker`) may have a `marker`: per-area targets
		for the objective indicator, as "InteractionType:InteractionId",
		e.g. { default = "Sit:classroom_player_chair", bedroom = "Door:…" }.
		A target can also be a list followed in order (a route), and
		"Waypoint:<id>" names a route point placed in the world.
]]

local DataLoader = require(script.Parent.Parent.Util.DataLoader)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local plans = {}

local function key(characterId: string, day: number): string
	return `{characterId}|{day}`
end

local function validate(plan: any, source: string): boolean
	if type(plan) ~= "table" or type(plan.characterId) ~= "string" or type(plan.day) ~= "number" then
		warn(`[DayPlans] Entry in {source} needs "characterId" and "day"; skipped.`)
		return false
	end
	for _, field in { "startArea", "startDestination", "finalObjectiveText" } do
		if type(plan[field]) ~= "string" then
			warn(`[DayPlans] {plan.characterId} day {plan.day} is missing "{field}"; skipped.`)
			return false
		end
	end
	if plan.startTime ~= nil and type(plan.startTime) ~= "string" then
		warn(`[DayPlans] {plan.characterId} day {plan.day} "startTime" must be text like "7:05 AM"; skipped.`)
		return false
	end
	if type(plan.objectives) ~= "table" then
		warn(`[DayPlans] {plan.characterId} day {plan.day} needs an objectives list; skipped.`)
		return false
	end
	for index, objective in plan.objectives do
		if type(objective.text) ~= "string" or type(objective.completeWhen) ~= "table" then
			warn(`[DayPlans] {plan.characterId} day {plan.day} objective #{index} needs "text" and "completeWhen".`)
			return false
		end
	end
	return true
end

DataLoader.forEachModule(script, function(list, source)
	if type(list) ~= "table" then
		warn(`[DayPlans] {source} must return a list.`)
		return
	end
	for _, plan in list do
		if validate(plan, source) then
			local planKey = key(plan.characterId, plan.day)
			if plans[planKey] then
				warn(`[DayPlans] Duplicate plan for {planKey}; skipped.`)
			else
				plans[planKey] = TableUtil.deepFreeze(plan)
			end
		end
	end
end)

local DayPlans = {}

function DayPlans.get(characterId: string, day: number)
	return plans[key(characterId, day)]
end

return DayPlans
