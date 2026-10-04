--[[
	Areas

	Display names, ambient audio and time rules for each area of the world.
	Areas are found by the area volumes the world builders place; when two
	overlap (the neighbourhood around the house and school), the smaller,
	more specific one wins.

	Area shape:
		title: string
		ambience: { soundId: string, volume: number }?
		arrivals: { ArrivalRule }?   time progression when the player
		                             arrives; each rule applies once per day,
		                             the first time its `when` holds
	ArrivalRule:
		when: Condition?             see Game/Conditions
		minutes: number?             advance the clock by this much
		atLeast: string?             and/or move it to at least this time
		message: string?             notification shown when it applies

	PLACEHOLDER AUDIO: Roblox Studio ships no ambient loops, so `soundId` is
	empty and the area plays silently. Paste an audio asset id
	("rbxassetid://123…") from the Creator Store to enable it; volume is
	already set conservatively. Ambience plays through the environment
	sound group, so it is muffled while headphones are worn.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	bedroom = {
		title = "Bedroom",
		ambience = { soundId = "", volume = 0.15 }, -- quiet room tone, distant birds
		arrivals = {
			{
				when = { flag = "recoveredAfterClass" },
				atLeast = "3:35 PM",
			},
		},
	},
	home = {
		title = "Home",
		ambience = { soundId = "", volume = 0.12 }, -- fridge hum, clock ticking
		arrivals = {
			{
				when = { flag = "recoveredAfterClass" },
				atLeast = "3:30 PM",
				message = "Home again. The house is quiet.",
			},
		},
	},
	neighborhood = {
		title = "Maple Street",
		ambience = { soundId = "", volume = 0.2 }, -- birds, distant traffic
		arrivals = {
			{ atLeast = "7:35 AM" },
			{
				-- Leaving school once the morning's done: the day moves on.
				when = { flag = "recoveredAfterClass" },
				atLeast = "3:05 PM",
				message = "The rest of the school day goes by. Time to walk home.",
			},
		},
	},
	hallway = {
		title = "Westbrook High",
		ambience = { soundId = "", volume = 0.2 }, -- school background, lockers, footsteps
		arrivals = {
			-- The walk to school.
			{ minutes = 15 },
		},
	},
	classroom = {
		title = "Room 104",
		ambience = { soundId = "", volume = 0.15 }, -- low classroom murmur, chairs
	},
})
