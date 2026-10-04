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
		modifiers = {
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
		ambience = {
			saturation = 0.05,
			brightness = 0.02,
			tint = Color3.fromRGB(238, 246, 255),
		},
	},
}
