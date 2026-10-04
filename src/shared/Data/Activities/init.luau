--[[
	Activities registry

	Activities are short, physical interactions in the world (grabbing
	headphones, resting in a calm corner, ...). They are not tied to a
	character: the same object works for anyone, and `byCharacter` can adjust
	effects or text for a specific character.

	Activity shape:
		id: string
		title: string                    shown on the feedback panel
		objectText, actionText: string   ProximityPrompt labels
		holdDuration: number?            seconds to hold the prompt (0 = tap)
		maxUses: number?                 per day, default 1
		minutes: number?                 in-game time it takes
		guided: GuidedTask?              done as a short physical task
		                                 (client GuidedTask) instead of
		                                 at once; see below
		npcReaction: { npc, reaction?, line? }?
		                                 an NPC reacts when it's done
		requires: Condition?             see Game/Conditions
		effects: { [meterId]: number }
		resultText: string               what the character did
		feedback: string                 educational, nonjudgmental
		setFlags: { [string]: any }?
		tags: { string }?                e.g. "recovery", "accommodation"
		presentation: "dialog" | "toast"?
		                                 dialog (default) opens the feedback
		                                 panel; toast shows a short notice
		group: string?, groupLimit: number?
		                                 activities in a group share a limit
		                                 ("pack 2 of these 3"); once reached,
		                                 the rest become unavailable
		groupTitle, groupFullMessage: string?
		                                 notice shown when the group is full
		byCharacter: { [characterId]: partial Activity }?
		modifiers: { { when: Condition, ...overrides } }?
		                                 first matching modifier replaces
		                                 fields (see Game/Rules)

	GuidedTask shape:
		title: string
		cycles: number                   how many times the steps repeat
		steps: { {
			input: "hold" | "release" | "still",
			seconds: number,
			text: string,                shown while the step progresses
			idle: string?,               shown while waiting for the input
			ready: string?,              ("release") shown when it can start
		} }
	There is no way to fail a guided task: letting go early or moving just
	lets the progress settle back.
]]

local DataLoader = require(script.Parent.Parent.Util.DataLoader)

local function validate(activity: any, source: string): boolean
	local label = `Activity "{activity.id}" ({source})`
	for _, field in { "title", "objectText", "actionText", "resultText", "feedback" } do
		if type(activity[field]) ~= "string" then
			warn(`[Activities] {label} is missing "{field}"; skipped.`)
			return false
		end
	end
	if not DataLoader.validateEffects(activity.effects, label) then
		return false
	end
	local guided = activity.guided
	if guided ~= nil then
		if type(guided.steps) ~= "table" or #guided.steps == 0 or type(guided.cycles) ~= "number" then
			warn(`[Activities] {label} "guided" needs steps and cycles; skipped.`)
			return false
		end
		for index, step in guided.steps do
			if not table.find({ "hold", "release", "still" }, step.input) or type(step.seconds) ~= "number" then
				warn(`[Activities] {label} guided step #{index} needs an input and seconds; skipped.`)
				return false
			end
		end
	end
	for characterId, override in activity.byCharacter or {} do
		if not DataLoader.validateEffects(override.effects, `{label} byCharacter.{characterId}`) then
			return false
		end
	end
	for index, modifier in activity.modifiers or {} do
		if not DataLoader.validateEffects(modifier.effects, `{label} modifier #{index}`) then
			return false
		end
	end
	return true
end

local byId = DataLoader.loadById(script, "Activities", validate)

local Activities = {}

function Activities.get(id: string)
	return byId[id]
end

return Activities
