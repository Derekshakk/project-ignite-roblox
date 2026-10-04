--[[
	World

	The contract between the 3D world (built on the server) and the gameplay
	systems (run on the client). Builders tag instances and set attributes
	using these names; client world controllers look them up the same way.
	Nothing here is specific to a character or a room.
]]

return table.freeze({
	Tags = table.freeze({
		-- ProximityPrompts that trigger gameplay. Attributes: InteractionType, InteractionId.
		Interactable = "IgniteInteractable",
		-- Invisible box parts the player can stand inside. Attribute: ZoneId.
		Zone = "IgniteZone",
		-- Invisible box parts marking which area the player is in. Attribute: AreaId.
		Area = "IgniteArea",
		-- NPC models the client animates. Attributes: NpcId?, Talkative?
		Npc = "IgniteNpc",
		-- Door leaves that swing open when the player approaches.
		-- Attributes: HingeCFrame, ClosedOffset, OpenAngle.
		AutoDoor = "IgniteAutoDoor",
		-- Looping world sounds routed through the environment sound group.
		AmbientSound = "IgniteAmbientSound",
	}),

	Attributes = table.freeze({
		InteractionType = "InteractionType",
		InteractionId = "InteractionId",
		ZoneId = "ZoneId",
		AreaId = "AreaId",
		NpcId = "NpcId",
		Talkative = "Talkative",
		ItemId = "ItemId",
		-- On Sit prompts: a scenario location that starts once seated.
		ScenarioLocation = "ScenarioLocation",
		-- On seats: an NPC the player listens to while seated.
		ListenTo = "ListenTo",
		-- On prompts: "lift" (small objects), "pulse" (default) or "none".
		Feedback = "Feedback",
		HingeCFrame = "HingeCFrame",
		ClosedOffset = "ClosedOffset",
		OpenAngle = "OpenAngle",
	}),

	InteractionTypes = table.freeze({
		-- InteractionId is a location id; the scenario shown there depends on
		-- the character and day (see Scenario.location).
		Scenario = "Scenario",
		-- InteractionId is an activity id (Data/Activities).
		Activity = "Activity",
		-- InteractionId is a destination id; the server moves the character.
		Travel = "Travel",
		-- Ends the day once all objectives are complete.
		EndDay = "EndDay",
		-- InteractionId is an item id (Data/Items); adds it to the inventory.
		Pickup = "Pickup",
		-- InteractionId is an inspectable id (Data/Inspectables).
		Inspect = "Inspect",
		-- InteractionId is a seat id; the server seats the character.
		Sit = "Sit",
	}),

	Remotes = table.freeze({
		Folder = "IgniteRemotes",
		Travel = "RequestTravel",
		Inventory = "InventoryRequest",
		Sit = "RequestSit",
	}),
})
