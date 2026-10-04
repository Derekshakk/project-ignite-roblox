--[[
	School activities.

	PLACEHOLDER CONTENT: effects and wording are first-pass values for the
	prototype. Recovery should restore some capacity, never fully reset it.
]]

return {
	{
		id = "locker_books",
		title = "Your locker",
		objectText = "Your locker",
		actionText = "Swap books",
		holdDuration = 0.4,
		maxUses = 1,
		presentation = "toast",
		effects = { energy = 2 },
		tags = { "organisation" },
		resultText = "Alex swapped the heavy textbooks for just what's needed this morning.",
		feedback = "Alex left the heavy textbooks behind. One less thing to carry through the day.",
	},
	{
		id = "calm_corner_rest",
		title = "The calm corner",
		objectText = "Calm corner",
		actionText = "Sit and listen to music",
		holdDuration = 2,
		maxUses = 1,
		requires = { flag = "completedAt:classroom_seat" },
		effects = {
			energy = 8,
			stress = -10,
			focus = 6,
			burnout = -4,
			lifeSatisfaction = 3,
		},
		setFlags = { recoveredAfterClass = true },
		tags = { "recovery" },
		resultText = "Alex spent a few quiet minutes in the calm corner with some music.",
		feedback = "A short, intentional break gave Alex some capacity back: a little more energy and a "
			.. "little less stress. It didn't erase the morning. Recovery builds up over time, and small "
			.. "breaks tend to help most when they happen before capacity runs very low.",
	},
}
