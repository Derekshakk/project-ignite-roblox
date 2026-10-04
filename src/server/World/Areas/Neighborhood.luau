--[[
	Neighborhood — the walk from Alex's house to school.

	The ground only covers the playable map (house, streets, park, school
	grounds), with an invisible boundary around it. Maple Street and School
	Road continue past the boundary (out of reach) so background traffic
	arrives and leaves out of sight. Coordinates are world space (the house
	is at the origin; the school's hallway origin comes from WorldBuilder).

	Layout (top-down, +x east, +z south):
		house       x -15..15, z -12..24, path down to Maple Street
		Maple St    runs east along z 43..57, sidewalks on both sides
		            - quiet crossing at x 62..68 → Elm Park (the long, quiet
		              way: zone "park_path")
		            - main crossing at x 190..196, with walk signals
		              (busy stretch: zone "busy_street")
		School Rd   runs south along x 196..210 to the school
		            - crossing guard and crosswalk at z 296..304
		school      entrance faces west at x ≈ 273, z = 300 (SchoolExterior)
	Walking either way takes roughly half a minute at normal speed.

	Neighbours (Houses.luau variants) line Maple Street: four lots on the
	north side (x 50, 92, 134, 170) and two on the south (x -24, 26), each
	with a driveway, a walk, landscaping and a mailbox. Some neighbours are
	busy outside (NpcAnimator activities): watering, sweeping, gardening,
	sitting on a porch, chatting with a dog at their feet, and a student
	waiting at the bus stop. Walkers and traffic are added by the client
	(World/Ambient) along routes in Data/Ambient; the named route points
	they use are placed here with Builder.routeMarker.

	Interaction points:
		walk-signal buttons → Signal "crosswalk_main"
		Inspect "neighbor_garden", "bus_stop", "park_sign"
	NPCs: Mr. Okafor (neighbour), Riley (waiting at the main crossing),
	Ms. Dale (crossing guard).
	Route points for the objective marker: Waypoint "main_corner",
	"school_crossing". Area: "neighborhood".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Builder = require(script.Parent.Parent.Builder)
local Houses = require(script.Parent.Parent.Houses)
local Npc = require(script.Parent.Parent.Npc)
local OutdoorProps = require(script.Parent.Parent.OutdoorProps)
local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local Vehicles = require(script.Parent.Parent.Vehicles)

local C = Palette.Colors
local O = OutdoorProps.Colors
local InteractionType = World.InteractionTypes
local hash = Props.hash
local rgb = Color3.fromRGB

local BOUNDS = { minX = -50, maxX = 440, minZ = -50, maxZ = 350 }
-- Where the streets end, out of reach past the boundary (traffic routes
-- in Data/Ambient start and end here).
local MAPLE_WEST_END = -150
local SCHOOL_RD_SOUTH_END = 446
local SIDEWALK_TOP = Builder.FLOOR_TOP
local STREET_TOP = 0.05
local PATH_TOP = 0.12

local MAPLE = { z1 = 43, z2 = 57 } -- along X
local SCHOOL_RD = { x1 = 196, x2 = 210 } -- along Z
local PARK = { x1 = 66, z1 = 66, x2 = 184, z2 = 284 }
local PARK_PATH = {
	Vector3.new(68, 0, 61),
	Vector3.new(82, 0, 92),
	Vector3.new(128, 0, 108),
	Vector3.new(108, 0, 158),
	Vector3.new(158, 0, 190),
	Vector3.new(128, 0, 232),
	Vector3.new(172, 0, 262),
	Vector3.new(192, 0, 291),
}
local POND = Vector3.new(92, 0, 210)

-- House styles: wall, trim, roof, door, shutter, accent.
local STYLES = {
	sage = { wall = rgb(160, 176, 146), trim = rgb(232, 226, 210), roof = rgb(74, 70, 72), door = rgb(150, 56, 52), shutter = rgb(62, 82, 66) },
	cream = { wall = rgb(214, 198, 166), trim = rgb(236, 232, 220), roof = rgb(92, 72, 64), door = rgb(50, 78, 112), shutter = rgb(52, 70, 96), accent = rgb(176, 132, 96) },
	blue = { wall = rgb(132, 160, 186), trim = rgb(234, 230, 220), roof = rgb(62, 64, 70), door = rgb(204, 168, 70), shutter = rgb(44, 58, 78) },
	brick = { wall = rgb(150, 86, 70), trim = rgb(230, 224, 210), roof = rgb(58, 60, 64), door = rgb(36, 70, 60), shutter = rgb(36, 46, 44), wallMaterial = Enum.Material.Brick },
	clay = { wall = rgb(196, 132, 104), trim = rgb(236, 228, 212), roof = rgb(84, 66, 60), door = rgb(70, 92, 70), shutter = rgb(96, 64, 52), accent = rgb(214, 186, 140) },
	grey = { wall = rgb(176, 178, 176), trim = rgb(240, 238, 232), roof = rgb(54, 60, 70), door = rgb(170, 70, 60), shutter = rgb(70, 80, 96) },
}

local Neighborhood = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Floor CFrame at (x, top, z) facing toward (tx, tz).
local function facingPoint(x: number, top: number, z: number, tx: number, tz: number): CFrame
	return CFrame.lookAt(v(x, top, z), v(tx, top, tz))
end

-- Distance from a point to the park path (flat).
local function distanceToPath(point: Vector3): number
	local best = math.huge
	for i = 1, #PARK_PATH - 1 do
		local a, b = PARK_PATH[i], PARK_PATH[i + 1]
		local ab = b - a
		local t = math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (point - (a + ab * t)).Magnitude)
	end
	return best
end

local function inRoadCorridor(point: Vector3): boolean
	return (point.Z > 28 and point.Z < 72) or (point.X > 180 and point.X < 226)
end

local function buildGround(parent: Instance)
	local ground = Builder.model(parent, "Ground")
	OutdoorProps.slab(ground, "Grass", BOUNDS.minX, BOUNDS.minZ, BOUNDS.maxX, BOUNDS.maxZ, 0, O.Grass, Enum.Material.Grass, 4)
	-- Out-of-reach ground along the two streets that run off the map.
	OutdoorProps.slab(ground, "GrassWest", MAPLE_WEST_END - 14, 0, BOUNDS.minX, 110, 0, O.Grass, Enum.Material.Grass, 4)
	OutdoorProps.slab(ground, "GrassSouth", 150, BOUNDS.maxZ, 262, SCHOOL_RD_SOUTH_END + 14, 0, O.Grass, Enum.Material.Grass, 4)

	-- Invisible boundary so nobody walks off the edge of the map.
	local height = 60
	local function wall(name: string, x1: number, z1: number, x2: number, z2: number)
		Builder.part(ground, name, CFrame.new((x1 + x2) / 2, height / 2, (z1 + z2) / 2), Vector3.new(math.max(math.abs(x2 - x1), 2), height, math.max(math.abs(z2 - z1), 2)), O.Grass, {
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		})
	end
	wall("BoundaryNorth", BOUNDS.minX, BOUNDS.minZ - 1, BOUNDS.maxX, BOUNDS.minZ - 1)
	wall("BoundarySouth", BOUNDS.minX, BOUNDS.maxZ + 1, BOUNDS.maxX, BOUNDS.maxZ + 1)
	wall("BoundaryWest", BOUNDS.minX - 1, BOUNDS.minZ, BOUNDS.minX - 1, BOUNDS.maxZ)
	wall("BoundaryEast", BOUNDS.maxX + 1, BOUNDS.minZ, BOUNDS.maxX + 1, BOUNDS.maxZ)

	-- A tree line just inside the boundary hides the edge of the world
	-- (open where the streets continue). Simple far-away trees.
	local seed = 500
	for x = BOUNDS.minX + 6, BOUNDS.maxX - 6, 16 do
		for _, z in { BOUNDS.minZ + 5, BOUNDS.maxZ - 5 } do
			seed += 1
			local point = v(x + (hash(seed) - 0.5) * 6, 0, z)
			if not (z > 300 and point.X > 180 and point.X < 226) then
				OutdoorProps.tree(ground, CFrame.new(point), seed, 1.2, { far = true })
			end
		end
	end
	for z = BOUNDS.minZ + 22, BOUNDS.maxZ - 22, 16 do
		for _, x in { BOUNDS.minX + 5, BOUNDS.maxX - 5 } do
			seed += 1
			local point = v(x, 0, z + (hash(seed) - 0.5) * 6)
			if not (x < 0 and point.Z > 28 and point.Z < 72) then
				OutdoorProps.tree(ground, CFrame.new(point), seed, 1.2, { far = true })
			end
		end
	end
	-- Trees lining the streets beyond the boundary.
	for x = MAPLE_WEST_END - 4, BOUNDS.minX - 6, 13 do
		for _, z in { 30, 70 } do
			seed += 1
			OutdoorProps.tree(ground, CFrame.new(x + (hash(seed) - 0.5) * 4, 0, z + (hash(seed + 1) - 0.5) * 4), seed, 1.15, { far = true })
		end
	end
	for z = BOUNDS.maxZ + 6, SCHOOL_RD_SOUTH_END + 4, 13 do
		for _, x in { 183, 223 } do
			seed += 1
			OutdoorProps.tree(ground, CFrame.new(x + (hash(seed) - 0.5) * 4, 0, z), seed, 1.15, { far = true })
		end
	end

	-- Soft patches so the open grass isn't one flat colour.
	OutdoorProps.grassPatches(ground, BOUNDS.minX + 4, BOUNDS.minZ + 4, BOUNDS.maxX - 4, BOUNDS.maxZ - 4, 70, 900, function(point)
		return inRoadCorridor(point)
			or (point.X > -18 and point.X < 18 and point.Z > -15 and point.Z < 38)
			or (point.X > 262 and point.X < 380 and point.Z > 270 and point.Z < 330)
	end)
end

local function buildStreets(parent: Instance)
	local streets = Builder.model(parent, "Streets")
	local asphalt, concrete = Enum.Material.Asphalt, Enum.Material.Concrete

	-- Roads.
	OutdoorProps.slab(streets, "MapleStreet", MAPLE_WEST_END, MAPLE.z1, SCHOOL_RD.x2, MAPLE.z2, STREET_TOP, O.Asphalt, asphalt)
	OutdoorProps.slab(streets, "SchoolRoad", SCHOOL_RD.x1, MAPLE.z2, SCHOOL_RD.x2, SCHOOL_RD_SOUTH_END, STREET_TOP, O.Asphalt, asphalt)
	-- A few patched sections of asphalt.
	for i, spec in { { 30, 48, 9, 4 }, { 132, 53, 12, 3.5 }, { 203, 160, 4, 10 }, { 200, 248, 3.5, 7 } } do
		Builder.detail(streets, "Patch", CFrame.new(spec[1], STREET_TOP + 0.005, spec[2]) * CFrame.Angles(0, math.rad(hash(i) * 8 - 4), 0), v(spec[3], 0.02, spec[4]), O.AsphaltPatch, {
			Material = asphalt,
		})
	end

	-- Sidewalks (raised a little above the road; a small step, no gaps).
	OutdoorProps.slab(streets, "SidewalkMapleNorth", MAPLE_WEST_END, 37, SCHOOL_RD.x2 + 6, MAPLE.z1, SIDEWALK_TOP, O.Sidewalk, concrete)
	OutdoorProps.slab(streets, "SidewalkMapleSouth", MAPLE_WEST_END, MAPLE.z2, SCHOOL_RD.x1 - 6, 63, SIDEWALK_TOP, O.Sidewalk, concrete)
	OutdoorProps.slab(streets, "SidewalkSchoolWest", SCHOOL_RD.x1 - 6, MAPLE.z2, SCHOOL_RD.x1, SCHOOL_RD_SOUTH_END, SIDEWALK_TOP, O.Sidewalk, concrete)
	OutdoorProps.slab(streets, "SidewalkSchoolEast", SCHOOL_RD.x2, MAPLE.z1, SCHOOL_RD.x2 + 6, SCHOOL_RD_SOUTH_END, SIDEWALK_TOP, O.Sidewalk, concrete)
	-- Expansion joints across the sidewalks (subtle lines every few studs).
	for x = MAPLE_WEST_END + 6, SCHOOL_RD.x1 - 8, 6 do
		Builder.detail(streets, "Joint", CFrame.new(x, SIDEWALK_TOP + 0.005, 40), v(0.12, 0.02, 5.6), O.Curb)
		Builder.detail(streets, "Joint", CFrame.new(x, SIDEWALK_TOP + 0.005, 60), v(0.12, 0.02, 5.6), O.Curb)
	end
	for z = MAPLE.z2 + 6, SCHOOL_RD_SOUTH_END - 4, 6 do
		Builder.detail(streets, "Joint", CFrame.new(SCHOOL_RD.x1 - 3, SIDEWALK_TOP + 0.005, z), v(5.6, 0.02, 0.12), O.Curb)
		Builder.detail(streets, "Joint", CFrame.new(SCHOOL_RD.x2 + 3, SIDEWALK_TOP + 0.005, z), v(5.6, 0.02, 0.12), O.Curb)
	end

	-- Curbs and gutters along every road edge.
	OutdoorProps.curb(streets, v(MAPLE_WEST_END, STREET_TOP, MAPLE.z1), v(SCHOOL_RD.x2, STREET_TOP, MAPLE.z1), SIDEWALK_TOP, Vector3.zAxis)
	OutdoorProps.curb(streets, v(MAPLE_WEST_END, STREET_TOP, MAPLE.z2), v(SCHOOL_RD.x1, STREET_TOP, MAPLE.z2), SIDEWALK_TOP, -Vector3.zAxis)
	OutdoorProps.curb(streets, v(SCHOOL_RD.x1, STREET_TOP, MAPLE.z2), v(SCHOOL_RD.x1, STREET_TOP, SCHOOL_RD_SOUTH_END), SIDEWALK_TOP, Vector3.xAxis)
	OutdoorProps.curb(streets, v(SCHOOL_RD.x2, STREET_TOP, MAPLE.z1), v(SCHOOL_RD.x2, STREET_TOP, SCHOOL_RD_SOUTH_END), SIDEWALK_TOP, -Vector3.xAxis)
	for _, spec in { { 40, 43, 0, -1 }, { 132, 43, 0, -1 }, { 24, 57, 0, 1 }, { 150, 57, 0, 1 }, { 196, 140, -1, 0 }, { 196, 262, -1, 0 }, { 210, 110, 1, 0 }, { 210, 330, 1, 0 } } do
		local position = v(spec[1], STREET_TOP, spec[2])
		OutdoorProps.stormDrain(streets, CFrame.lookAt(position, position + v(spec[3], 0, spec[4])))
	end

	-- Centre lines (dashed), with gaps at the crossings.
	local function crossing(x: number, ranges: { { number } }): boolean
		for _, range in ranges do
			if x >= range[1] and x <= range[2] then
				return true
			end
		end
		return false
	end
	for x = MAPLE_WEST_END + 4, SCHOOL_RD.x1 - 6, 10 do
		if not crossing(x, { { 58, 72 }, { 186, 200 } }) then
			Builder.detail(streets, "LaneLine", CFrame.new(x, STREET_TOP + 0.02, (MAPLE.z1 + MAPLE.z2) / 2), v(5, 0.04, 0.35), O.LaneLine)
		end
	end
	for z = MAPLE.z2 + 6, SCHOOL_RD_SOUTH_END - 4, 10 do
		if not crossing(z, { { 292, 308 } }) then
			Builder.detail(streets, "LaneLine", CFrame.new((SCHOOL_RD.x1 + SCHOOL_RD.x2) / 2, STREET_TOP + 0.02, z), v(0.35, 0.04, 5), O.LaneLine)
		end
	end

	-- Crosswalk stripes, and stop lines where traffic waits.
	local function stripesAcrossMaple(x1: number, x2: number)
		for x = x1 + 0.6, x2 - 0.5, 1.6 do
			Builder.detail(streets, "Crosswalk", CFrame.new(x, STREET_TOP + 0.02, (MAPLE.z1 + MAPLE.z2) / 2), v(0.8, 0.04, MAPLE.z2 - MAPLE.z1 - 0.6), O.Stripe)
		end
	end
	stripesAcrossMaple(62, 68) -- quiet crossing toward the park
	stripesAcrossMaple(190, 196) -- main crossing
	for z = 296.6, 303.6, 1.6 do
		Builder.detail(streets, "Crosswalk", CFrame.new((SCHOOL_RD.x1 + SCHOOL_RD.x2) / 2, STREET_TOP + 0.02, z), v(SCHOOL_RD.x2 - SCHOOL_RD.x1 - 0.6, 0.04, 0.8), O.Stripe)
	end
	for _, spec in { { 60.4, 53.5, 0.5, 6.4 }, { 69.6, 46.5, 0.5, 6.4 }, { 188.4, 53.5, 0.5, 6.4 }, { 197.6, 46.5, 0.5, 6.4 }, { 199.5, 294.4, 6.4, 0.5 }, { 206.5, 305.6, 6.4, 0.5 } } do
		Builder.detail(streets, "StopLine", CFrame.new(spec[1], STREET_TOP + 0.02, spec[2]), v(spec[3], 0.04, spec[4]), O.Stripe)
	end

	-- Streetlights along the walking route (clear of driveways, front walks
	-- and the bus stop).
	for _, x in { -110, -70, -30, 24, 76, 111, 151 } do
		OutdoorProps.streetlight(streets, facingPoint(x, SIDEWALK_TOP, 37.6, x, 50))
	end
	for _, x in { -100, -60, 0, 50, 100, 140 } do
		OutdoorProps.streetlight(streets, facingPoint(x, SIDEWALK_TOP, 62.4, x, 50))
	end
	for z = 90, SCHOOL_RD_SOUTH_END - 10, 42 do
		OutdoorProps.streetlight(streets, facingPoint(190.6, SIDEWALK_TOP, z, 203, z))
	end

	-- Street signs at the corner, and the park turn-off.
	OutdoorProps.signPost(streets, facingPoint(187.6, SIDEWALK_TOP, 37.3, 160, 37.3), "Maple St", nil, 3.4)
	OutdoorProps.signPost(streets, facingPoint(189, 0, 64.5, 189, 30), "School Rd", nil, 3.4)
	OutdoorProps.signPost(streets, facingPoint(58.6, SIDEWALK_TOP, 37.3, 30, 37.3), "Elm Park  ›  School", rgb(70, 120, 84), 4.6)
	OutdoorProps.trafficSign(streets, facingPoint(188.4, 0, 120, 188.4, 100), "SCHOOL\nZONE", "SPEED\nLIMIT 20")
	OutdoorProps.trafficSign(streets, facingPoint(217.8, 0, 268, 217.8, 290), "SCHOOL\nZONE", "SPEED\nLIMIT 20")

	-- Street furniture, kept to the edges of the sidewalks so people can
	-- walk past.
	OutdoorProps.hydrant(streets, CFrame.new(176, SIDEWALK_TOP, 42.5))
	OutdoorProps.hydrant(streets, CFrame.new(195.4, SIDEWALK_TOP, 180))
	OutdoorProps.hydrant(streets, CFrame.new(-40, SIDEWALK_TOP, 57.6))
	Props.bin(streets, CFrame.new(141, SIDEWALK_TOP, 37.6))
	Props.bin(streets, CFrame.new(214.6, SIDEWALK_TOP, 290))
	OutdoorProps.utilityBox(streets, facingPoint(98, 0, 35.8, 98, 50))
	OutdoorProps.utilityBox(streets, facingPoint(218.4, 0, 150, 205, 150))

	-- Bus stop (inspect the timetable).
	OutdoorProps.slab(streets, "BusStopPad", 114, 31, 126, 37, SIDEWALK_TOP, O.Sidewalk, concrete)
	local _, busSign = OutdoorProps.busShelter(streets, facingPoint(120, SIDEWALK_TOP, 34.2, 120, 50))
	Builder.prompt(busSign, InteractionType.Inspect, "bus_stop", { ActionText = "Read", ObjectText = "Bus stop", MaxActivationDistance = 8 })

	-- Main crossing: walk signals on both sides, with push buttons.
	for _, spec in { { z = 42.4, faceZ = 60 }, { z = 58.4, faceZ = 30 } } do
		local button = OutdoorProps.crossingSignal(streets, facingPoint(188.4, SIDEWALK_TOP, spec.z, 188.4, spec.faceZ), "crosswalk_main")
		Builder.prompt(button, InteractionType.Signal, "crosswalk_main", {
			ActionText = "Press to cross",
			ObjectText = "Walk button",
			MaxActivationDistance = 7,
		}):SetAttribute(World.Attributes.Feedback, "none")
	end

	-- Busy road: the traffic noise of Maple's east end and School Road.
	Builder.zone(streets, "busy_street", CFrame.new(163, 5, 50), v(106, 10, 26))
	Builder.zone(streets, "busy_street", CFrame.new(203, 5, 174.5), v(26, 10, 223))
end

---------------------------------------------------------------------------
-- Lots
---------------------------------------------------------------------------

local function paved(parent: Instance, name: string, x1: number, z1: number, x2: number, z2: number, color: Color3?)
	return OutdoorProps.slab(parent, name, math.min(x1, x2), math.min(z1, z2), math.max(x1, x2), math.max(z1, z2), SIDEWALK_TOP, color or O.Driveway, Enum.Material.Concrete)
end

-- A row of shrubs along a house front.
local function shrubs(parent: Instance, from: Vector3, to: Vector3, seed: number)
	local count = math.max(1, math.floor((to - from).Magnitude / 3.2))
	for i = 0, count do
		local point = from:Lerp(to, if count == 0 then 0.5 else i / count)
		OutdoorProps.bush(parent, CFrame.new(point), seed + i, 0.85)
	end
end

local function northFront(x: number): CFrame
	return CFrame.lookAt(v(x, 0, 20), v(x, 0, 21))
end

local function southFront(x: number): CFrame
	return CFrame.lookAt(v(x, 0, 80), v(x, 0, 79))
end

local function buildLots(parent: Instance)
	local lots = Builder.model(parent, "Lots")

	-- Lot 50: ranch, garage to the east. Mr. Okafor's vegetable garden and
	-- a sprinkler on the lawn.
	do
		local lot = Builder.model(lots, "Lot50")
		local style = table.clone(STYLES.sage) :: any
		-- North-side fronts face +z, so their local +X is world -x.
		style.garageSide = -1
		style.number = "50"
		Houses.build(lot, "ranch", northFront(50), style)
		OutdoorProps.lawn(lot, 33, 22, 56, 36.6, 51)
		paved(lot, "Walk", 49, 26.2, 52, 37, O.Sidewalk)
		paved(lot, "Driveway", 56.5, 21, 65.5, 37)
		OutdoorProps.car(lot, facingPoint(61, SIDEWALK_TOP, 29, 61, 20), Vehicles.Colors[7], "suv")
		OutdoorProps.bins(lot, facingPoint(67.4, 0, 33, 60, 33))
		OutdoorProps.mailbox(lot, facingPoint(54.4, 0, 36.2, 54.4, 50), C.Charcoal)
		shrubs(lot, v(34.5, 0, 21.6), v(39.5, 0, 21.6), 120)
		OutdoorProps.sprinkler(lot, CFrame.new(44.5, 0, 31.5))
		OutdoorProps.rock(lot, CFrame.new(53.2, 0, 27.5), 1)
		OutdoorProps.rock(lot, CFrame.new(53.8, 0, 28.6), 2, 0.7)
	end

	-- Lot 92: cottage with a porch bench and a fenced front garden.
	do
		local lot = Builder.model(lots, "Lot92")
		local style = table.clone(STYLES.cream) :: any
		style.number = "92"
		local _, info = Houses.build(lot, "cottage", northFront(92), style)
		OutdoorProps.lawn(lot, 74, 28.5, 102.5, 34.3, 92, true)
		paved(lot, "Walk", 86.9, 28.2, 89.9, 37, O.Sidewalk)
		paved(lot, "Driveway", 103, 20, 109, 37)
		OutdoorProps.car(lot, facingPoint(106, SIDEWALK_TOP, 27, 106, 20), Vehicles.Colors[2], "hatchback")
		OutdoorProps.fence(lot, v(74, 0, 34.5), v(102.5, 0, 34.5), C.OffWhite, { gate = { at = 12.9, width = 3, swing = 80 } })
		OutdoorProps.mailbox(lot, facingPoint(85.4, 0, 36.1, 85.4, 50), Palette.Assorted[2])
		OutdoorProps.flowerBed(lot, CFrame.new(78.5, 0, 27.4), 8, 1.6, 921)
		OutdoorProps.flowerBed(lot, CFrame.new(96, 0, 27.4), 10, 1.6, 922)
		OutdoorProps.bush(lot, CFrame.new(76, 0, 31.5), 924)
		OutdoorProps.bush(lot, CFrame.new(100.5, 0, 31.5), 925)
		Builder.routeMarker("lot92_step", info.doorStep + v(0, SIDEWALK_TOP, 0.4))
		Builder.routeMarker("lot92_gate", v(88.4, SIDEWALK_TOP, 34.5))
		lot:SetAttribute("PorchBench", info.porchBench)
	end

	-- Lot 134: colonial. The neighbour here checks the mail now and then.
	do
		local lot = Builder.model(lots, "Lot134")
		local style = table.clone(STYLES.brick) :: any
		style.number = "134"
		local _, info = Houses.build(lot, "colonial", northFront(134), style)
		OutdoorProps.lawn(lot, 121, 26.5, 150, 34.3, 134, true)
		paved(lot, "Walk", 132.5, 26.0, 135.5, 37, O.Sidewalk)
		paved(lot, "MailPad", 135.5, 35.2, 137.2, 36.8, O.Sidewalk)
		paved(lot, "Driveway", 114, 20, 120, 37)
		OutdoorProps.car(lot, facingPoint(117, SIDEWALK_TOP, 27.5, 117, 20), Vehicles.Colors[3], "sedan")
		OutdoorProps.bins(lot, facingPoint(121.1, 0, 22, 117, 22))
		OutdoorProps.fence(lot, v(121, 0, 34.5), v(150, 0, 34.5), C.OffWhite, { gate = { at = 11.5, width = 3, swing = 80 } })
		local _, boxPosition = OutdoorProps.mailbox(lot, facingPoint(137.8, 0, 36.0, 137.8, 50), C.Charcoal)
		shrubs(lot, v(123.5, 0, 21.4), v(130, 0, 21.4), 140)
		shrubs(lot, v(138, 0, 21.4), v(144.5, 0, 21.4), 150)
		OutdoorProps.flowerBed(lot, CFrame.new(143, 0, 33.2), 10, 1.4, 931)
		Builder.routeMarker("lot134_step", info.doorStep + v(0, SIDEWALK_TOP, 0.4))
		Builder.routeMarker("lot134_gate", v(134, SIDEWALK_TOP, 34.5))
		Builder.routeMarker("lot134_mailwalk", v(134, SIDEWALK_TOP, 36.0))
		Builder.routeMarker("lot134_mailstand", v(136.3, SIDEWALK_TOP, 36.0))
		Builder.routeMarker("lot134_mailbox", boxPosition)
	end

	-- Lot 170: ranch, garage to the west, flower beds by the picture window
	-- and a low hedge.
	do
		local lot = Builder.model(lots, "Lot170")
		local style = table.clone(STYLES.grey) :: any
		style.garageSide = 1
		style.number = "170"
		Houses.build(lot, "ranch", northFront(170), style)
		OutdoorProps.lawn(lot, 164.5, 25.5, 188, 34, 170)
		paved(lot, "Walk", 168, 26.2, 171, 37, O.Sidewalk)
		paved(lot, "Driveway", 154.5, 21, 163.5, 37)
		OutdoorProps.car(lot, facingPoint(159, SIDEWALK_TOP, 29.5, 159, 20), Vehicles.Colors[1], "sedan")
		OutdoorProps.mailbox(lot, facingPoint(166.4, 0, 36.1, 166.4, 50), Palette.Assorted[4])
		OutdoorProps.flowerBed(lot, CFrame.new(182.6, 0, 22.2), 6.5, 1.8, 941)
		OutdoorProps.hedge(lot, v(171.6, 0, 35.2), v(186, 0, 35.2), 1.8)
		shrubs(lot, v(166.6, 0, 26), v(166.6, 0, 30), 160)
	end

	-- South side, lot -24: ranch, garage to the east (its owner sweeps the
	-- driveway).
	do
		local lot = Builder.model(lots, "LotMinus24")
		local style = table.clone(STYLES.clay) :: any
		style.garageSide = 1
		Houses.build(lot, "ranch", southFront(-24), style)
		OutdoorProps.lawn(lot, -40.5, 63.4, -25.5, 74, 241)
		paved(lot, "Walk", -25, 63, -22, 73.7, O.Sidewalk)
		paved(lot, "Driveway", -17.5, 63, -8.5, 79)
		OutdoorProps.bins(lot, facingPoint(-6.6, 0, 66, -12, 66))
		OutdoorProps.mailbox(lot, facingPoint(-27, 0, 63.9, -27, 50), Palette.Assorted[6])
		shrubs(lot, v(-39, 0, 78.4), v(-30, 0, 78.4), 170)
		OutdoorProps.tree(lot, CFrame.new(-44, 0, 70), 47)
	end

	-- South side, lot 26: blue cottage.
	do
		local lot = Builder.model(lots, "Lot26")
		local style = table.clone(STYLES.blue) :: any
		style.chimneySide = -1
		Houses.build(lot, "cottage", southFront(26), style)
		OutdoorProps.lawn(lot, 17, 63.4, 35, 72.5, 261, true)
		paved(lot, "Walk", 28.1, 63, 31.1, 71.6, O.Sidewalk)
		paved(lot, "Driveway", 36, 63, 42, 80)
		OutdoorProps.car(lot, facingPoint(39, SIDEWALK_TOP, 72, 39, 80), Vehicles.Colors[6], "van")
		OutdoorProps.mailbox(lot, facingPoint(32.6, 0, 63.9, 32.6, 50), Palette.Assorted[3])
		OutdoorProps.flowerBed(lot, CFrame.new(21.5, 0, 72.8), 7, 1.6, 961)
		OutdoorProps.hedge(lot, v(17, 0, 64.6), v(27.2, 0, 64.6), 1.6)
		OutdoorProps.tree(lot, CFrame.new(46, 0, 70), 49)
	end

	-- Street trees between the yards and the sidewalk, and back gardens.
	local seed = 40
	for _, point in { v(26, 0, 32), v(69.5, 0, 32), v(111.5, 0, 31), v(151.2, 0, 31), v(189, 0, 30), v(8, 0, 76) } do
		seed += 1
		OutdoorProps.tree(lots, CFrame.new(point), seed)
	end
	for x = -40, 190, 19 do
		seed += 1
		OutdoorProps.tree(lots, CFrame.new(x + hash(seed) * 6, 0, -26 - hash(seed + 1) * 10), seed)
	end
	for x = -40, 60, 24 do
		seed += 1
		OutdoorProps.tree(lots, CFrame.new(x + hash(seed) * 6, 0, 108 + hash(seed + 1) * 8), seed)
	end

	-- Mr. Okafor's vegetable garden: staked tomato plants (inspect).
	local garden = Builder.part(lots, "GardenBed", CFrame.new(34, 0.25, 28), v(7, 0.5, 3), O.Mulch, { Material = Enum.Material.Ground })
	for _, z in { 26.4, 29.6 } do
		Builder.detail(lots, "GardenEdge", CFrame.new(34, 0.3, z), v(7.4, 0.6, 0.25), C.Wood, { Material = Enum.Material.Wood })
	end
	for i = 0, 4 do
		local x = 31.4 + i * 1.3
		Builder.cylinder(lots, "Stake", CFrame.new(x + 0.25, 1.6, 28.2), 2.6, 0.12, rgb(196, 176, 110), { CanCollide = false })
		Builder.ellipsoid(lots, "Tomato", CFrame.new(x, 1.3, 28), v(1.0, 1.5, 0.9), C.Plant, { Material = Enum.Material.Grass, CanCollide = false })
		for j = 1, 2 do
			Builder.detail(lots, "Fruit", CFrame.new(x + (j - 1.5) * 0.5, 1.0 + j * 0.25, 27.55), v(0.32, 0.32, 0.32), rgb(204, 64, 52), {
				Shape = Enum.PartType.Ball,
			})
		end
	end
	Builder.prompt(garden, InteractionType.Inspect, "neighbor_garden", { ActionText = "Look", ObjectText = "Garden", MaxActivationDistance = 8 })
	return lots
end

-- Neighbours doing small things outside (NpcAnimator activities).
local function buildNeighbors(parent: Instance, lots: Instance)
	local people = Builder.model(parent, "Neighbors")
	-- Mr. Okafor, watering his tomatoes. Still greets Alex as before.
	Npc.spawn(people, "MrOkafor", facingPoint(39.6, 0, 29.2, 34, 28.2), {
		seed = 61,
		adult = true,
		shirt = rgb(176, 120, 72),
		npcId = "neighbor",
		turnRange = 0,
		activity = "water",
		hold = "watering_can",
	})
	-- Sweeping the driveway across the street.
	Npc.spawn(people, "Neighbor_Sweeping", facingPoint(-11, SIDEWALK_TOP, 70, -12.5, 63), {
		seed = 71,
		adult = true,
		turnRange = 0,
		activity = "sweep",
		hold = "broom",
	})
	-- Tending the flower bed at 170.
	Npc.spawn(people, "Neighbor_Gardening", facingPoint(182.6, 0, 24.6, 182.6, 18), {
		seed = 77,
		adult = true,
		hair = "cap",
		turnRange = 0,
		activity = "garden",
		hold = "trowel",
	})
	-- A coffee on the porch bench at 92.
	local lot92 = lots:FindFirstChild("Lot92")
	local bench = lot92 and lot92:GetAttribute("PorchBench")
	if typeof(bench) == "CFrame" then
		Npc.spawn(people, "Neighbor_Porch", bench * CFrame.new(0.9, 0, -0.1), {
			seed = 66,
			adult = true,
			turnRange = 0,
			activity = "sit_mug",
			hold = "mug",
			holdHand = "Left",
			seatHeight = OutdoorProps.BENCH_SEAT_TOP,
		})
	end
	-- Two neighbours chatting, a dog sitting with them. Visual only: they
	-- gesture and nod, without speech bubbles.
	Npc.spawn(people, "Neighbor_ChatA", facingPoint(3, 0, 71, 5.6, 72.2), { seed = 85, adult = true, talkative = true, turnRange = 0 })
	Npc.spawn(people, "Neighbor_ChatB", facingPoint(5.6, 0, 72.2, 3, 71), { seed = 86, adult = true, talkative = true, turnRange = 0 })
	OutdoorProps.dog(people, facingPoint(4.9, 0, 69.6, 2, 66), rgb(176, 128, 72), "sit")
	-- A student on their phone, waiting for the bus.
	Npc.spawn(people, "Student_BusStop", facingPoint(121.1, SIDEWALK_TOP, 33.6, 121.1, 40), {
		seed = 88,
		backpack = true,
		turnRange = 0,
		activity = "sit_phone",
		hold = "phone",
		seatHeight = OutdoorProps.BENCH_SEAT_TOP,
	})
end

local function buildPark(parent: Instance)
	local park = Builder.model(parent, "ElmPark")
	-- Hedges with gaps at the entrance (north-west) and exit (south-east).
	OutdoorProps.hedge(park, v(74, 0, PARK.z1), v(PARK.x2, 0, PARK.z1))
	OutdoorProps.hedge(park, v(PARK.x1, 0, PARK.z1 + 6), v(PARK.x1, 0, PARK.z2))
	OutdoorProps.hedge(park, v(PARK.x1, 0, PARK.z2), v(176, 0, PARK.z2))
	OutdoorProps.hedge(park, v(PARK.x2, 0, PARK.z1), v(PARK.x2, 0, 274))

	for i = 1, #PARK_PATH - 1 do
		OutdoorProps.pathSegment(park, PARK_PATH[i], PARK_PATH[i + 1], 5, PATH_TOP, O.Path, Enum.Material.Ground)
	end

	-- Pond with a stony edge, a few reeds, benches and plenty of trees (kept
	-- off the path).
	Builder.cylinder(park, "Pond", CFrame.new(POND.X, 0.05, POND.Z), 0.2, 22, O.Water, {
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		CanCollide = false,
	})
	Builder.cylinder(park, "PondEdge", CFrame.new(POND.X, 0.02, POND.Z), 0.15, 24, rgb(150, 140, 120), { Material = Enum.Material.Pebble })
	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2 + hash(i) * 0.4
		local edge = POND + v(math.cos(angle), 0, math.sin(angle)) * 11.6
		OutdoorProps.rock(park, CFrame.new(edge), 300 + i, 0.9)
		if i % 3 == 0 then
			for j = 1, 3 do
				Builder.cylinder(park, "Reed", CFrame.new(edge + v((j - 2) * 0.4, 1.2, 0.6)), 2.4 + j * 0.3, 0.12, rgb(108, 128, 70), { CanCollide = false })
			end
		end
	end
	OutdoorProps.bench(park, facingPoint(113, PATH_TOP, 214, POND.X, POND.Z))
	OutdoorProps.bench(park, facingPoint(138, PATH_TOP, 98, 128, 108))
	OutdoorProps.bench(park, facingPoint(147, PATH_TOP, 252, 150, 262))
	OutdoorProps.flowerBed(park, CFrame.new(76, 0, 75) * CFrame.Angles(0, math.rad(65), 0), 8, 2, 333)
	OutdoorProps.flowerBed(park, CFrame.new(176, 0, 272) * CFrame.Angles(0, math.rad(-30), 0), 7, 2, 334)

	local seed = 300
	for x = PARK.x1 + 8, PARK.x2 - 8, 13 do
		for z = PARK.z1 + 8, PARK.z2 - 8, 13 do
			seed += 1
			local point = v(x + (hash(seed) - 0.5) * 8, 0, z + (hash(seed + 9) - 0.5) * 8)
			local farFromPath = distanceToPath(point) > 9
			local farFromPond = (point - POND).Magnitude > 16
			if farFromPath and farFromPond then
				if hash(seed + 3) < 0.55 then
					OutdoorProps.tree(park, CFrame.new(point), seed)
				elseif hash(seed + 4) < 0.35 then
					OutdoorProps.bush(park, CFrame.new(point), seed)
				end
			end
		end
	end
	OutdoorProps.grassPatches(park, PARK.x1 + 3, PARK.z1 + 3, PARK.x2 - 3, PARK.z2 - 3, 24, 777, function(point)
		return distanceToPath(point) < 5 or (point - POND).Magnitude < 14
	end)

	local _, parkSign = OutdoorProps.signPost(park, facingPoint(76, 0, 69, 70, 50), "Elm Park", rgb(70, 120, 84), 3.4)
	Builder.prompt(parkSign, InteractionType.Inspect, "park_sign", { ActionText = "Read", ObjectText = "Park sign", MaxActivationDistance = 8 })

	-- Quiet: less demand, but the long way round (Data/Zones "park_path").
	Builder.zone(park, "park_path", CFrame.new((PARK.x1 + PARK.x2) / 2, 5, (PARK.z1 + PARK.z2) / 2), v(PARK.x2 - PARK.x1, 10, PARK.z2 - PARK.z1))
end

local function buildPeople(parent: Instance)
	local people = Builder.model(parent, "People")
	-- Riley, waiting for the light at the main crossing (just off the
	-- walking line, so passers-by can get round).
	Npc.spawn(people, "Riley", facingPoint(185.4, SIDEWALK_TOP, 41.4, 192, 50), {
		seed = 83,
		shirt = rgb(200, 132, 150),
		backpack = true,
		npcId = "riley",
		turnRange = 0,
	})
	-- Ms. Dale, the crossing guard by the school.
	Npc.spawn(people, "CrossingGuard", facingPoint(193.4, SIDEWALK_TOP, 293.4, 203, 300), {
		seed = 91,
		adult = true,
		shirt = rgb(206, 220, 72),
		npcId = "crossing_guard",
		turnRange = 0,
	})
end

function Neighborhood.build(parent: Instance, _origin: CFrame, _context)
	local folder = Builder.model(parent, "Neighborhood")
	buildGround(folder)
	buildStreets(folder)
	local lots = buildLots(folder)
	buildNeighbors(folder, lots)
	buildPark(folder)
	buildPeople(folder)

	Builder.waypoint(folder, "main_corner", v(192, 3, 40))
	Builder.waypoint(folder, "school_crossing", v(193, 3, 299))

	-- Everything outdoors; smaller indoor area volumes take priority.
	Builder.areaVolume(
		folder,
		"neighborhood",
		CFrame.new((BOUNDS.minX + BOUNDS.maxX) / 2, 25, (BOUNDS.minZ + BOUNDS.maxZ) / 2),
		v(BOUNDS.maxX - BOUNDS.minX, 50, BOUNDS.maxZ - BOUNDS.minZ)
	)
	return folder
end

return Neighborhood
