--[[
	Npcs

	Named NPCs that take part in scenes. World builders tag the NPC model
	with the matching NpcId; scenarios refer to them as `speaker`.

	PLACEHOLDER CONTENT.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	teacher = {
		name = "Ms. Rivera",
		-- Captions shown while the player sits and listens.
		lectureLines = {
			"Okay, let's pick up where we left off yesterday.",
			"Plants turn sunlight into energy. Who remembers what that's called?",
			"Right, photosynthesis. Write that one down.",
			"If you have questions, you can raise your hand or leave a note on my desk.",
		},
	},
})
