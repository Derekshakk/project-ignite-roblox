--[[
	Alex — scenarios.

	PLACEHOLDER CONTENT: replace or extend with the final Project Ignite
	writing.
	See Scenarios/init.luau for the full scenario shape.

	To add more scenarios for Alex, append tables to this list. `location`
	must match an interaction point placed in the world (see the area
	builders in ServerScriptService.Server.World.Areas).
]]

return {
	{
		id = "alex_d1_morning_planner",
		characterId = "alex",
		day = 1,
		order = 1,
		location = "bedroom_desk",
		promptText = "Check planner",

		title = "The Morning Plan",
		timeOfDay = "7:10 AM",
		situation = "Alex's planner is open on the desk. Today there's a quiz in second period, a reading "
			.. "assignment due, and a note scribbled in the margin: \"permission slip??\" "
			.. "The bus leaves in twenty-five minutes.",
		innerThoughts = "Okay. That's a lot of things. Where do I even start?",

		choices = {
			{
				id = "checklist",
				text = "Make a quick checklist",
				description = "Write the three things down in order before leaving.",
				effects = {
					focus = 8,
					stress = -5,
					energy = -3,
					motivation = 3,
				},
				feedback = "Writing things down moved some of the load out of Alex's head and onto paper. "
					.. "It took a few minutes and a little energy, but having a clear order made the "
					.. "morning feel more manageable. External tools like lists can support working memory "
					.. "on busy days.",
			},
			{
				id = "text_friend",
				text = "Text a friend about the permission slip",
				description = "Ask someone who might know instead of guessing.",
				effects = {
					selfAdvocacy = 6,
					stress = -4,
					energy = -2,
				},
				feedback = "Reaching out cleared up one uncertainty and reminded Alex they don't have to "
					.. "figure everything out alone. Asking for information is a small but real form of "
					.. "self-advocacy, even when it takes a bit of effort to start the conversation.",
			},
			{
				id = "head_out",
				text = "Close the planner and head out",
				description = "Save your energy for the day ahead.",
				effects = {
					energy = 2,
					stress = 5,
					focus = -4,
				},
				feedback = "Skipping the planning kept a little energy in reserve, which can be a reasonable "
					.. "call on a tight morning. The open questions came along for the ride, though, and "
					.. "they may need attention later.",
			},
			{
				id = "reread",
				text = "Re-read everything until it feels right",
				description = "Go over the page again to be sure nothing is missed.",
				effects = {
					focus = 2,
					energy = -8,
					stress = 4,
					burnout = 3,
				},
				feedback = "Checking again brought some reassurance, but it used a lot of energy before the "
					.. "day had even started. Wanting certainty makes sense when things feel unpredictable; "
					.. "noticing when checking stops helping is a useful skill.",
			},
		},
	},
	{
		id = "alex_d1_s1_group_project",
		characterId = "alex",
		day = 1,
		order = 2,
		location = "classroom_seat",
		promptText = "Take your seat",
		speaker = "teacher",
		leadInSeconds = 5,
		introLines = {
			"Good morning! Quick change of plans before we start.",
			"You'll be doing a group project, due Friday. Find a group of three, starting now!",
		},

		title = "The Surprise Group Project",
		timeOfDay = "8:15 AM",
		situation = "First period has barely started when the teacher announces a group project "
			.. "due Friday. Groups are being formed out loud, right now, and the instructions are "
			.. "only being given verbally. The classroom gets louder as everyone starts talking at once.",
		innerThoughts = "Wait — what are the steps again? It's so loud I can't hold onto what she said. "
			.. "I had a plan for today and this wasn't in it.",

		choices = {
			{
				id = "lead",
				text = "Volunteer to lead the group",
				description = "Take charge so the plan feels more under your control.",
				effects = {
					energy = -15,
					stress = 10,
					motivation = 5,
					burnout = 8,
					focus = -5,
				},
				feedback = "Taking the lead gave Alex a sense of control and a small boost in motivation. "
					.. "It also meant organising other people in a loud room while still unsure of the "
					.. "instructions, which used up a lot of energy early in the day. Leading can be a real "
					.. "strength — it just has a cost worth noticing when capacity is already stretched.",
			},
			{
				id = "ask_written",
				text = "Ask the teacher for written instructions",
				description = "Quietly request the steps in writing so you can follow them.",
				effects = {
					selfAdvocacy = 12,
					stress = -8,
					focus = 10,
					energy = -5,
				},
				feedback = "Asking for written instructions took some courage and a little energy, but it "
					.. "gave Alex something steady to come back to. Requesting information in a format that "
					.. "works for you is a form of self-advocacy, and it often makes the rest of a task "
					.. "feel more manageable.",
			},
			{
				id = "go_along",
				text = "Go along with whatever group forms",
				description = "Stay quiet and figure out the details later.",
				effects = {
					stress = 6,
					motivation = -5,
					burnout = 4,
					focus = -5,
				},
				feedback = "Staying quiet avoided a stressful conversation in the moment, which can be a "
					.. "reasonable way to conserve energy. The uncertainty didn't go away, though — Alex "
					.. "carried it with them, and it may need attention later in the day.",
			},
			{
				id = "short_break",
				text = "Take a short break to reset",
				description = "Use a hall pass for a few quiet minutes before joining in.",
				effects = {
					energy = 6,
					stress = -10,
					focus = 5,
					lifeSatisfaction = 3,
					motivation = -2,
				},
				feedback = "A few quiet minutes helped Alex's nervous system settle, and they came back "
					.. "with a little more energy and focus. Missing part of the group discussion meant "
					.. "catching up afterwards. Recovery breaks are a valid tool, and noticing when you "
					.. "need one is a skill.",
			},
		},
	},
}
