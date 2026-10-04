--[[
	School zones.

	PLACEHOLDER VALUES: tune once more of the day exists. Totals are capped
	by maxTicks so lingering can never push a meter far.
	  crowded_hallway: walking straight through ≈ +8 stress (entry +4, then
	                   +2 every 1.5 s, up to +12 more while lingering).
	                   Wearing headphones ≈ +3–4 (entry +2, then +1 per tick):
	                   less demand, not none.
	  quiet_alcove:    up to -10 stress, +5 energy

	`ambientSound.soundId` is an empty placeholder (see Data/Areas).
]]

return {
	{
		id = "crowded_hallway",
		title = "Crowded hallway",
		entryEffects = { stress = 4, energy = -2 },
		effects = { stress = 2, focus = -1 },
		tickSeconds = 1.5,
		maxTicks = 6,
		walkSpeedMultiplier = 0.65,
		ambientSound = { soundId = "", volume = 0.3 }, -- crowd chatter loop
		enterMessage = "The hallway is packed and loud. Alex can feel the noise starting to add up.",
		capMessage = "Alex has made it through the busiest stretch. The crowd took some energy to get through.",
		eventSummary = "Moved through the crowded hallway",
		ambience = {
			saturation = -0.25,
			contrast = 0.06,
			tint = Color3.fromRGB(255, 243, 232),
		},
		-- First match wins: waiting for the rush (or arriving late) thins the
		-- crowd; headphones still help on top of that.
		modifiers = {
			{
				when = { flags = { "crowdThinned", "equipped:headphones" } },
				entryEffects = { stress = 1 },
				effects = {},
				walkSpeedMultiplier = 0.9,
				enterMessage = "With the rush over and headphones on, the hallway feels manageable.",
				eventSummary = "Walked through the hallway after the rush, with headphones on",
				ambience = { saturation = -0.04, tint = Color3.fromRGB(252, 250, 247) },
			},
			{
				when = { flag = "crowdThinned" },
				entryEffects = { stress = 2 },
				effects = { stress = 1 },
				walkSpeedMultiplier = 0.85,
				enterMessage = "The rush has passed. It's still busy, but there's room to move now.",
				eventSummary = "Walked through the hallway after the rush",
				ambience = { saturation = -0.1, contrast = 0.02, tint = Color3.fromRGB(252, 248, 242) },
			},
			{
				when = { after = "8:10 AM" },
				entryEffects = { stress = 2 },
				effects = { stress = 1 },
				walkSpeedMultiplier = 0.85,
				enterMessage = "Most people have already gone to class. The hallway is quieter now.",
				eventSummary = "Walked through the hallway after most people had gone",
				ambience = { saturation = -0.1, contrast = 0.02, tint = Color3.fromRGB(252, 248, 242) },
			},
			{
				when = { flag = "equipped:headphones" },
				entryEffects = { stress = 2, energy = -1 },
				effects = { stress = 1 },
				enterMessage = "With headphones on, the noise is muffled. The crowd still takes some effort.",
				eventSummary = "Moved through the crowded hallway with headphones on",
				ambience = {
					saturation = -0.1,
					contrast = 0.02,
					tint = Color3.fromRGB(250, 248, 245),
				},
			},
		},
	},
	{
		id = "quiet_alcove",
		title = "Quiet space",
		effects = { stress = -2, energy = 1 },
		tickSeconds = 2,
		maxTicks = 5,
		enterMessage = "It's quieter here. Alex can take a moment before moving on.",
		capMessage = "Alex feels a bit steadier. Staying longer won't restore much more right now.",
		eventSummary = "Took a short pause in the quiet space",
		modifiers = {
			{
				when = { flag = "packed:water" },
				effects = { stress = -2, energy = 2 },
				enterMessage = "It's quieter here. Alex takes a moment and a sip of water before moving on.",
			},
		},
		ambience = {
			saturation = 0.05,
			brightness = 0.02,
			tint = Color3.fromRGB(238, 246, 255),
		},
	},

	-- The walk to school.
	{
		id = "busy_street",
		title = "Busy street",
		entryEffects = { stress = 3, focus = -1 },
		effects = { stress = 1 },
		tickSeconds = 2.5,
		maxTicks = 5,
		ambientSound = { soundId = "", volume = 0.3 }, -- traffic loop (placeholder)
		enterMessage = "Cars, a bus, a horn somewhere. The main road is loud this morning.",
		capMessage = "The traffic noise has added up over the walk.",
		eventSummary = "Walked along the busy main road",
		ambience = { saturation = -0.12, contrast = 0.04 },
		modifiers = {
			{
				when = { flag = "equipped:headphones" },
				entryEffects = { stress = 1 },
				effects = {},
				enterMessage = "Headphones take the edge off the traffic noise.",
				eventSummary = "Walked along the main road with headphones on",
				ambience = { saturation = -0.04 },
			},
		},
	},
	{
		id = "park_path",
		title = "Elm Park",
		-- The quiet way is longer.
		entryMinutes = 5,
		effects = { stress = -1, energy = 1 },
		tickSeconds = 3,
		maxTicks = 4,
		enterMessage = "The park path is quieter: birds, wind, someone's dog. It's the long way, though.",
		capMessage = "Alex feels a little steadier. The long way has taken a few extra minutes.",
		eventSummary = "Took the quiet way through the park",
		ambience = {
			saturation = 0.06,
			brightness = 0.02,
			tint = Color3.fromRGB(244, 252, 240),
		},
	},
}
