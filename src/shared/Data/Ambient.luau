--[[
	Ambient

	Background life for the walk to school: traffic routes, pedestrian
	routes, the crossings both use, and the ambient sound slots. Read by
	the client's World/Ambient modules; nothing here affects gameplay.

	Coordinates are world space and follow the layout in
	server/World/Areas/Neighborhood.luau (Maple Street along X at z 43..57,
	School Road along Z at x 196..210, sidewalks 6 wide on both). A route
	point can also be a marker name (string) placed by the Neighborhood
	builder, e.g. "lot134_step", so routes follow a house if it moves.

	Crossing:
		min, max: Vector2       crosswalk rectangle on the road (x, z)
		axis: "x" | "z"          the direction people cross in
		signal: string?          crosswalk id of a pedestrian signal:
		                         cars stop while it shows "walk", people
		                         wait for it
		Without a signal, cars yield to anyone in the crosswalk or waiting
		at its curb, and people cross once no car is about to pass.

	Traffic route:
		points: { Vector3 }      lane centre line, start → end (off-map at
		                         both ends, so cars appear and leave out of
		                         sight)
		corners: { [index]: radius }  rounded corners (studs)
		speed: number            cruising speed (studs/s); cars vary ±10%
		turnSpeed: number        speed through rounded corners
		maxCars: number
		spawnEvery: { min, max } seconds between cars

	Pedestrian route:
		kind: "student" | "adult"
		mode: "oneway" (walk to the end, fade out, respawn later at the
		      start) | "pingpong" (walk back and forth, pausing at ends)
		points: { RoutePoint }
		speed: { min, max }      walking speed (studs/s)
		maxWalkers, spawnEvery, group: { min, max }?  (one-way routes)
		keepRight: number?       lateral offset to the walker's right
		endPause: { min, max }?  pause at each end (pingpong)
		schedule: { Window }?    only active in these windows of in-game
		                         time; a window with `reverse` walks the
		                         route backwards (students heading home)
		dog: boolean?            walks a dog on a leash
		carry: string?           prop held in the right hand ("groceries")
	RoutePoint: Vector3 | string | {
		at: Vector3 | string,
		pause: { min, max }?,    stop here for a moment
		look: Vector3 | string?, face this point while paused
		gesture: string?,        "reach" (mailbox), "read", "lookAround"
		wait: string?,           crossing id: wait at this curb before
		                         stepping into the road
	}

	PLACEHOLDER AUDIO: like Data/Areas, sound ids are empty until Creator
	Store assets are added. `fallback` ids are sounds bundled with every
	Roblox client, re-pitched to stand in until then.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local v = Vector3.new
local SIDEWALK = 0.2
local ROAD = 0.05
local PARK = 0.12

local SCHOOL_HOURS = {
	-- On the way in, until just after the bell.
	{ untilTime = "8:40 AM" },
	-- Heading home in the afternoon.
	{ fromTime = "2:45 PM", reverse = true },
}

return TableUtil.deepFreeze({
	limits = {
		cars = 5,
		walkers = 10,
		-- Beyond this distance from the camera, people and cars are moved
		-- a few times a second instead of every frame, without animation.
		detailDistance = 140,
		-- New cars/people only appear where the camera can't see them, or
		-- at least this far away.
		spawnClearance = 110,
	},

	crossings = {
		maple_quiet = { min = Vector2.new(61.5, 43), max = Vector2.new(68.5, 57), axis = "z" },
		maple_main = { min = Vector2.new(189.5, 43), max = Vector2.new(196.5, 57), axis = "z", signal = "crosswalk_main" },
		school_rd = { min = Vector2.new(196, 295.5), max = Vector2.new(210, 304.5), axis = "x" },
	},

	traffic = {
		{
			id = "maple_east_school_south",
			points = { v(-150, ROAD, 53.5), v(199.5, ROAD, 53.5), v(199.5, ROAD, 446) },
			corners = { [2] = 6 },
			speed = 24,
			turnSpeed = 9,
			maxCars = 3,
			spawnEvery = { 9, 20 },
		},
		{
			id = "school_north_maple_west",
			points = { v(206.5, ROAD, 446), v(206.5, ROAD, 46.5), v(-150, ROAD, 46.5) },
			corners = { [2] = 10 },
			speed = 24,
			turnSpeed = 10,
			maxCars = 3,
			spawnEvery = { 10, 22 },
		},
	},

	-- Body colours for traffic (one per car, picked at random).
	carColors = {
		Color3.fromRGB(160, 60, 56),
		Color3.fromRGB(70, 96, 140),
		Color3.fromRGB(196, 196, 190),
		Color3.fromRGB(60, 62, 70),
		Color3.fromRGB(120, 140, 110),
		Color3.fromRGB(206, 180, 120),
		Color3.fromRGB(90, 120, 150),
		Color3.fromRGB(150, 150, 156),
		Color3.fromRGB(118, 68, 84),
	},

	pedestrians = {
		{
			id = "students_maple",
			kind = "student",
			mode = "oneway",
			schedule = SCHOOL_HOURS,
			maxWalkers = 3,
			spawnEvery = { 8, 18 },
			group = { 1, 2 },
			speed = { 4.8, 5.6 },
			keepRight = 0.5,
			points = {
				v(-120, SIDEWALK, 40),
				v(178, SIDEWALK, 40),
				-- Around Riley, who waits at the corner.
				v(182, SIDEWALK, 38.2),
				v(188.8, SIDEWALK, 38.2),
				{ at = v(192.6, SIDEWALK, 42.2), wait = "maple_main" },
				{ at = v(192.6, SIDEWALK, 57.6), wait = "maple_main" },
				v(192.6, SIDEWALK, 286),
				-- Past the crossing guard.
				v(191.4, SIDEWALK, 290),
				v(191.4, SIDEWALK, 297.6),
				{ at = v(195.4, SIDEWALK, 300.6), wait = "school_rd" },
				{ at = v(210.6, SIDEWALK, 300.6), wait = "school_rd" },
				v(222, SIDEWALK, 301),
				v(262, SIDEWALK, 301.2),
			},
		},
		{
			id = "students_school_rd",
			kind = "student",
			mode = "oneway",
			schedule = SCHOOL_HOURS,
			maxWalkers = 2,
			spawnEvery = { 12, 24 },
			group = { 1, 2 },
			speed = { 4.8, 5.6 },
			keepRight = 0.5,
			points = {
				v(213, SIDEWALK, 440),
				v(213, SIDEWALK, 306),
				v(217, SIDEWALK, 302.6),
				v(262, SIDEWALK, 302.6),
			},
		},
		{
			id = "dog_walker",
			kind = "adult",
			mode = "pingpong",
			speed = { 3.8, 4.3 },
			keepRight = 0.5,
			endPause = { 3, 6 },
			dog = true,
			points = { v(-44, SIDEWALK, 40), v(150, SIDEWALK, 40) },
		},
		{
			id = "maple_south_stroll",
			kind = "adult",
			mode = "pingpong",
			speed = { 3.4, 3.9 },
			keepRight = 0.5,
			endPause = { 2, 5 },
			points = {
				v(-44, SIDEWALK, 60),
				{ at = v(64, SIDEWALK, 60), pause = { 2, 3 }, look = v(100, 4, 110), gesture = "lookAround" },
				v(150, SIDEWALK, 60),
			},
		},
		{
			id = "park_stroll",
			kind = "adult",
			mode = "pingpong",
			speed = { 3.6, 4.2 },
			endPause = { 2, 4 },
			points = {
				v(66.5, SIDEWALK, 61.8),
				v(82, PARK, 92),
				v(128, PARK, 108),
				v(108, PARK, 158),
				v(158, PARK, 190),
				{ at = v(128, PARK, 232), pause = { 3, 5 }, look = v(92, 1, 210) },
				v(172, PARK, 262),
				v(184, PARK, 280),
			},
		},
		{
			id = "groceries_home",
			kind = "adult",
			mode = "oneway",
			maxWalkers = 1,
			spawnEvery = { 30, 60 },
			speed = { 3.8, 4.3 },
			keepRight = 0.5,
			carry = "groceries",
			points = {
				v(-120, SIDEWALK, 40),
				v(86, SIDEWALK, 40),
				v(88.4, SIDEWALK, 38.4),
				"lot92_gate",
				"lot92_step",
			},
		},
		{
			id = "mail_check",
			kind = "adult",
			mode = "pingpong",
			speed = { 3.2, 3.6 },
			endPause = { 8, 14 },
			points = {
				{ at = "lot134_step", gesture = "read" },
				"lot134_gate",
				"lot134_mailwalk",
				{ at = "lot134_mailstand", pause = { 2.5, 3.5 }, look = "lot134_mailbox", gesture = "reach" },
			},
		},
		{
			id = "school_rd_walk",
			kind = "adult",
			mode = "pingpong",
			speed = { 4.0, 4.6 },
			keepRight = 0.5,
			endPause = { 2, 4 },
			points = { v(213, SIDEWALK, 64), v(213, SIDEWALK, 284) },
		},
	},

	sounds = {
		-- Per car, 3D. Pitch follows speed, with a slight doppler shift.
		engine = { id = "", volume = 0.18, speed = 1 },
		road = { id = "", fallback = "rbxasset://sounds/action_falling.mp3", volume = 0.1, speed = 0.32 },
		-- Per nearby walker, 3D.
		footsteps = { id = "", fallback = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.1 },
		-- Outdoor beds (2D), faded in while the player is outside.
		birds = { id = "", volume = 0.12 },
		wind = { id = "", fallback = "rbxasset://sounds/action_falling.mp3", volume = 0.035, speed = 0.55 },
		-- Positional murmur at talking groups (no speech bubbles).
		murmur = { id = "", volume = 0.1 },
	},
})
