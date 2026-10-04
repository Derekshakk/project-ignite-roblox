--[[
	School activities.

	PLACEHOLDER CONTENT: effects and wording are first-pass values for the
	prototype. Recovery should restore some capacity, never fully reset it.
	Most things also take a little time (`minutes`), which is part of the
	tradeoff: the clock keeps moving toward the bell.
]]

-- Guided tasks (client GuidedTask): short physical actions, never failable.
local BREATHING = {
	title = "A few slow breaths",
	cycles = 3,
	steps = {
		{ input = "hold", seconds = 3, text = "Breathe in slowly…", idle = "Hold E (or the circle) to breathe in" },
		{ input = "release", seconds = 3.5, text = "Breathe out slowly…", ready = "Now let go, and breathe out" },
	},
}

local STRETCH = {
	title = "A quick stretch",
	cycles = 3,
	steps = {
		{ input = "hold", seconds = 2, text = "Reach up and stretch…", idle = "Hold E (or the circle) to stretch" },
		{ input = "release", seconds = 1.5, text = "And relax…", ready = "Now let go and relax" },
	},
}

local WAIT_FOR_CROWD = {
	title = "Waiting it out",
	cycles = 1,
	steps = {
		{
			input = "still",
			seconds = 7,
			text = "Leaning on the wall while the rush goes by…",
			idle = "Stay still for a moment to let the crowd pass",
		},
	},
}

return {
	{
		id = "locker_books",
		title = "Your locker",
		objectText = "Your locker",
		actionText = "Swap books",
		holdDuration = 0.4,
		maxUses = 1,
		minutes = 1,
		presentation = "toast",
		effects = { energy = 2 },
		tags = { "organisation" },
		resultText = "Alex swapped the heavy textbooks for just what's needed this morning.",
		feedback = "Alex left the heavy textbooks behind. One less thing to carry through the day.",
		modifiers = {
			{
				-- Packed the science textbook at home: more to drop off.
				when = { flag = "packed:textbook" },
				effects = { energy = 3 },
				resultText = "Alex dropped the extra textbook into the locker too.",
				feedback = "Alex left the textbooks behind, including the one packed this morning. "
					.. "The bag feels a lot lighter now.",
			},
		},
	},
	{
		id = "calm_corner_rest",
		title = "The calm corner",
		objectText = "Calm corner",
		actionText = "Sit and listen to music",
		holdDuration = 2,
		maxUses = 1,
		requires = { flag = "completedAt:classroom_seat" },
		minutes = 5,
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
		modifiers = {
			{
				-- Packed the sketchbook: time for a special interest.
				when = { flag = "packed:sketchbook" },
				actionText = "Sketch and listen to music",
				effects = {
					energy = 8,
					stress = -10,
					focus = 8,
					burnout = -4,
					lifeSatisfaction = 6,
				},
				resultText = "Alex spent a few quiet minutes in the calm corner sketching, with music on.",
				feedback = "Sketching gave Alex's mind somewhere good to rest. Time with a special interest "
					.. "can be restorative in a way plain rest isn't for everyone. It still didn't erase the "
					.. "morning; recovery builds up over time.",
			},
		},
	},
	{
		-- Seated on the alcove bench: a short guided breathing task.
		id = "alcove_breathe",
		title = "A few slow breaths",
		objectText = "Bench",
		actionText = "Sit and breathe",
		maxUses = 1,
		minutes = 2,
		guided = BREATHING,
		presentation = "toast",
		effects = { stress = -4, focus = 3, energy = 1 },
		tags = { "recovery" },
		resultText = "Alex sat in the quiet space and took a few slow breaths.",
		feedback = "A few slow breaths in a quiet spot helped Alex's body settle a little. It's a small "
			.. "reset, not a full recharge, and it worked partly because the space was quiet.",
	},

	-- Packing the bag (bedroom, before leaving): room for two of these.
	-- What's packed changes small moments later in the day.
	{
		id = "pack_sketchbook",
		title = "Packed: sketchbook",
		objectText = "Sketchbook",
		actionText = "Pack in bag",
		holdDuration = 0.3,
		presentation = "toast",
		group = "pack",
		groupLimit = 2,
		groupTitle = "Backpack",
		groupFullMessage = "The bag is full. Everything else stays home today.",
		requires = { notFlag = "visited:hallway" },
		minutes = 1,
		effects = {},
		setFlags = { ["packed:sketchbook"] = true },
		tags = { "prioritising" },
		resultText = "Packed the sketchbook",
		feedback = "Alex packed the sketchbook. Drawing is one of the things that helps Alex recharge.",
	},
	{
		id = "pack_textbook",
		title = "Packed: science textbook",
		objectText = "Science textbook",
		actionText = "Pack in bag",
		holdDuration = 0.3,
		presentation = "toast",
		group = "pack",
		groupLimit = 2,
		groupTitle = "Backpack",
		groupFullMessage = "The bag is full. Everything else stays home today.",
		requires = { notFlag = "visited:hallway" },
		minutes = 1,
		effects = { energy = -1 },
		setFlags = { ["packed:textbook"] = true },
		tags = { "prioritising" },
		resultText = "Packed the science textbook",
		feedback = "Alex packed the heavy science textbook, just in case. The bag is noticeably heavier.",
	},
	{
		id = "pack_water",
		title = "Packed: water bottle",
		objectText = "Water bottle",
		actionText = "Pack in bag",
		holdDuration = 0.3,
		presentation = "toast",
		group = "pack",
		groupLimit = 2,
		groupTitle = "Backpack",
		groupFullMessage = "The bag is full. Everything else stays home today.",
		requires = { notFlag = "visited:hallway" },
		minutes = 1,
		effects = {},
		setFlags = { ["packed:water"] = true },
		tags = { "prioritising" },
		resultText = "Packed a water bottle",
		feedback = "Alex packed a water bottle. Small things like water are easy to forget on a rushed morning.",
	},

	-- Bedroom: a short movement break before leaving.
	{
		id = "morning_stretch",
		title = "A quick stretch",
		objectText = "Stretching mat",
		actionText = "Stretch",
		maxUses = 1,
		minutes = 3,
		guided = STRETCH,
		presentation = "toast",
		requires = { notFlag = "visited:hallway" },
		effects = { energy = 3, stress = -3, focus = 2 },
		tags = { "recovery", "movement" },
		resultText = "Stretched for a few minutes before leaving",
		feedback = "Moving for a few minutes helped Alex feel more awake and a little less tense. "
			.. "It also used a few minutes of a tight morning.",
	},

	-- Hallway: the water fountain.
	{
		id = "drink_water",
		title = "Water break",
		objectText = "Water fountain",
		actionText = "Get a drink",
		holdDuration = 1.2,
		maxUses = 1,
		minutes = 1,
		presentation = "toast",
		effects = { energy = 2, focus = 1 },
		tags = { "recovery" },
		resultText = "Stopped for a drink of water",
		feedback = "A drink of water and a few seconds standing still. Small, but it helps.",
		modifiers = {
			{
				when = { flag = "packed:water" },
				actionText = "Refill your bottle",
				effects = { energy = 3, focus = 1 },
				resultText = "Refilled the water bottle",
				feedback = "Alex topped up the bottle packed this morning. Water on hand for the rest of the day.",
			},
		},
	},

	-- Hallway: wait by the wall for the rush to pass (costs time; the
	-- crowded stretch is easier afterwards).
	{
		id = "wait_for_crowd",
		title = "Waited for the rush to pass",
		objectText = "Quiet spot by the wall",
		actionText = "Wait for the crowd",
		maxUses = 1,
		minutes = 4,
		guided = WAIT_FOR_CROWD,
		presentation = "toast",
		effects = { stress = -2 },
		setFlags = { crowdThinned = true },
		tags = { "planning", "environment" },
		resultText = "Waited by the wall until the hallway cleared a little",
		feedback = "Alex waited for the busiest moment to pass. The hallway is calmer now, and it cost a few "
			.. "minutes of the morning.",
	},

	-- Classroom: a question, written down and left on the teacher's desk.
	{
		id = "write_question",
		title = "A question on a sticky note",
		objectText = "Your notebook",
		actionText = "Write down a question",
		holdDuration = 1,
		maxUses = 1,
		minutes = 1,
		presentation = "toast",
		requires = { flag = "completedAt:classroom_seat" },
		effects = {},
		setFlags = { carryingNote = true },
		tags = { "self-advocacy" },
		resultText = "Wrote down a question about the project",
		feedback = "Alex wrote a question about the project on a sticky note. Now to get it to Ms. Rivera.",
	},
	{
		id = "leave_note",
		title = "Left a question for Ms. Rivera",
		objectText = "Question tray",
		actionText = "Leave your note",
		holdDuration = 0.5,
		maxUses = 1,
		presentation = "toast",
		requires = { flag = "carryingNote" },
		effects = { selfAdvocacy = 5, stress = -2, energy = -1 },
		setFlags = { carryingNote = false, noteLeft = true },
		npcReaction = {
			npc = "teacher",
			reaction = "nod",
			line = "Thanks, Alex. I'll get back to you before lunch.",
		},
		tags = { "self-advocacy" },
		resultText = "Left a written question on the teacher's desk",
		feedback = "Asking in writing let Alex ask without having to speak up in front of the class. "
			.. "It still took a bit of energy to walk up to the desk.",
	},
}
