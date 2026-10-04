--[[
	SchoolExterior — the outside of Westbrook High.

	Brick cladding around the footprint of the hallway, the classroom and
	the quiet alcove (so the interiors are untouched), flat roofs, the
	entrance canopy and sign, and the forecourt the walk from School Road
	arrives at. Positioned from the hallway's origin (WorldBuilder), so the
	school can move without editing this file.

	The entrance doors themselves are part of the hallway (Hallway.luau,
	Door "school_entrance").

	Interaction points: Inspect "school_sign" (the letter board).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Builder = require(script.Parent.Parent.Builder)
local Npc = require(script.Parent.Parent.Npc)
local OutdoorProps = require(script.Parent.Parent.OutdoorProps)
local Palette = require(script.Parent.Parent.Palette)
local Vehicles = require(script.Parent.Parent.Vehicles)

local C = Palette.Colors
local O = OutdoorProps.Colors
local InteractionType = World.InteractionTypes
local rgb = Color3.fromRGB

local SchoolExterior = {}

function SchoolExterior.build(parent: Instance, hallwayOrigin: CFrame, _context)
	local model = Builder.model(parent, "SchoolExterior")
	local hx, hz = hallwayOrigin.X, hallwayOrigin.Z
	local function p(x: number, z: number): Vector2
		return Vector2.new(hx + x, hz + z)
	end
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(hx + x, y, hz + z)
	end

	-- Footprint (outer faces of the interior walls), relative to the
	-- hallway origin: hallway x ±57 z ±9; classroom x 56..90 z ±16;
	-- alcove x -24..-12 z 9..20.
	local footprint = {
		p(-57, -9), p(56, -9), p(56, -16), p(90, -16), p(90, 16), p(56, 16),
		p(56, 9), p(-12, 9), p(-12, 20), p(-24, 20), p(-24, 9), p(-57, 9),
	}
	local tall, low = 14.6, 12.4
	local hallwayWindows = {}
	for x = -40, 40, 14 do
		table.insert(hallwayWindows, { at = hx + x, width = 5, bottom = 4.5, top = 9 })
	end
	Builder.cladding(model, footprint, {
		name = "Brick",
		color = O.Brick,
		material = Enum.Material.Brick,
		height = { tall, tall, tall, tall, tall, tall, tall, low, low, low, tall, tall },
		openings = {
			-- Real classroom windows (north wall), and the entrance.
			[3] = {
				{ at = hx + 73, width = 6.2, bottom = 3.9, top = 9.1 },
				{ at = hx + 82, width = 6.2, bottom = 3.9, top = 9.1 },
			},
			[12] = { { at = hz, width = 5.8, bottom = 0, top = 8.4 } },
		},
		windows = {
			[1] = hallwayWindows,
			[4] = { { at = hz - 7, width = 5, bottom = 4.5, top = 9 }, { at = hz + 7, width = 5, bottom = 4.5, top = 9 } },
			[11] = { { at = hx - 40, width = 5, bottom = 4.5, top = 9 } },
			[12] = { { at = hz - 6, width = 3, bottom = 4.5, top = 9 }, { at = hz + 6, width = 3, bottom = 4.5, top = 9 } },
		},
	})
	Builder.part(model, "HallwayRoof", CFrame.new(v(0, 13.6, 0)), Vector3.new(114, 0.8, 18), O.Roof)
	Builder.part(model, "ClassroomRoof", CFrame.new(v(73, 13.62, 0)), Vector3.new(34, 0.8, 32), O.Roof)
	Builder.part(model, "AlcoveRoof", CFrame.new(v(-18, 11.6, 14.5)), Vector3.new(12, 0.8, 11), O.Roof)

	-- Entrance: canopy, sign, and a forecourt down to School Road.
	local front = hx - 57 - Builder.WALL_THICKNESS -- outer face of the cladding
	Builder.part(model, "Canopy", CFrame.new(front - 4, 9.4, hz), Vector3.new(8, 0.4, 11), O.Roof)
	for _, z in { -5, 5 } do
		Builder.cylinder(model, "CanopyPost", CFrame.new(front - 7.4, 4.8, hz + z), 9.2, 0.45, C.Metal, { Material = Enum.Material.Metal })
	end
	Builder.sign(model, "SchoolName", CFrame.lookAt(Vector3.new(front - 0.08, 11.6, hz), Vector3.new(front - 10, 11.6, hz)), Vector3.new(18, 2, 0.12), "WESTBROOK HIGH SCHOOL", rgb(40, 52, 80), C.Paper)

	local forecourtStart = 216 -- east edge of School Road's sidewalk
	OutdoorProps.slab(model, "Forecourt", forecourtStart, hz - 16, front + 1, hz + 16, Builder.FLOOR_TOP, O.Sidewalk, Enum.Material.Concrete)

	-- Letter board by the crossing (inspect).
	local board = Builder.model(model, "LetterBoard")
	for _, z in { -2.4, 2.4 } do
		Builder.part(board, "Post", CFrame.new(222, 2, hz - 12 + z), Vector3.new(0.4, 4, 0.4), C.DarkMetal)
	end
	local boardSign = Builder.sign(board, "Board", CFrame.lookAt(Vector3.new(222, 4.2, hz - 12), Vector3.new(210, 4.2, hz - 12)), Vector3.new(6, 2.4, 0.3), "WELCOME BACK", rgb(32, 36, 44), C.Paper)
	board:SetAttribute(World.Attributes.InteractModel, true)
	Builder.prompt(boardSign, InteractionType.Inspect, "school_sign", { ActionText = "Read", ObjectText = "School sign", MaxActivationDistance = 9 })

	-- Flagpole, bike rack, benches, trees.
	Builder.cylinder(model, "Flagpole", CFrame.new(236, 11, hz + 12), 22, 0.4, C.Metal, { Material = Enum.Material.Metal })
	-- The flag is three segments the client ripples gently (WorldMotion).
	local flag = Builder.model(model, "Flag")
	local hoist = CFrame.lookAt(Vector3.new(236, 20.2, hz + 12.2), Vector3.new(236, 20.2, hz + 20))
	for i = 1, 3 do
		Builder.detail(flag, `Segment{i}`, hoist * CFrame.new(0, 0, -(i - 0.5)), Vector3.new(0.08, 2, 1.02), rgb(64, 96, 150))
	end
	Builder.detail(flag, "Stripe", hoist * CFrame.new(0, 0, -0.5), Vector3.new(0.1, 0.5, 0.9), rgb(214, 176, 72))
	OutdoorProps.motion(flag, "flutter", { MotionPivot = hoist, MotionAmount = 14 })
	Builder.detail(model, "Finial", CFrame.new(236, 22.2, hz + 12), Vector3.new(0.6, 0.6, 0.6), C.Yellow, { Shape = Enum.PartType.Ball, Material = Enum.Material.Metal })
	for i = 0, 4 do
		Builder.detail(model, "BikeRack", CFrame.new(252 + i * 1.6, 1.2, hz + 13), Vector3.new(0.15, 1.8, 1.6), C.DarkMetal)
	end
	OutdoorProps.bench(model, CFrame.lookAt(Vector3.new(246, Builder.FLOOR_TOP, hz - 13.5), Vector3.new(246, Builder.FLOOR_TOP, hz)))
	local seed = 700
	for _, offset in { { 228, -22 }, { 248, -22 }, { 266, -22 }, { 228, 22 }, { 250, 22 }, { 266, 22 } } do
		seed += 1
		OutdoorProps.tree(model, CFrame.new(offset[1], 0, hz + offset[2]), seed)
	end

	-- Parking lot and field north of the school.
	OutdoorProps.slab(model, "ParkingLot", 226, 180, 372, 262, 0.05, O.Asphalt, Enum.Material.Asphalt)
	for x = 232, 366, 8 do
		Builder.detail(model, "Bay", CFrame.new(x, 0.08, 199), Vector3.new(0.3, 0.04, 10), O.Stripe)
		Builder.detail(model, "Bay", CFrame.new(x, 0.08, 243), Vector3.new(0.3, 0.04, 10), O.Stripe)
	end
	local carColors = { rgb(70, 96, 140), rgb(196, 196, 190), rgb(160, 60, 56), rgb(60, 62, 70), rgb(140, 120, 90) }
	for i, x in { 236, 260, 292, 324, 348 } do
		OutdoorProps.car(model, CFrame.lookAt(Vector3.new(x, 0.05, if i % 2 == 0 then 199 else 243), Vector3.new(x, 0.05, 220)), carColors[i], Vehicles.styleFor(i))
	end

	-- A few students hanging around before the bell.
	local people = Builder.model(model, "Students")
	Npc.spawn(people, "Student_Forecourt1", CFrame.lookAt(Vector3.new(250, Builder.FLOOR_TOP, hz - 8), Vector3.new(252, Builder.FLOOR_TOP, hz - 6.4)), {
		seed = 121,
		chatter = { "Did you finish the reading?", "I'm so not ready for the quiz." },
	})
	Npc.spawn(people, "Student_Forecourt2", CFrame.lookAt(Vector3.new(252, Builder.FLOOR_TOP, hz - 6.4), Vector3.new(250, Builder.FLOOR_TOP, hz - 8)), {
		seed = 122,
		chatter = { "Same.", "We could study at lunch?" },
	})
	Npc.spawn(people, "Student_Forecourt3", CFrame.lookAt(Vector3.new(260, Builder.FLOOR_TOP, hz + 9), Vector3.new(262, Builder.FLOOR_TOP, hz + 2)), {
		seed = 123,
		talkative = false,
	})
	return model
end

return SchoolExterior
