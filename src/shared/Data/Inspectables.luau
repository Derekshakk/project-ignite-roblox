--[[
	Inspectables

	Small world details the player can look at. Inspecting shows a short
	note and never changes meters — they add texture to the world and say a
	little more about the character. The first look at each one counts
	toward "details noticed" (shown on the results screen); finding them is
	optional.

	PLACEHOLDER CONTENT.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	-- Bedroom
	bedroom_photo = {
		title = "Photo",
		actionText = "Look",
		text = "A photo from a summer trip to the aquarium. Everyone is squinting into the sun.",
	},
	bedroom_drawings = {
		title = "Drawings",
		actionText = "Look",
		text = "Pages of deep-sea creatures, each labelled in tiny handwriting. Alex has drawn the same anglerfish eleven times.",
	},
	bedroom_bookshelf = {
		title = "Bookshelf",
		actionText = "Look",
		text = "Ocean field guides, two sketching how-tos, and a library book that's due on Thursday.",
	},
	bedroom_window = {
		title = "Window",
		actionText = "Look outside",
		text = "Grey sky, quiet street. The bus stop is just visible at the end of the road.",
	},

	-- The walk to school
	neighbor_garden = {
		title = "Mr. Okafor's garden",
		actionText = "Look",
		text = "Tomato plants tied to bamboo stakes. A hand-written tag says \"Do not pick yet!!\"",
	},
	bus_stop = {
		title = "Bus stop",
		actionText = "Read",
		text = "Route 4 timetable. Someone has circled 7:42 and written \"always late\" next to it.",
	},
	park_sign = {
		title = "Elm Park",
		actionText = "Read",
		text = "\"Path to Westbrook High. Quiet area, please keep music low.\" Someone has drawn a small bird on it.",
	},
	school_sign = {
		title = "Westbrook High School",
		actionText = "Read",
		text = "Home of the Herons. The letter board underneath says: WELCOME BACK. QUIET ROOM OPEN AT LUNCH.",
	},

	-- Hallway
	hallway_noticeboard = {
		title = "Notice board",
		actionText = "Read",
		text = "Club fair on Friday. Quiet study room open at lunch. Lost: one blue water bottle.",
	},
	hallway_lost_bag = {
		title = "Someone's bag",
		actionText = "Look",
		text = "Someone left their bag on the bench. A tiny octopus keychain hangs from the zip.",
	},
	alcove_shelf = {
		title = "Book swap",
		actionText = "Look",
		text = "A handwritten sign: \"Take one, leave one.\" Someone has left a well-worn guide to tide pools.",
	},

	-- Classroom
	classroom_schedule = {
		title = "Today's schedule",
		actionText = "Read",
		text = "Period 1: Science, Room 104. Period 2: Math quiz. Period 3: Reading.",
	},
	classroom_calm_card = {
		title = "Card by the beanbag",
		actionText = "Read",
		text = "\"Need a minute? You can use this corner, no need to ask. Headphones are on the shelf.\"",
	},
})
