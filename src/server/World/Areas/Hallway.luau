--[[
	School hallway.

	Layout (local X runs from the entrance at -56 to the classroom at +56):
		-56        entrance door back home (Travel → "bedroom_door_arrival")
		-50..-22   lockers; the character's locker (Activity "locker_books",
		           with an animated door)
		-34        notice board (Inspect "hallway_noticeboard")
		-18        side opening to the quiet alcove (zone "quiet_alcove")
		-8..26     crowded stretch with students (zone "crowded_hallway")
		+56        double doors into the classroom (open as you approach)
	Destination: "hallway_entrance".

	The player can respond to the crowd through movement: walk straight
	through, put on headphones first, or step into the quiet alcove to
	recover.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Builder = require(script.Parent.Parent.Builder)
local Npc = require(script.Parent.Parent.Npc)
local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)

local at = Builder.at
local facing = Builder.facing
local C = Palette.Colors
local M = Palette.Materials
local InteractionType = World.InteractionTypes

local AREA_ID = "hallway"
local WIDTH, DEPTH, HEIGHT = 112, 16, 12
local NORTH_FACE, SOUTH_FACE = -DEPTH / 2, DEPTH / 2
local LOCKER_Z = NORTH_FACE + 0.7
local OWN_LOCKER_X = -36

-- Crowd: pairs and small groups chatting, placed so a winding path remains.
local CROWD = {
	{ pos = Vector2.new(-4, -5.6), look = Vector2.new(-2.5, -4.6) },
	{ pos = Vector2.new(-2.5, -4.6), look = Vector2.new(-4, -5.6), chatter = "did you finish the—" },
	{ pos = Vector2.new(3.5, 2.8), look = Vector2.new(5, 4) },
	{ pos = Vector2.new(5, 4), look = Vector2.new(3.5, 2.8), chatter = "no way!!" },
	{ pos = Vector2.new(4.5, 6.4), look = Vector2.new(4.2, 3.4) },
	{ pos = Vector2.new(10.5, -3.8), look = Vector2.new(12, -2.4) },
	{ pos = Vector2.new(12, -2.4), look = Vector2.new(10.5, -3.8), chatter = "haha" },
	{ pos = Vector2.new(11.8, -5.8), look = Vector2.new(11.2, -3.2) },
	{ pos = Vector2.new(17.5, 5), look = Vector2.new(19, 3.8), chatter = "wait, what's due?" },
	{ pos = Vector2.new(19, 3.8), look = Vector2.new(17.5, 5) },
	{ pos = Vector2.new(23, -5), look = Vector2.new(24.5, -6.4), chatter = "see you at lunch" },
	{ pos = Vector2.new(24.5, -6.4), look = Vector2.new(23, -5) },
}

local Hallway = {}

local function buildAlcove(room: Instance, origin: CFrame)
	local alcoveOrigin = origin * CFrame.new(-18, 0, SOUTH_FACE + Builder.WALL_THICKNESS + 5)
	local alcove = Builder.room(room, alcoveOrigin, {
		name = "QuietAlcove",
		width = 10,
		depth = 10,
		height = 10,
		floorColor = C.AlcoveFloor,
		floorMaterial = M.Carpet,
		wallColor = C.AlcoveWall,
		trimColor = C.Trim,
		walls = { north = false, south = {}, east = {}, west = {} },
	})

	-- Cushioned bench along the back wall.
	local bench = Builder.model(alcove, "Bench")
	Builder.part(bench, "Seat", at(alcoveOrigin, -0.5, 1.3, 3.9), Vector3.new(5.5, 0.35, 1.7), C.LightWood, { Material = M.Wood })
	for _, x in { -2.9, 1.9 } do
		Builder.part(bench, "Base", at(alcoveOrigin, x, 0.56, 3.9), Vector3.new(0.4, 1.12, 1.5), C.Wood, { Material = M.Wood })
	end
	Builder.part(bench, "Cushion", at(alcoveOrigin, -0.5, 1.6, 3.9), Vector3.new(5.2, 0.25, 1.5), C.Lavender, { Material = M.Fabric })
	Builder.detail(bench, "BackCushion", at(alcoveOrigin, -0.5, 2.5, 4.75) * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(5, 1.4, 0.35), C.Lavender:Lerp(C.Charcoal, 0.15), {
		Material = M.Fabric,
	})

	Props.floorLamp(alcove, at(alcoveOrigin, -4.1, 0, 4.1))
	Props.plant(alcove, at(alcoveOrigin, 3.9, 0, 4.0))
	Props.plant(alcove, at(alcoveOrigin, 3.9, 0, -3.6), 0.8)
	Props.bookshelf(alcove, facing(alcoveOrigin, -4.4, 0, -1.5, Vector3.xAxis), 3.2, 4.2, 1.1, 2, 21)
	Builder.detail(alcove, "Rug", at(alcoveOrigin, 0, 0.03, 0.5), Vector3.new(6, 0.06, 5), C.Rug:Lerp(C.Paper, 0.2), { Material = M.Carpet })
	Props.poster(alcove, facing(alcoveOrigin, 4.94, 5.2, 0.5, -Vector3.xAxis), 2.2, 2.8, C.Teal, 8)
	Builder.ceilingLight(alcove, alcoveOrigin, 0, 0, 10, { length = 2, width = 2, brightness = 0.45, range = 16 })

	Builder.zone(room, "quiet_alcove", at(alcoveOrigin, 0, 5, 0), Vector3.new(9.6, 10, 9.6))
	Builder.areaVolume(room, AREA_ID, at(alcoveOrigin, 0, 5, 0), Vector3.new(10, 10, 10))
end

function Hallway.build(parent: Instance, origin: CFrame, context)
	local room = Builder.room(parent, origin, {
		name = "Hallway",
		width = WIDTH,
		depth = DEPTH,
		height = HEIGHT,
		floorColor = C.HallwayFloor,
		floorMaterial = M.Tiles,
		wallColor = C.HallwayWall,
		wainscot = { height = 3.6, color = C.HallwayWainscot, material = M.Tiles },
		trimColor = C.Trim,
		ceilingGrid = 4,
		walls = {
			-- west/east openings are measured along Z
			west = { { center = 0, width = 5, top = 8 } },
			east = { { center = 0, width = 8, top = 9.5 } },
			south = { { center = -18, width = 8, top = 9 } },
			north = {},
		},
	})
	local details = Builder.model(room, "Details")

	for _, z in { -5.5, 5.5 } do
		Builder.detail(details, "FloorStripe", at(origin, 0, 0.02, z), Vector3.new(WIDTH, 0.04, 0.6), C.HallwayStripe)
	end

	-- Entrance: door home + arrival point.
	local exitDoor = Builder.part(details, "ExitDoor", at(origin, -WIDTH / 2 - 0.5, 3.95, 0), Vector3.new(0.35, 7.9, 4.8), C.Door, {
		Material = M.Wood,
	})
	Builder.detail(details, "PushBar", at(origin, -WIDTH / 2 - 0.27, 3.6, 0), Vector3.new(0.15, 0.25, 3.6), C.Metal, { Material = M.Metal })
	Builder.prompt(exitDoor, InteractionType.Travel, "bedroom_door_arrival", {
		ActionText = "Head home",
		ObjectText = "School exit",
		MaxActivationDistance = 8,
	})
	Builder.sign(details, "ExitSign", facing(origin, -WIDTH / 2 + 0.08, 9.2, 0, Vector3.xAxis), Vector3.new(2.4, 0.8, 0.1), "EXIT", Color3.fromRGB(52, 120, 80), C.Paper)
	Builder.destination(context, "hallway_entrance", AREA_ID, facing(origin, -WIDTH / 2 + 4, 0, 0, Vector3.xAxis))
	-- Fire extinguisher by the exit.
	Builder.cylinder(details, "Extinguisher", at(origin, -WIDTH / 2 + 0.45, 2.4, 4.2), 1.6, 0.5, C.Red)
	Builder.detail(details, "ExtinguisherBracket", at(origin, -WIDTH / 2 + 0.1, 2.2, 4.2), Vector3.new(0.1, 0.5, 0.6), C.DarkMetal)

	-- Lockers along the north wall; the character's locker is an activity.
	local lockers = Builder.model(details, "Lockers")
	Props.lockerBank(lockers, origin, -50, -22, LOCKER_Z, Vector3.zAxis, 1, { OWN_LOCKER_X })
	Props.lockerBank(lockers, origin, 28, 46, LOCKER_Z, Vector3.zAxis, 4)
	local ownLocker, lockerDoor = Props.locker(lockers, facing(origin, OWN_LOCKER_X, 0, LOCKER_Z, Vector3.zAxis), C.OwnLocker, 99, true)
	ownLocker.Name = "YourLocker"
	if lockerDoor then
		Builder.attached(lockerDoor, "Sticker", lockerDoor.CFrame * CFrame.new(0.2, 1.4, -0.06) * CFrame.Angles(0, 0, math.rad(8)), Vector3.new(0.6, 0.6, 0.03), C.Accent)
	end
	local lockerPrompt = Builder.activityPrompt(ownLocker, "locker_books")
	if lockerPrompt and lockerDoor then
		-- The client swings this door open briefly when the locker is used.
		local link = Instance.new("ObjectValue")
		link.Name = "AnimatedDoor"
		link.Value = lockerDoor
		link.Parent = lockerPrompt
	end

	buildAlcove(room, origin)
	Builder.sign(details, "QuietSign", facing(origin, -18, 10.1, SOUTH_FACE - 0.08, -Vector3.zAxis), Vector3.new(5, 1.1, 0.1), "Quiet Space", C.AlcoveWall)

	-- Crowded stretch.
	Builder.zone(room, "crowded_hallway", at(origin, 9, 5, 0), Vector3.new(34, 10, DEPTH))
	local students = Builder.model(room, "Students")
	for index, spec in CROWD do
		local position = at(origin, spec.pos.X, 0, spec.pos.Y).Position
		local lookAt = at(origin, spec.look.X, 0, spec.look.Y).Position
		Npc.spawn(students, `Student{index}`, CFrame.lookAt(position, lookAt), {
			seed = index,
			chatter = spec.chatter,
		})
	end

	-- Classroom doors (decorative), boards, posters and fixtures.
	Props.classroomDoor(details, facing(origin, 6, 3.85, SOUTH_FACE - 0.08, -Vector3.zAxis), "Room 101")
	Props.classroomDoor(details, facing(origin, 34, 3.85, SOUTH_FACE - 0.08, -Vector3.zAxis), "Room 103")
	Props.classroomDoor(details, facing(origin, 14, 3.85, NORTH_FACE + 0.08, Vector3.zAxis), "Room 102")
	local noticeBoard = Props.bulletinBoard(details, facing(origin, -34, 5.6, SOUTH_FACE - 0.08, -Vector3.zAxis), 6, 3, 2)
	Builder.prompt(noticeBoard:FindFirstChild("Frame") :: BasePart, InteractionType.Inspect, "hallway_noticeboard", {
		ActionText = "Read",
		ObjectText = "Notice board",
		MaxActivationDistance = 9,
	})
	-- Bench with a forgotten bag, between the notice board and the posters.
	local bench = Builder.model(details, "Bench")
	Builder.part(bench, "Seat", at(origin, -40, 1.5, SOUTH_FACE - 0.9), Vector3.new(4.4, 0.25, 1.3), C.LightWood, { Material = M.Wood })
	for _, x in { -41.8, -38.2 } do
		Builder.part(bench, "Leg", at(origin, x, 0.7, SOUTH_FACE - 0.9), Vector3.new(0.25, 1.4, 1.1), C.DarkMetal, { Material = M.Metal })
	end
	Props.backpack(bench, facing(origin, -39.2, 1.62, SOUTH_FACE - 0.9, -Vector3.zAxis), C.Yellow)
	Props.bulletinBoard(details, facing(origin, 46, 5.6, SOUTH_FACE - 0.08, -Vector3.zAxis), 5, 2.6, 6)
	Props.poster(details, facing(origin, -46, 5.8, SOUTH_FACE - 0.06, -Vector3.zAxis), 2.4, 3, C.Blue, 4)
	Props.poster(details, facing(origin, 22, 5.8, SOUTH_FACE - 0.06, -Vector3.zAxis), 2.4, 3, C.Yellow, 7)
	Props.poster(details, facing(origin, 4, 5.8, NORTH_FACE + 0.06, Vector3.zAxis), 2.2, 2.8, C.Green, 9)
	Props.clock(details, facing(origin, 0, 9.4, SOUTH_FACE - 0.1, -Vector3.zAxis))
	Props.bin(details, at(origin, -27, 0, SOUTH_FACE - 1.1))
	Props.bin(details, at(origin, 40, 0, SOUTH_FACE - 1.1))

	local fountain = Builder.model(details, "Fountain")
	Builder.part(fountain, "Basin", at(origin, -15, 3, NORTH_FACE + 0.6), Vector3.new(1.6, 0.6, 1.2), C.Metal, { Material = M.Metal })
	Builder.detail(fountain, "Pedestal", at(origin, -15, 1.35, NORTH_FACE + 0.35), Vector3.new(0.6, 2.7, 0.6), C.DarkMetal)
	Builder.detail(fountain, "Spout", at(origin, -15, 3.4, NORTH_FACE + 0.35), Vector3.new(0.15, 0.25, 0.3), C.DarkMetal)

	-- Double doors into the classroom; they swing open (into the room) as
	-- the player approaches (client Doors controller).
	for _, side in { -1, 1 } do
		local hinge = facing(origin, WIDTH / 2 + 0.5, 4.7, side * 4, Vector3.xAxis)
		local leaf = Builder.hingedLeaf(details, "ClassroomDoor", hinge, Vector3.new(3.95, 9.4, 0.2), C.Door, -side, side * -95, {
			Material = M.Wood,
		})
		CollectionService:AddTag(leaf, World.Tags.AutoDoor)
		Builder.attached(leaf, "Window", leaf.CFrame * CFrame.new(0, 1.6, 0), Vector3.new(1.3, 2.4, 0.24), C.Glass, {
			Material = M.Glass,
			Transparency = 0.35,
		})
		Builder.attached(leaf, "PushPlate", leaf.CFrame * CFrame.new(-side * 1.3, -0.4, 0), Vector3.new(0.35, 1.0, 0.26), C.Metal, {
			Material = M.Metal,
		})
	end

	-- Classroom entrance sign.
	Builder.sign(details, "ClassroomSign", facing(origin, WIDTH / 2 - 0.1, 10.7, 0, -Vector3.xAxis), Vector3.new(6, 1.2, 0.1), "Room 104", C.Sign)

	Builder.areaVolume(room, AREA_ID, at(origin, 0, HEIGHT / 2, 0), Vector3.new(WIDTH, HEIGHT, DEPTH))

	-- Ceiling lights; every other one casts shadows to keep cost down.
	local index = 0
	for x = -49, 49, 14 do
		index += 1
		Builder.ceilingLight(room, origin, x, 0, HEIGHT, {
			length = 4,
			width = 1.6,
			brightness = 0.7,
			range = 22,
			shadows = index % 2 == 0,
		})
	end

	return room
end

return Hallway
