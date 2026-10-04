--[[
	Areas

	Display names and ambient audio for each area of the world.

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
	},
	hallway = {
		title = "Main Hallway",
		ambience = { soundId = "", volume = 0.2 }, -- school background, lockers, footsteps
	},
	classroom = {
		title = "Room 104",
		ambience = { soundId = "", volume = 0.15 }, -- low classroom murmur, chairs
	},
})
