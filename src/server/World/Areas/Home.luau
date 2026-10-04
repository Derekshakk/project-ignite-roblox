--[[
	Home — the front hall and the outside of Alex's house.

	Built in the same frame as the bedroom (origin = the bedroom's floor
	centre). The bedroom door (south wall, x = 8) opens into a small front
	hall; the front door at the end of it opens onto the porch, and a path
	leads down to the street (see Neighborhood).

	Interaction points:
		front door → Door "house_front_door" (closes by itself)
	Area: "home" (the front hall).

	The house exterior is cladding around the rooms' footprint, with gable
	roofs (the main block's ridge runs east–west; the front-hall wing has
	its own street-facing gable), a gabled porch, trim and gutters, so the
	interiors are untouched.
]]

local Builder = require(script.Parent.Parent.Builder)
local OutdoorProps = require(script.Parent.Parent.OutdoorProps)
local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)

local at = Builder.at
local facing = Builder.facing
local C = Palette.Colors
local M = Palette.Materials
local O = OutdoorProps.Colors
local rgb = Color3.fromRGB

local HALL_WIDTH, HALL_DEPTH, HALL_HEIGHT = 12, 12, 10
local HALL_CENTER = Vector2.new(8, 17)
local FRONT_DOOR_COLOR = rgb(64, 96, 124)

local Home = {}

local function buildHall(parent: Instance, origin: CFrame)
	local hallOrigin = origin * CFrame.new(HALL_CENTER.X, 0, HALL_CENTER.Y)
	local hall = Builder.room(parent, hallOrigin, {
		name = "FrontHall",
		width = HALL_WIDTH,
		depth = HALL_DEPTH,
		height = HALL_HEIGHT,
		floorColor = C.LightWood,
		floorMaterial = M.WoodPlanks,
		wallColor = rgb(214, 204, 186),
		trimColor = C.OffWhite,
		-- The bedroom's south wall (with its door) closes the north side.
		walls = { north = false, south = { { center = 0, width = 5, top = 8 } }, east = {}, west = {} },
	})
	local furniture = Builder.model(hall, "Furniture")

	-- Shoe bench and coat hooks along the west wall.
	Builder.part(furniture, "ShoeBench", at(hallOrigin, -5.3, 0.9, -1), Vector3.new(1.3, 1.8, 4.5), C.Wood, { Material = M.Wood })
	for i, color in { C.Red, C.Blue, C.Charcoal } do
		Builder.detail(furniture, "Shoes", at(hallOrigin, -5.3, 0.15, -2.8 + i * 1.1), Vector3.new(0.9, 0.3, 0.5), color)
	end
	Builder.detail(furniture, "HookRail", at(hallOrigin, -5.9, 6, -1), Vector3.new(0.2, 0.3, 4), C.DarkWood)
	for i, color in { C.Green, C.Purple } do
		Builder.detail(furniture, "Jacket", at(hallOrigin, -5.6, 4.6, -2.2 + i * 1.4), Vector3.new(0.5, 2.6, 1.1), color, { Material = M.Fabric })
	end
	-- Side table with a key bowl, and a mirror, on the east wall.
	Builder.part(furniture, "SideTable", at(hallOrigin, 5.2, 1.4, -3.5), Vector3.new(1.4, 0.2, 3), C.LightWood, { Material = M.Wood })
	for _, z in { -4.7, -2.3 } do
		Builder.detail(furniture, "Leg", at(hallOrigin, 5.2, 0.65, z), Vector3.new(0.2, 1.3, 0.2), C.DarkWood)
	end
	Builder.cylinder(furniture, "KeyBowl", at(hallOrigin, 5.2, 1.6, -3.9), 0.2, 0.9, C.Teal)
	Builder.detail(furniture, "Mirror", at(hallOrigin, 5.92, 5, -3.5), Vector3.new(0.1, 3, 2), C.Glass:Lerp(C.OffWhite, 0.4), {
		Material = M.Glass,
	})
	Builder.detail(hall, "Runner", at(hallOrigin, 0, 0.03, -1), Vector3.new(3.4, 0.06, 8), C.Rug:Lerp(C.Red, 0.4), { Material = M.Carpet })
	Props.plant(furniture, at(hallOrigin, 4.9, 0, 4.6), 0.8)
	Builder.ceilingLight(hall, hallOrigin, 0, -1, HALL_HEIGHT, { length = 2, width = 2, brightness = 0.6, range = 16 })

	-- Front door: swings into the hall, away from the furniture.
	local door = Builder.door(furniture, {
		name = "FrontDoor",
		hinge = at(origin, 10.4, 3.95, 23.5),
		size = Vector3.new(4.8, 7.9, 0.35),
		color = FRONT_DOOR_COLOR,
		side = -1,
		openAngle = -80,
		doorId = "house_front_door",
		objectText = "Front door",
		autoClose = 8,
	})
	for _, offset in { -1.9, 1.9 } do
		Builder.attached(door, "DoorPanel", at(origin, 8, 3.95 + offset, 23.31), Vector3.new(3.4, 2.8, 0.05), FRONT_DOOR_COLOR:Lerp(C.Charcoal, 0.2))
	end
	for _, z in { 23.22, 23.78 } do
		Builder.attached(door, "DoorKnob", at(origin, 6.2, 3.8, z), Vector3.new(0.35, 0.35, 0.35), C.Metal, {
			Shape = Enum.PartType.Ball,
			Material = M.Metal,
		})
	end

	Builder.areaVolume(hall, "home", at(hallOrigin, 0, HALL_HEIGHT / 2, 0), Vector3.new(HALL_WIDTH, HALL_HEIGHT, HALL_DEPTH))
end

local function buildExterior(parent: Instance, origin: CFrame)
	local exterior = Builder.model(parent, "HouseExterior")
	local function p(x: number, z: number): Vector2
		local world = origin * Vector3.new(x, 0, z)
		return Vector2.new(world.X, world.Z)
	end
	-- Footprint: bedroom (x ±15, z ±12) plus the front hall (x 1..15, z 12..24).
	Builder.cladding(exterior, { p(-15, -12), p(15, -12), p(15, 24), p(1, 24), p(1, 12), p(-15, 12) }, {
		name = "Siding",
		color = O.Siding,
		material = Enum.Material.WoodPlanks,
		height = { 13.6, 13.6, 12.4, 12.4, 13.6, 13.6 },
		openings = {
			[1] = { { at = (origin * Vector3.new(3, 0, 0)).X, width = 8.2, bottom = 3.9, top = 9.1 } }, -- bedroom window
			[3] = { { at = (origin * Vector3.new(8, 0, 0)).X, width = 5.8, bottom = 0, top = 8.4 } }, -- front door
		},
		windows = {
			[2] = { { at = (origin * Vector3.new(0, 0, -4)).Z, width = 4, bottom = 4, top = 8 } },
			[4] = { { at = (origin * Vector3.new(0, 0, 18)).Z, width = 3, bottom = 4, top = 8 } },
			[5] = { { at = (origin * Vector3.new(-7, 0, 0)).X, width = 5, bottom = 4, top = 8 } },
			[6] = { { at = (origin * Vector3.new(0, 0, 0)).Z, width = 5, bottom = 4, top = 8 } },
		},
	})
	-- Flat roof slabs close the tops of the walls; the pitched roofs sit on
	-- top of them. Main block: x -16..16, z -13..13 (outer faces), walls to
	-- y 13.8. Front-hall wing: x 0..16, z 12..25, walls to y 12.6.
	local trim = C.OffWhite
	Builder.part(exterior, "Roof", origin * CFrame.new(0, 12.6, 0), Vector3.new(30, 0.8, 24), O.Roof)
	Builder.part(exterior, "HallRoof", origin * CFrame.new(8, 11.6, 18), Vector3.new(14, 0.8, 12), O.Roof)
	Builder.gableRoof(exterior, origin * CFrame.new(0, 13.8, 0), {
		name = "MainRoof",
		length = 32,
		span = 26,
		rise = 6,
		eave = 1.3,
		rake = 1.0,
		color = O.Roof,
		gableColor = O.Siding,
		trimColor = trim,
		gutterColor = trim,
		-- The south eave meets the wing roof; it gets a shorter gutter below.
		gutterSides = { -1 },
	})
	Builder.detail(exterior, "Gutter", origin * CFrame.new(-8.5, 13.0, 14.42), Vector3.new(17, 0.42, 0.42), trim, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
	-- The wing's own cross-gable over the front hall; its back gable sits
	-- on the main roof's slope like a dormer.
	Builder.gableRoof(exterior, origin * CFrame.new(8, 12.6, 18.5) * CFrame.Angles(0, math.pi / 2, 0), {
		name = "WingRoof",
		length = 13,
		span = 16,
		rise = 4.6,
		eave = 1.0,
		rake = 1.2,
		color = O.Roof,
		gableColor = O.Siding,
		trimColor = trim,
		gutterColor = trim,
	})
	Builder.part(exterior, "Chimney", origin * CFrame.new(-9, 17, -6), Vector3.new(2.6, 10, 2.6), O.Brick, { Material = Enum.Material.Brick })
	Builder.detail(exterior, "ChimneyCap", origin * CFrame.new(-9, 22.2, -6), Vector3.new(3.1, 0.4, 3.1), C.Charcoal)

	-- Foundation band and corner boards.
	local function band(x1: number, z1: number, x2: number, z2: number)
		Builder.detail(exterior, "Foundation", origin * CFrame.new((x1 + x2) / 2, 0.45, (z1 + z2) / 2), Vector3.new(math.max(x2 - x1, 0.2), 0.9, math.max(z2 - z1, 0.2)), O.Sidewalk, {
			Material = Enum.Material.Concrete,
		})
	end
	band(-16.15, -13.15, 16.15, -12.95) -- north
	band(-16.15, -13, -15.95, 13) -- west
	band(15.95, -13, 16.15, 25) -- east
	band(-16, 12.95, 0, 13.15) -- south, west of the wing
	band(-0.15, 13, 0.05, 25) -- wing, west face
	band(0, 24.95, 5.1, 25.15) -- wing front, either side of the door
	band(10.9, 24.95, 16, 25.15)
	for _, corner in { { -16, -13, 13.6 }, { 16, -13, 13.6 }, { -16, 13, 13.6 }, { 0, 25, 12.4 }, { 16, 25, 12.4 } } do
		Builder.detail(exterior, "CornerBoard", origin * CFrame.new(corner[1], corner[3] / 2 + 0.2, corner[2]), Vector3.new(0.6, corner[3], 0.6), trim)
	end
	for _, spout in { { -16.3, 13.3, 13.6 }, { 16.3, 25.3, 12.4 } } do
		Builder.detail(exterior, "Downspout", origin * CFrame.new(spout[1], spout[3] / 2, spout[2]), Vector3.new(0.32, spout[3], 0.32), trim)
	end

	-- Front door surround, porch light and house number.
	for _, x in { 4.85, 11.15 } do
		Builder.detail(exterior, "DoorCasing", origin * CFrame.new(x, 4.4, 25.1), Vector3.new(0.5, 8.6, 0.22), trim)
	end
	Builder.detail(exterior, "DoorHead", origin * CFrame.new(8, 8.9, 25.12), Vector3.new(7.0, 0.55, 0.26), trim)
	Builder.detail(exterior, "LampBracket", origin * CFrame.new(3.6, 6.6, 25.15), Vector3.new(0.3, 0.5, 0.24), C.DarkMetal)
	Builder.detail(exterior, "LampGlass", origin * CFrame.new(3.6, 6.5, 25.45), Vector3.new(0.42, 0.6, 0.42), rgb(240, 222, 170), {
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	Builder.sign(exterior, "HouseNumber", CFrame.lookAt((origin * CFrame.new(13.2, 6.6, 25.1)).Position, (origin * CFrame.new(13.2, 6.6, 30)).Position), Vector3.new(1.4, 0.6, 0.08), "12", rgb(46, 48, 52), rgb(226, 214, 180))

	-- Shutters and a window box on the street-facing window.
	for _, x in { -10.65, -3.35 } do
		Builder.detail(exterior, "Shutter", origin * CFrame.new(x, 6.2, 13.18), Vector3.new(1.8, 4.6, 0.12), rgb(52, 70, 96))
	end
	Builder.detail(exterior, "WindowBox", origin * CFrame.new(-7, 3.5, 13.45), Vector3.new(5.6, 0.6, 0.6), C.Wood)
	for i = 0, 5 do
		Builder.detail(exterior, "Flowers", origin * CFrame.new(-9.4 + i * 0.96, 4.0, 13.45), Vector3.new(0.62, 0.62, 0.62), Palette.pick({ rgb(214, 96, 104), rgb(236, 196, 90), rgb(232, 150, 170), C.Green }, i + 1), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Grass,
		})
	end

	-- Porch with a small gabled roof on two posts, and the path down to
	-- the sidewalk.
	OutdoorProps.slab(exterior, "Porch", 3, 24, 13, 29, Builder.FLOOR_TOP, O.Sidewalk, Enum.Material.Concrete)
	Builder.gableRoof(exterior, origin * CFrame.new(8, 9.6, 27.0) * CFrame.Angles(0, math.pi / 2, 0), {
		name = "PorchRoof",
		length = 4.4,
		span = 8,
		rise = 1.8,
		eave = 0.4,
		rake = 0.3,
		thickness = 0.35,
		color = O.Roof,
		gableColor = trim,
		gableEnds = { -1 },
	})
	for _, x in { 4.6, 11.4 } do
		Builder.cylinder(exterior, "PorchPost", origin * CFrame.new(x, 4.9, 28.6), 9.4, 0.45, trim)
		Builder.detail(exterior, "PostBase", origin * CFrame.new(x, 0.6, 28.6), Vector3.new(0.8, 0.8, 0.8), trim)
	end
	OutdoorProps.slab(exterior, "FrontPath", 6.5, 29, 9.5, 37, Builder.FLOOR_TOP, O.Sidewalk, Enum.Material.Concrete)

	-- Front yard: a picket fence with a garden gate at the path, mailbox,
	-- lawn, flower bed and shrubs.
	OutdoorProps.fence(exterior, origin * Vector3.new(-15, 0, 35), origin * Vector3.new(15, 0, 35), C.OffWhite, { gate = { at = 21, width = 4, swing = 80 } })
	OutdoorProps.mailbox(exterior, facing(origin, 12, -Builder.FLOOR_TOP, 36, Vector3.zAxis), C.Blue)
	OutdoorProps.lawn(exterior, -15, 26, 6.2, 34.6, 12)
	OutdoorProps.flowerBed(exterior, origin * CFrame.new(-8, 0, 14.4), 14, 1.6, 15)
	OutdoorProps.bush(exterior, origin * CFrame.new(-1.6, 0, 19), 16)
	OutdoorProps.bush(exterior, origin * CFrame.new(-1.6, 0, 23), 17)
	OutdoorProps.tree(exterior, origin * CFrame.new(-8, 0, 29), 3)
	Props.plant(exterior, origin * CFrame.new(2.4, Builder.FLOOR_TOP, 26.5), 0.9)
	Props.plant(exterior, origin * CFrame.new(13.6, Builder.FLOOR_TOP, 26.5), 0.9)
end

function Home.build(parent: Instance, origin: CFrame, _context)
	local home = Builder.model(parent, "Home")
	buildHall(home, origin)
	buildExterior(home, origin)
	return home
end

return Home
