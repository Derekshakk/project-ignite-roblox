--[[
	Npcs

	Named NPCs that take part in scenes. World builders tag the NPC model
	with the matching NpcId; scenarios refer to them as `speaker`. Named
	NPCs get a small name label over their head.

	NPC shape:
		name: string
		lectureLines: { string }?   spoken while the player sits in a seat
		                            that listens to this NPC (ListenTo)
		greeting: string?           said once per run when the player first
		                            comes within `greetDistance` studs, while
		                            the scenario at `greetFor` is available
		greetDistance: number?
		greetFor: string?           scenario location id
		greetReaction: string?      animation played with the greeting
		                            ("wave", "nod", "point", "shrug")

	PLACEHOLDER CONTENT.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

return TableUtil.deepFreeze({
	teacher = {
		name = "Ms. Rivera",
		-- Spoken while the player sits and listens.
		lectureLines = {
			"Okay, let's pick up where we left off yesterday.",
			"Plants turn sunlight into energy. Who remembers what that's called?",
			"Right, photosynthesis. Write that one down.",
			"If you have questions, you can raise your hand or leave a note on my desk.",
		},
		greeting = "Morning, Alex! Grab your seat whenever you're ready.",
		greetDistance = 20,
		greetFor = "classroom_seat",
		greetReaction = "wave",
	},
	neighbor = {
		name = "Mr. Okafor",
		greeting = "Morning, Alex! Have a good day at school.",
		greetDistance = 18,
		greetReaction = "wave",
	},
	riley = {
		name = "Riley",
		greeting = "Hey Alex! This light takes forever, huh?",
		greetDistance = 16,
		greetReaction = "wave",
	},
	crossing_guard = {
		name = "Ms. Dale",
		greeting = "Good morning! I'll get you across.",
		greetDistance = 18,
		greetReaction = "point",
	},
	sam = {
		name = "Sam",
		greeting = "Alex! Over here!",
		greetDistance = 18,
		greetFor = "hallway_friend",
		greetReaction = "wave",
	},
})
