--[[
	Alex — character data.

	PLACEHOLDER CONTENT: replace the text below with Alex's final content from
	the Flutter version of Project Ignite. The field names are the contract;
	every character module must return a table with the same shape (see
	Characters/init.luau for the full list and validation rules).
]]

return {
	id = "alex",
	sortOrder = 1,

	name = "Alex",
	age = 16,
	pronouns = "they/them",
	shortDescription = "A curious, creative student who notices details others miss "
		.. "and runs low on energy when the day gets loud and unpredictable.",

	neurodivergentExperiences = {
		"Processes a lot of sensory input at once",
		"Finds sudden changes to plans hard to switch into",
		"Thinks in big, connected ideas",
	},

	strengths = {
		"Creative problem solving",
		"Deep focus on topics they care about",
		"Notices patterns and details",
	},

	burnoutTriggers = {
		"Loud, crowded spaces",
		"Last-minute schedule changes",
		"Unclear or spoken-only instructions",
	},

	recoveryStrategies = {
		"Short quiet breaks",
		"Written plans and checklists",
		"Time for a special interest",
	},

	-- 0–100. Any meter left out falls back to Meters.DEFAULT_VALUE.
	startingMeters = {
		burnout = 30,
		energy = 65,
		focus = 55,
		stress = 40,
		motivation = 60,
		lifeSatisfaction = 60,
		selfAdvocacy = 35,
	},

	-- Reserved for later milestones (portrait/scene artwork, theming).
	portraitImage = nil,
	accentColor = Color3.fromRGB(94, 155, 232),
}
