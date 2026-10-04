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
		-- NPC models the client animates. Attributes: NpcId?, Talkative?,
		-- ChatterLines?
		Npc = "IgniteNpc",
		-- Looping world sounds routed through the environment sound group.
		AmbientSound = "IgniteAmbientSound",
		-- Parts/models hidden locally once a story flag is set (e.g. an item
		-- packed into the backpack). Attribute: HideWhenFlag or ShowWhenFlag.
		FlagVisibility = "IgniteFlagVisibility",
		-- Hinged door leaves driven by the client Doors system.
		-- Attributes: HingeCFrame, ClosedOffset, OpenAngle, DoorId,
		-- DoorGroup?, AutoClose?, Locked?
		Door = "IgniteDoor",
		-- Invisible route points the objective marker can point at.
		-- Attribute: WaypointId.
		Waypoint = "IgniteWaypoint",
		-- Pedestrian signal heads (parts "Walk"/"Wait"). Attribute: CrosswalkId.
		CrosswalkSignal = "IgniteCrosswalkSignal",
		-- Small looping world motion driven by the client WorldMotion module
		-- (swaying trees, a spinning sprinkler, a garden gate, a flag, a
		-- dog's tail). Attribute: Motion, plus MotionPivot / MotionAxis /
		-- MotionSpeed / MotionAmount depending on the kind.
		AmbientMotion = "IgniteAmbientMotion",
	}),

	Attributes = table.freeze({
		InteractionType = "InteractionType",
		InteractionId = "InteractionId",
		ZoneId = "ZoneId",
		AreaId = "AreaId",
		NpcId = "NpcId",
		Talkative = "Talkative",
		-- On NPCs: background lines separated by "|" (client AmbientChatter).
		ChatterLines = "ChatterLines",
		ItemId = "ItemId",
		-- On Sit prompts: a scenario location that starts once seated.
		ScenarioLocation = "ScenarioLocation",
		-- On seats: an NPC the player listens to while seated.
		ListenTo = "ListenTo",
		-- On seats: an activity done as a short guided task while seated
		-- (e.g. slow breathing on the alcove bench).
		RecoveryActivity = "RecoveryActivity",
		-- On prompts: "lift" (small objects), "pulse" (default), "open"
		-- (swings an AnimatedCover), "collect" (pickups), "pack" (flies into
		-- the PackInto target) or "none".
		Feedback = "Feedback",
		-- On models: highlight/animate the whole model for a prompt inside it.
		InteractModel = "InteractModel",
		-- See Tags.FlagVisibility.
		HideWhenFlag = "HideWhenFlag",
		ShowWhenFlag = "ShowWhenFlag",
		-- Doors (see Tags.Door).
		DoorId = "DoorId",
		DoorGroup = "DoorGroup",
		AutoClose = "AutoClose",
		Locked = "Locked",
		LockedMessage = "LockedMessage",
		WaypointId = "WaypointId",
		CrosswalkId = "CrosswalkId",
		HingeCFrame = "HingeCFrame",
		ClosedOffset = "ClosedOffset",
		OpenAngle = "OpenAngle",
		-- On NPCs: a looping background activity the NpcAnimator plays
		-- ("water", "sweep", "garden", "sit", "sit_mug", "sit_phone", "phone").
		Activity = "Activity",
		-- On NPCs: measured rig proportions (studs) used for sitting and
		-- crouching poses: hip joint height above the floor, thigh length,
		-- and the seat top height for seated activities.
		HipJointHeight = "HipJointHeight",
		ThighLength = "ThighLength",
		SeatHeight = "SeatHeight",
		-- See Tags.AmbientMotion. Motion: "sway" | "spin" | "gate" | "wag" | "flutter".
		Motion = "Motion",
		MotionPivot = "MotionPivot",
		MotionAxis = "MotionAxis",
		MotionSpeed = "MotionSpeed",
		MotionAmount = "MotionAmount",
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
		-- InteractionId is a door id; the client Doors system opens/closes it.
		Door = "Door",
		-- InteractionId is a crosswalk id; pressing asks for the walk signal.
		Signal = "Signal",
	}),

	-- ReplicatedStorage folder of templates the client clones for ambient
	-- life (pedestrian rigs, traffic cars, a dog, carried props), plus
	-- named route points as Vector3 attributes on its "Markers" child.
	AmbientFolder = "IgniteAmbient",

	Remotes = table.freeze({
		Folder = "IgniteRemotes",
		Travel = "RequestTravel",
		Inventory = "InventoryRequest",
		Sit = "RequestSit",
	}),
})
