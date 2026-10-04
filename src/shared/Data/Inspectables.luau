--[[
	Inspectables

	Small world details the player can look at. Inspecting shows a short
	note and never changes meters — they add texture to the world.

	PLACEHOLDER CONTENT.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	bedroom_photo = {
		title = "Photo",
		actionText = "Look",
		text = "A photo from a summer trip to the aquarium. Everyone is squinting into the sun.",
	},
	hallway_noticeboard = {
		title = "Notice board",
		actionText = "Read",
		text = "Club fair on Friday. Quiet study room open at lunch. Lost: one blue water bottle.",
	},
	classroom_schedule = {
		title = "Today's schedule",
		actionText = "Read",
		text = "Period 1: Science, Room 104. Period 2: Math quiz. Period 3: Reading.",
	},
})
