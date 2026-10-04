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
		requires: Condition?             see Game/Conditions
		effects: { [meterId]: number }
		resultText: string               what the character did
		feedback: string                 educational, nonjudgmental
		setFlags: { [string]: any }?
		tags: { string }?                e.g. "recovery", "accommodation"
		presentation: "dialog" | "toast"?
		                                 dialog (default) opens the feedback
		                                 panel; toast shows a short notice
		byCharacter: { [characterId]: partial Activity }?
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
	for characterId, override in activity.byCharacter or {} do
		if not DataLoader.validateEffects(override.effects, `{label} byCharacter.{characterId}`) then
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
