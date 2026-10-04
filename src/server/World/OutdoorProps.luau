--[[
	OutdoorProps

	Street, yard and park dressing for the walk to school. Like Props, each
	function builds a small model at a floor CFrame (facing its
	LookVector). Shapes are softened with cylinders, wedges and stretched
	spheres instead of plain boxes, and part counts stay low:
	- details never collide or cast shadows (Builder.detail); long things
	  like fences collide through one invisible box
	- things that move (tree canopies, a sprinkler arm, a garden gate, a
	  dog's tail) are only tagged; the client's WorldMotion animates them,
	  so there are no scripts per object
	- far-away trees (options.far) use fewer parts and don't sway

	Houses live in Houses.luau and cars in Vehicles.luau.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Builder = require(script.Parent.Builder)
local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)
local Vehicles = require(script.Parent.Vehicles)

local Colors = Palette.Colors
local Materials = Palette.Materials
local Attributes = World.Attributes
local detail = Builder.detail
local hash = Props.hash
local rgb = Color3.fromRGB

local OutdoorProps = {}

OutdoorProps.Colors = table.freeze({
	Grass = rgb(104, 142, 86),
	GrassDark = rgb(88, 124, 74),
	GrassLight = rgb(122, 156, 94),
	Lawn = rgb(98, 146, 82),
	Leaves = rgb(84, 128, 74),
	LeavesLight = rgb(118, 152, 82),
	LeavesWarm = rgb(150, 150, 76),
	LeavesDeep = rgb(62, 104, 66),
	Conifer = rgb(52, 92, 64),
	Trunk = rgb(96, 72, 54),
	Hedge = rgb(70, 112, 66),
	Asphalt = rgb(70, 72, 78),
	AsphaltPatch = rgb(78, 80, 86),
	Sidewalk = rgb(176, 172, 164),
	Curb = rgb(158, 154, 148),
	Gutter = rgb(96, 96, 100),
	Driveway = rgb(164, 160, 152),
	Path = rgb(168, 146, 112),
	Mulch = rgb(92, 66, 48),
	LaneLine = rgb(222, 196, 92),
	Stripe = rgb(226, 224, 216),
	Brick = rgb(156, 88, 70),
	Siding = rgb(150, 176, 196),
	Roof = rgb(74, 70, 72),
	Water = rgb(86, 132, 156),
	Iron = rgb(56, 58, 62),
})
local C = OutdoorProps.Colors

local FLOWER_COLORS = {
	rgb(214, 96, 104),
	rgb(236, 196, 90),
	rgb(170, 120, 200),
	rgb(232, 150, 170),
	rgb(240, 236, 220),
	rgb(226, 132, 72),
}

local function rotY(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- Tags a part (or model) for the client's WorldMotion.
local function motion(instance: Instance, kind: string, attributes: { [string]: any }?)
	instance:SetAttribute(Attributes.Motion, kind)
	for key, value in attributes or {} do
		instance:SetAttribute(key, value)
	end
	CollectionService:AddTag(instance, World.Tags.AmbientMotion)
end
OutdoorProps.motion = motion

-- Invisible collision box between two ground points.
local function collider(parent: Instance, from: Vector3, to: Vector3, height: number, thickness: number)
	local middle = (from + to) / 2 + Vector3.new(0, height / 2, 0)
	return Builder.part(parent, "Collision", CFrame.lookAt(middle, to + Vector3.new(0, height / 2, 0)), Vector3.new(thickness, height, (to - from).Magnitude), C.Grass, {
		Transparency = 1,
		CastShadow = false,
		CanQuery = false,
	})
end

---------------------------------------------------------------------------
-- Plants
---------------------------------------------------------------------------

--[[
	A tree, varied by seed: a tapered trunk with a root flare and branch
	stubs under a canopy of 3–5 overlapping rounded clumps, or (about one in
	six) a conifer of stacked tiers. Canopies sway gently on the client.
	Options: far (boolean) — boundary trees: two clumps, no sway.
]]
function OutdoorProps.tree(parent: Instance, floor: CFrame, seed: number, scale: number?, options: { [string]: any }?)
	local opts = options or {}
	local s = (scale or 1) * (0.85 + hash(seed) * 0.35)
	local model = Builder.model(parent, "Tree")
	local far = opts.far == true
	local conifer = opts.conifer or (not far and hash(seed + 11) < 0.17)
	local trunkHeight = (if conifer then 3.2 else 6) * s

	if far then
		Builder.cylinder(model, "Trunk", floor * CFrame.new(0, trunkHeight / 2, 0), trunkHeight, 1.1 * s, C.Trunk, { Material = Materials.Wood })
	else
		Builder.cylinder(model, "Trunk", floor * CFrame.new(0, trunkHeight * 0.3, 0), trunkHeight * 0.6, 1.25 * s, C.Trunk, { Material = Materials.Wood })
		detail(model, "Trunk", floor * CFrame.new(0, trunkHeight * 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(trunkHeight * 0.55, 0.85 * s, 0.85 * s), C.Trunk, {
			Shape = Enum.PartType.Cylinder,
			Material = Materials.Wood,
		})
		detail(model, "RootFlare", floor * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.5, 1.9 * s, 1.9 * s), C.Trunk:Lerp(C.Mulch, 0.3), {
			Shape = Enum.PartType.Cylinder,
			Material = Materials.Wood,
		})
	end

	local pivot = floor * Vector3.new(0, trunkHeight, 0)
	local function clump(name: string, offset: Vector3, size: Vector3, color: Color3, sway: number)
		local part = Builder.ellipsoid(model, name, floor * CFrame.new(offset) * rotY(hash(seed + offset.X) * 180), size, color, {
			Material = Materials.Grass,
			CanCollide = false,
		})
		if not far then
			motion(part, "sway", { [Attributes.MotionPivot] = pivot, [Attributes.MotionAmount] = sway })
		end
		return part
	end

	if conifer then
		local color = C.Conifer:Lerp(C.LeavesDeep, hash(seed + 4) * 0.5)
		local tiers = { { 7.0, 3.6, 0.0 }, { 5.6, 3.4, 2.4 }, { 4.2, 3.2, 4.6 }, { 2.6, 3.0, 6.6 } }
		for i, tier in tiers do
			local width, height, y = tier[1] * s, tier[2] * s, tier[3] * s
			clump("Leaves", Vector3.new(0, trunkHeight + y, 0), Vector3.new(width, height, width), color:Lerp(C.Leaves, i * 0.05), 0.6 + i * 0.25)
		end
		return model
	end

	local palette = { C.Leaves, C.LeavesLight, C.LeavesWarm, C.LeavesDeep }
	local base = palette[(seed % #palette) + 1]
	local count = if far then 2 else 3 + seed % 3
	for i = 1, count do
		local r = hash(seed * 3 + i)
		local width = (5.4 + r * 2.6) * s
		local angle = (i / count) * math.pi * 2 + hash(seed + 5) * 6
		local spread = if i == 1 then 0 else 1.7 * s
		local offset = Vector3.new(math.cos(angle) * spread, trunkHeight + width * 0.32 + (if i == 1 then 1.2 * s else (r - 0.3) * 1.6 * s), math.sin(angle) * spread)
		clump("Leaves", offset, Vector3.new(width, width * (0.72 + r * 0.16), width * (0.92 + r * 0.12)), base:Lerp(C.GrassDark, r * 0.35), 1.0 + r * 0.6)
	end
	if not far then
		-- Branch stubs reaching into the canopy.
		for i = 1, 2 do
			local angle = hash(seed + i * 13) * math.pi * 2
			local from = floor * Vector3.new(0, trunkHeight * 0.7, 0)
			local to = floor * Vector3.new(math.cos(angle) * 1.9 * s, trunkHeight + 0.6 * s, math.sin(angle) * 1.9 * s)
			Builder.beam(model, "Branch", from, to, 0.42 * s, 0.42 * s, C.Trunk, { Material = Materials.Wood, CanCollide = false, CastShadow = false })
		end
	end
	return model
end

-- A rounded shrub of two or three clumps.
function OutdoorProps.bush(parent: Instance, floor: CFrame, seed: number, scale: number?)
	local s = (scale or 1) * (0.8 + hash(seed + 2) * 0.4)
	local model = Builder.model(parent, "Bush")
	local color = ({ C.Hedge, C.Leaves, C.LeavesDeep, C.LeavesLight })[(seed % 4) + 1]
	for i = 1, 2 + seed % 2 do
		local r = hash(seed * 7 + i)
		local size = Vector3.new(2.4 + r * 1.2, 1.8 + r * 0.8, 2.2 + r * 1.0) * s
		local offset = Vector3.new((r - 0.5) * 1.6 * s, size.Y * 0.42, (hash(seed + i) - 0.5) * 1.2 * s)
		Builder.ellipsoid(model, "Bush", floor * CFrame.new(offset), size, color:Lerp(C.GrassDark, r * 0.3), {
			Material = Materials.Grass,
			CanCollide = false,
			CastShadow = i == 1,
		})
	end
	return model
end

--[[
	A mulched bed with clumps of flowers. `center` is the bed's centre on
	the ground; it runs along the CFrame's local X.
]]
function OutdoorProps.flowerBed(parent: Instance, center: CFrame, length: number, depth: number, seed: number)
	local model = Builder.model(parent, "FlowerBed")
	detail(model, "Mulch", center * CFrame.new(0, 0.1, 0), Vector3.new(length, 0.22, depth), C.Mulch, { Material = Materials.Ground })
	detail(model, "Edging", center * CFrame.new(0, 0.12, -depth / 2), Vector3.new(length + 0.3, 0.26, 0.24), C.Curb, { Material = Materials.Concrete })
	local count = math.max(2, math.floor(length / 1.5))
	for i = 1, count do
		local r = hash(seed * 5 + i)
		local x = -length / 2 + (i - 0.5) * length / count + (r - 0.5) * 0.5
		local z = (hash(seed + i * 3) - 0.5) * (depth - 1.0)
		local leaf = Vector3.new(1.2, 0.8, 1.2) * (0.8 + r * 0.4)
		detail(model, "Foliage", center * CFrame.new(x, 0.45, z), leaf, C.Leaves:Lerp(C.LeavesDeep, r), {
			Shape = Enum.PartType.Ball,
			Material = Materials.Grass,
		})
		local color = FLOWER_COLORS[(seed + i) % #FLOWER_COLORS + 1]
		detail(model, "Blossom", center * CFrame.new(x + 0.2, 0.85, z - 0.1), Vector3.new(0.55, 0.55, 0.55), color, {
			Shape = Enum.PartType.Ball,
			Material = Materials.Fabric,
		})
		if r > 0.4 then
			detail(model, "Blossom", center * CFrame.new(x - 0.3, 0.75, z + 0.25), Vector3.new(0.45, 0.45, 0.45), color:Lerp(Color3.new(1, 1, 1), 0.15), {
				Shape = Enum.PartType.Ball,
				Material = Materials.Fabric,
			})
		end
	end
	return model
end

-- A decorative rock.
function OutdoorProps.rock(parent: Instance, floor: CFrame, seed: number, scale: number?)
	local s = (scale or 1) * (0.7 + hash(seed) * 0.6)
	return Builder.ellipsoid(parent, "Rock", floor * CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0, hash(seed + 1) * 6, (hash(seed + 2) - 0.5) * 0.4), Vector3.new(1.6, 0.9, 1.2) * s, rgb(136, 134, 128):Lerp(rgb(110, 104, 96), hash(seed + 3)), {
		Material = Materials.Slate,
		CanCollide = false,
	})
end

-- A hedge between two points on the ground, with a rounded top.
function OutdoorProps.hedge(parent: Instance, from: Vector3, to: Vector3, height: number?)
	local h = height or 2.6
	local model = Builder.model(parent, "Hedge")
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt((from + to) / 2, to)
	Builder.part(model, "Hedge", frame * CFrame.new(0, (h - 0.8) / 2, 0), Vector3.new(2, h - 0.8, length), C.Hedge, { Material = Materials.Grass })
	detail(model, "HedgeTop", frame * CFrame.new(0, h - 0.8, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(length, 2, 2), C.Hedge:Lerp(C.LeavesLight, 0.12), {
		Shape = Enum.PartType.Cylinder,
		Material = Materials.Grass,
	})
	return model
end

---------------------------------------------------------------------------
-- Fences and gates
---------------------------------------------------------------------------

--[[
	A garden gate leaf of pickets. `hinge` is on the hinge line at mid
	height; the leaf runs along its local -Z for `width`. The client swings
	it open when someone walks up (Motion "gate").
]]
function OutdoorProps.gate(parent: Instance, hinge: CFrame, width: number, color: Color3, openAngle: number)
	local model = Builder.model(parent, "Gate")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, y in { -0.5, 0.7 } do
		detail(model, "GateRail", hinge * CFrame.new(0, y, -width / 2), Vector3.new(0.18, 0.22, width - 0.1), color)
	end
	for z = 0.25, width - 0.2, 0.62 do
		detail(model, "Picket", hinge * CFrame.new(0, 0.1, -z), Vector3.new(0.12, 2.6, 0.36), color)
	end
	detail(model, "Latch", hinge * CFrame.new(0, 0.2, -width + 0.15), Vector3.new(0.2, 0.2, 0.2), Colors.DarkMetal)
	motion(model, "gate", { [Attributes.HingeCFrame] = hinge, [Attributes.OpenAngle] = openAngle })
	return model
end

--[[
	A picket fence between two points on the ground: rails, square posts
	with caps every few studs, and pickets, colliding through a single
	invisible box. Options:
		gate: { at: number, width: number, swing: number? }?
		      leaves a gap `at` studs from `from` with a swinging gate
]]
function OutdoorProps.fence(parent: Instance, from: Vector3, to: Vector3, color: Color3?, options: { [string]: any }?)
	local paint = color or Colors.OffWhite
	local opts = options or {}
	local model = Builder.model(parent, "Fence")
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	local gate = opts.gate
	local gapFrom, gapTo = math.huge, -math.huge
	if gate then
		gapFrom, gapTo = gate.at, gate.at + gate.width
	end
	local function solid(a: number, b: number)
		if b - a < 0.3 then
			return
		end
		for _, y in { 0.9, 2.2 } do
			detail(model, "Rail", frame * CFrame.new(0, y, -(a + b) / 2), Vector3.new(0.18, 0.24, b - a), paint)
		end
		for z = a + 0.3, b - 0.2, 0.62 do
			detail(model, "Picket", frame * CFrame.new(-0.12, 1.4, -z), Vector3.new(0.12, 2.7, 0.36), paint)
		end
		collider(model, frame * Vector3.new(0, 0, -a), frame * Vector3.new(0, 0, -b), 3, 0.5)
	end
	solid(0, math.min(length, gapFrom))
	if gate then
		solid(gapTo, length)
	end
	local postSpacing = math.max(length / math.max(1, math.round(length / 6)), 1)
	for z = 0, length + 0.01, postSpacing do
		if z <= gapFrom - 0.4 or z >= gapTo + 0.4 then
			detail(model, "Post", frame * CFrame.new(0, 1.6, -z), Vector3.new(0.42, 3.2, 0.42), paint)
			detail(model, "PostCap", frame * CFrame.new(0, 3.3, -z), Vector3.new(0.56, 0.2, 0.56), paint:Lerp(Colors.Charcoal, 0.08))
		end
	end
	if gate then
		for _, z in { gapFrom, gapTo } do
			detail(model, "GatePost", frame * CFrame.new(0, 1.7, -z), Vector3.new(0.5, 3.4, 0.5), paint)
			detail(model, "PostCap", frame * CFrame.new(0, 3.45, -z), Vector3.new(0.64, 0.2, 0.64), paint:Lerp(Colors.Charcoal, 0.08))
		end
		local hinge = frame * CFrame.new(0, 1.45, -(gapFrom + 0.3))
		OutdoorProps.gate(model, hinge, gate.width - 0.6, paint, gate.swing or 75)
	end
	return model
end

---------------------------------------------------------------------------
-- Street furniture
---------------------------------------------------------------------------

-- A streetlight with a curved arm, facing the floor CFrame's look direction.
function OutdoorProps.streetlight(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "Streetlight")
	local metal = { Material = Materials.Metal }
	Builder.cylinder(model, "Base", floor * CFrame.new(0, 0.5, 0), 1.0, 0.85, Colors.DarkMetal, metal)
	Builder.cylinder(model, "Pole", floor * CFrame.new(0, 4, 0), 7, 0.48, Colors.DarkMetal, metal)
	detail(model, "Pole", floor * CFrame.new(0, 9.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(4.8, 0.36, 0.36), Colors.DarkMetal, {
		Shape = Enum.PartType.Cylinder,
		Material = Materials.Metal,
	})
	Builder.beam(model, "Arm", floor * Vector3.new(0, 11.9, 0), floor * Vector3.new(0, 12.7, -1.4), 0.26, 0.26, Colors.DarkMetal, { CanCollide = false, CastShadow = false })
	Builder.beam(model, "Arm", floor * Vector3.new(0, 12.7, -1.35), floor * Vector3.new(0, 12.75, -3.0), 0.26, 0.26, Colors.DarkMetal, { CanCollide = false, CastShadow = false })
	Builder.ellipsoid(model, "LampHead", floor * CFrame.new(0, 12.6, -3.2), Vector3.new(1.3, 0.55, 2.0), Colors.DarkMetal, { CanCollide = false, Material = Materials.Metal })
	detail(model, "Lens", floor * CFrame.new(0, 12.32, -3.2), Vector3.new(0.9, 0.08, 1.4), Colors.LightFixture, { Material = Materials.Glass })
	return model
end

-- A parked car (see Vehicles). `style` defaults to a sedan.
function OutdoorProps.car(parent: Instance, floor: CFrame, color: Color3, style: string?)
	return Vehicles.car(parent, floor, color, style)
end

--[[
	A curbside mailbox on a post, opening toward the floor CFrame's look
	direction, with a rounded top and a red flag. Returns (model, box
	position).
]]
function OutdoorProps.mailbox(parent: Instance, floor: CFrame, color: Color3)
	local model = Builder.model(parent, "Mailbox")
	Builder.part(model, "Post", floor * CFrame.new(0, 1.55, 0.2), Vector3.new(0.36, 3.1, 0.36), Colors.Wood, { Material = Materials.Wood })
	detail(model, "Arm", floor * CFrame.new(0, 3.0, 0), Vector3.new(0.3, 0.2, 1.2), Colors.Wood)
	local box = floor * CFrame.new(0, 3.35, -0.1)
	Builder.part(model, "Box", box, Vector3.new(0.9, 0.5, 1.6), color, { Material = Materials.Metal })
	detail(model, "BoxTop", box * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1.6, 0.9, 0.9), color, {
		Shape = Enum.PartType.Cylinder,
		Material = Materials.Metal,
	})
	detail(model, "Door", box * CFrame.new(0, 0.1, -0.82), Vector3.new(0.86, 0.85, 0.06), color:Lerp(Colors.Charcoal, 0.2))
	detail(model, "Flag", box * CFrame.new(0.5, 0.35, 0.3), Vector3.new(0.06, 0.6, 0.24), Colors.Red)
	return model, box.Position
end

function OutdoorProps.hydrant(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "Hydrant")
	local red, dark = Colors.Red, Colors.Red:Lerp(Colors.Charcoal, 0.3)
	local metal = { Material = Materials.Metal }
	Builder.cylinder(model, "Flange", floor * CFrame.new(0, 0.12, 0), 0.24, 1.0, dark, metal)
	Builder.cylinder(model, "Body", floor * CFrame.new(0, 0.95, 0), 1.5, 0.74, red, metal)
	detail(model, "Dome", floor * CFrame.new(0, 1.72, 0), Vector3.new(0.78, 0.78, 0.78), red, { Shape = Enum.PartType.Ball, Material = Materials.Metal })
	detail(model, "Nut", floor * CFrame.new(0, 2.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.22, 0.26, 0.26), dark, { Shape = Enum.PartType.Cylinder })
	detail(model, "SideNozzles", floor * CFrame.new(0, 1.2, 0), Vector3.new(1.15, 0.3, 0.3), dark, { Shape = Enum.PartType.Cylinder })
	detail(model, "FrontNozzle", floor * CFrame.new(0, 1.05, -0.4) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 0.42, 0.42), dark, { Shape = Enum.PartType.Cylinder })
	return model
end

-- Height of a bench's seat surface above its floor (NPCs sit on this).
OutdoorProps.BENCH_SEAT_TOP = 1.3

-- A slatted park bench with cast-iron ends.
function OutdoorProps.bench(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "Bench")
	local wood = { Material = Materials.Wood }
	for _, z in { -0.45, 0, 0.45 } do
		Builder.part(model, "Slat", floor * CFrame.new(0, 1.22, z), Vector3.new(5, 0.16, 0.38), Colors.LightWood, wood)
	end
	for _, y in { 2.0, 2.6 } do
		detail(model, "BackSlat", floor * CFrame.new(0, y, 0.7 + (y - 2) * 0.12) * CFrame.Angles(math.rad(12), 0, 0), Vector3.new(5, 0.34, 0.14), Colors.LightWood, wood)
	end
	for _, x in { -2.2, 2.2 } do
		detail(model, "Leg", floor * CFrame.new(x, 0.6, -0.4), Vector3.new(0.22, 1.2, 0.22), C.Iron)
		detail(model, "Leg", floor * CFrame.new(x, 1.3, 0.55) * CFrame.Angles(math.rad(10), 0, 0), Vector3.new(0.22, 2.6, 0.22), C.Iron)
		detail(model, "Armrest", floor * CFrame.new(x, 1.95, 0.05), Vector3.new(0.22, 0.16, 1.2), C.Iron)
	end
	return model
end

-- A sign on a post (raised above head height). The sign faces the floor
-- CFrame's look direction. Returns (model, sign part).
function OutdoorProps.signPost(parent: Instance, floor: CFrame, text: string, color: Color3?, width: number?)
	local model = Builder.model(parent, "SignPost")
	Builder.cylinder(model, "Post", floor * CFrame.new(0, 3.6, 0), 7.2, 0.26, Colors.DarkMetal, { Material = Materials.Metal })
	local sign = Builder.sign(model, "Sign", floor * CFrame.new(0, 6.6, -0.2), Vector3.new(width or 4, 1.1, 0.12), text, color or rgb(60, 110, 76), Colors.Paper)
	detail(model, "Cap", floor * CFrame.new(0, 7.25, 0), Vector3.new(0.34, 0.12, 0.34), Colors.DarkMetal)
	return model, sign
end

-- A two-panel traffic sign (e.g. "SCHOOL ZONE" over "SPEED LIMIT 20").
function OutdoorProps.trafficSign(parent: Instance, floor: CFrame, top: string, bottom: string?)
	local model = Builder.model(parent, "TrafficSign")
	Builder.cylinder(model, "Post", floor * CFrame.new(0, 3.5, 0), 7, 0.24, Colors.Metal, { Material = Materials.Metal })
	Builder.sign(model, "Sign", floor * CFrame.new(0, 6.2, -0.16), Vector3.new(2.4, 1.6, 0.1), top, rgb(226, 200, 64), rgb(30, 30, 32))
	if bottom then
		Builder.sign(model, "Sign", floor * CFrame.new(0, 4.6, -0.16), Vector3.new(2.0, 1.3, 0.1), bottom, rgb(226, 224, 216), rgb(30, 30, 32))
	end
	return model
end

-- A storm drain grate at the road edge; `floor` sits on the road at the
-- curb, facing the curb.
function OutdoorProps.stormDrain(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "StormDrain")
	detail(model, "Grate", floor * CFrame.new(0, 0.02, 0.5), Vector3.new(2.4, 0.04, 1.0), C.Iron, { Material = Materials.Metal })
	for x = -0.9, 0.9, 0.45 do
		detail(model, "Slot", floor * CFrame.new(x, 0.045, 0.5), Vector3.new(0.12, 0.02, 0.8), rgb(28, 28, 30))
	end
	detail(model, "Inlet", floor * CFrame.new(0, 0.12, -0.03), Vector3.new(2.4, 0.1, 0.06), rgb(28, 28, 30))
	return model
end

-- A green utility cabinet with a rounded top.
function OutdoorProps.utilityBox(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "UtilityBox")
	local green = rgb(84, 112, 88)
	Builder.part(model, "Cabinet", floor * CFrame.new(0, 1.1, 0), Vector3.new(1.8, 2.2, 1.1), green, { Material = Materials.Metal })
	detail(model, "Top", floor * CFrame.new(0, 2.2, 0), Vector3.new(1.8, 0.5, 1.1), green, { Shape = Enum.PartType.Cylinder, Material = Materials.Metal })
	detail(model, "Vent", floor * CFrame.new(0, 1.5, -0.57), Vector3.new(1.0, 0.5, 0.04), green:Lerp(Colors.Charcoal, 0.4))
	detail(model, "Plinth", floor * CFrame.new(0, 0.08, 0), Vector3.new(2.1, 0.16, 1.4), C.Curb, { Material = Materials.Concrete })
	return model
end

-- A pair of wheelie bins (rubbish and recycling) by a driveway.
function OutdoorProps.bins(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "Bins")
	for i, color in { rgb(60, 82, 64), rgb(56, 84, 128) } do
		local at = floor * CFrame.new((i - 1.5) * 1.6, 0, 0)
		Builder.part(model, "Bin", at * CFrame.new(0, 1.15, 0), Vector3.new(1.3, 2.0, 1.35), color)
		detail(model, "Lid", at * CFrame.new(0, 2.2, -0.04), Vector3.new(1.4, 0.14, 1.5), color:Lerp(Colors.Charcoal, 0.2))
		detail(model, "Handle", at * CFrame.new(0, 2.05, 0.74), Vector3.new(1.0, 0.14, 0.14), Colors.Charcoal)
		detail(model, "Wheels", at * CFrame.new(0, 0.28, 0.6), Vector3.new(1.4, 0.56, 0.56), Colors.Charcoal, { Shape = Enum.PartType.Cylinder })
	end
	return model
end

-- A lawn sprinkler; its arm spins on the client, sending out two arcs of
-- water (a few particles each).
function OutdoorProps.sprinkler(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "Sprinkler")
	detail(model, "Base", floor * CFrame.new(0, 0.08, 0), Vector3.new(0.9, 0.16, 0.9), rgb(70, 110, 70), { Shape = Enum.PartType.Ball })
	Builder.cylinder(model, "Riser", floor * CFrame.new(0, 0.4, 0), 0.6, 0.18, Colors.Metal, { CanCollide = false })
	local arm = detail(model, "Arm", floor * CFrame.new(0, 0.72, 0), Vector3.new(1.6, 0.1, 0.12), Colors.Metal, { Material = Materials.Metal })
	for _, side in { -1, 1 } do
		local nozzle = Instance.new("Attachment")
		nozzle.Name = "Nozzle"
		-- Point up and outward along the arm.
		nozzle.CFrame = CFrame.new(side * 0.8, 0, 0) * CFrame.Angles(0, 0, side * math.rad(-50))
		nozzle.Parent = arm
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "Spray"
		spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spray.Color = ColorSequence.new(rgb(196, 222, 236))
		spray.LightEmission = 0.1
		spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		spray.Size = NumberSequence.new(0.18, 0.08)
		spray.Lifetime = NumberRange.new(0.7, 1.0)
		spray.Rate = 18
		spray.Speed = NumberRange.new(9, 11)
		spray.SpreadAngle = Vector2.new(6, 6)
		spray.Acceleration = Vector3.new(0, -26, 0)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = nozzle
	end
	motion(arm, "spin", { [Attributes.MotionAxis] = Vector3.yAxis, [Attributes.MotionSpeed] = 2.2 })
	return model
end

---------------------------------------------------------------------------
-- A dog
---------------------------------------------------------------------------

-- Dog layouts: { name, offset, size, shape ("ball" | "ellipsoid"), tone }
-- with tone 0 coat, 1 darker coat, 2 black, 3 collar. Legs carry the
-- point they swing from (their top).
local DOG = {
	stand = {
		parts = {
			{ "Body", Vector3.new(0, 1.4, 0), Vector3.new(1.05, 0.95, 2.3), "ellipsoid", 0 },
			{ "Chest", Vector3.new(0, 1.5, -0.75), Vector3.new(0.95, 1.0, 1.0), "ellipsoid", 0 },
			{ "Neck", Vector3.new(0, 1.95, -1.15), Vector3.new(0.6, 0.85, 0.6), "ellipsoid", 0 },
			{ "Head", Vector3.new(0, 2.32, -1.45), Vector3.new(0.85, 0.8, 0.95), "ellipsoid", 0 },
			{ "Snout", Vector3.new(0, 2.15, -1.95), Vector3.new(0.5, 0.42, 0.65), "ellipsoid", 1 },
			{ "Nose", Vector3.new(0, 2.24, -2.26), Vector3.new(0.2, 0.2, 0.2), "ball", 2 },
			{ "Ear", Vector3.new(-0.42, 2.28, -1.38), Vector3.new(0.18, 0.55, 0.35), "ellipsoid", 1 },
			{ "Ear", Vector3.new(0.42, 2.28, -1.38), Vector3.new(0.18, 0.55, 0.35), "ellipsoid", 1 },
			{ "Eye", Vector3.new(-0.22, 2.44, -1.85), Vector3.new(0.13, 0.13, 0.13), "ball", 2 },
			{ "Eye", Vector3.new(0.22, 2.44, -1.85), Vector3.new(0.13, 0.13, 0.13), "ball", 2 },
			{ "Collar", Vector3.new(0, 1.86, -1.08), Vector3.new(0.68, 0.16, 0.68), "ellipsoid", 3 },
		},
		legs = {
			{ "LegFL", Vector3.new(-0.33, 1.05, -0.8) },
			{ "LegFR", Vector3.new(0.33, 1.05, -0.8) },
			{ "LegBL", Vector3.new(-0.33, 1.05, 0.75) },
			{ "LegBR", Vector3.new(0.33, 1.05, 0.75) },
		},
		tail = { base = Vector3.new(0, 1.62, 1.12), angle = 35 },
	},
	sit = {
		parts = {
			{ "Rump", Vector3.new(0, 0.6, 0.5), Vector3.new(1.1, 1.0, 1.3), "ellipsoid", 0 },
			{ "Body", Vector3.new(0, 1.3, 0.12), Vector3.new(1.0, 1.6, 1.1), "ellipsoid", 0 },
			{ "Chest", Vector3.new(0, 1.75, -0.25), Vector3.new(0.95, 1.0, 0.9), "ellipsoid", 0 },
			{ "Neck", Vector3.new(0, 2.25, -0.45), Vector3.new(0.6, 0.8, 0.6), "ellipsoid", 0 },
			{ "Head", Vector3.new(0, 2.65, -0.65), Vector3.new(0.85, 0.8, 0.95), "ellipsoid", 0 },
			{ "Snout", Vector3.new(0, 2.48, -1.15), Vector3.new(0.5, 0.42, 0.65), "ellipsoid", 1 },
			{ "Nose", Vector3.new(0, 2.57, -1.46), Vector3.new(0.2, 0.2, 0.2), "ball", 2 },
			{ "Ear", Vector3.new(-0.42, 2.6, -0.58), Vector3.new(0.18, 0.55, 0.35), "ellipsoid", 1 },
			{ "Ear", Vector3.new(0.42, 2.6, -0.58), Vector3.new(0.18, 0.55, 0.35), "ellipsoid", 1 },
			{ "Eye", Vector3.new(-0.22, 2.77, -1.05), Vector3.new(0.13, 0.13, 0.13), "ball", 2 },
			{ "Eye", Vector3.new(0.22, 2.77, -1.05), Vector3.new(0.13, 0.13, 0.13), "ball", 2 },
			{ "Collar", Vector3.new(0, 2.15, -0.38), Vector3.new(0.68, 0.16, 0.68), "ellipsoid", 3 },
			{ "Haunch", Vector3.new(-0.45, 0.45, 0.4), Vector3.new(0.45, 0.8, 1.0), "ellipsoid", 0 },
			{ "Haunch", Vector3.new(0.45, 0.45, 0.4), Vector3.new(0.45, 0.8, 1.0), "ellipsoid", 0 },
			{ "Paw", Vector3.new(-0.38, 0.1, -0.1), Vector3.new(0.34, 0.2, 0.55), "ellipsoid", 0 },
			{ "Paw", Vector3.new(0.38, 0.1, -0.1), Vector3.new(0.34, 0.2, 0.55), "ellipsoid", 0 },
		},
		legs = {
			{ "LegFL", Vector3.new(-0.3, 1.5, -0.45) },
			{ "LegFR", Vector3.new(0.3, 1.5, -0.45) },
		},
		tail = { base = Vector3.new(0, 0.35, 1.05), angle = -10 },
	},
}

--[[
	A medium-sized dog standing (pose "stand") or sitting ("sit") on
	`floor`, facing its LookVector. The model's PrimaryPart is an invisible
	"Root" at the floor. Legs ("LegFL", …) and the "Tail" carry a Pivot
	attribute (CFrame relative to the root) so the client can swing them;
	head parts are marked HeadPart for sniffing. Sitting dogs wag their
	tail through WorldMotion.
]]
function OutdoorProps.dog(parent: Instance, floor: CFrame, coat: Color3, pose: string?)
	local layout = DOG[pose or "stand"] or DOG.stand
	local model = Builder.model(parent, "Dog")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = Builder.part(model, "Root", floor, Vector3.new(1, 1, 1), coat, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	model.PrimaryPart = root
	local tones = { [0] = coat, [1] = coat:Lerp(Colors.Charcoal, 0.35), [2] = rgb(26, 24, 24), [3] = Colors.Red }
	local headParts = { Neck = true, Head = true, Snout = true, Nose = true, Ear = true, Eye = true, Collar = true }
	for _, spec in layout.parts do
		local name, offset, size, shape, tone = spec[1], spec[2], spec[3], spec[4], spec[5]
		local cframe = floor * CFrame.new(offset)
		local part
		if shape == "ball" then
			part = detail(model, name, cframe, size, tones[tone], { Shape = Enum.PartType.Ball })
		else
			part = Builder.ellipsoid(model, name, cframe, size, tones[tone], { CanCollide = false, CastShadow = name == "Body" })
		end
		if headParts[name] then
			part:SetAttribute("HeadPart", true)
		end
	end
	local leash = Instance.new("Attachment")
	leash.Name = "LeashPoint"
	leash.Parent = model:FindFirstChild("Collar")

	for _, spec in layout.legs do
		local name, top = spec[1], spec[2]
		local leg = Builder.ellipsoid(model, name, floor * CFrame.new(top.X, top.Y / 2, top.Z), Vector3.new(0.32, top.Y + 0.1, 0.32), coat, {
			CanCollide = false,
			CastShadow = false,
		})
		leg:SetAttribute("Pivot", CFrame.new(top))
	end
	local tailBase = layout.tail.base
	local tail = Builder.ellipsoid(model, "Tail", floor * CFrame.new(tailBase) * CFrame.Angles(math.rad(layout.tail.angle), 0, 0) * CFrame.new(0, 0, 0.45), Vector3.new(0.2, 0.2, 1.0), coat, {
		CanCollide = false,
		CastShadow = false,
	})
	tail:SetAttribute("Pivot", CFrame.new(tailBase))
	if pose == "sit" then
		motion(tail, "wag", {
			[Attributes.MotionPivot] = floor * tailBase,
			[Attributes.MotionAxis] = floor.UpVector,
			[Attributes.MotionSpeed] = 9,
			[Attributes.MotionAmount] = 22,
		})
	end
	return model
end

---------------------------------------------------------------------------
-- Bus stop and crossings
---------------------------------------------------------------------------

function OutdoorProps.busShelter(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "BusShelter")
	for _, x in { -3.6, 3.6 } do
		Builder.cylinder(model, "Post", floor * CFrame.new(x, 3.6, 1.2), 7.2, 0.32, Colors.DarkMetal, { Material = Materials.Metal })
	end
	Builder.beam(model, "Roof", floor * Vector3.new(0, 7.45, 1.5), floor * Vector3.new(0, 7.15, -1.6), 8.2, 0.26, Colors.DarkMetal, { Material = Materials.Metal }, floor.UpVector)
	detail(model, "RoofEdge", floor * CFrame.new(0, 7.0, -1.55), Vector3.new(8.2, 0.3, 0.12), rgb(56, 92, 150))
	detail(model, "BackPanel", floor * CFrame.new(0, 3.9, 1.25), Vector3.new(7, 5, 0.12), Colors.Glass, {
		Material = Materials.Glass,
		Transparency = 0.5,
	})
	detail(model, "SidePanel", floor * CFrame.new(-3.6, 3.9, 0.3), Vector3.new(0.1, 4.4, 1.8), Colors.Glass, {
		Material = Materials.Glass,
		Transparency = 0.5,
	})
	Builder.sign(model, "Ad", floor * CFrame.new(1.8, 3.9, 1.18), Vector3.new(2.6, 3.4, 0.05), "Westbrook\nLibrary\nOpen late", rgb(222, 196, 120), rgb(40, 44, 52))
	OutdoorProps.bench(model, floor * CFrame.new(0, 0, 0.5))
	local _, sign = OutdoorProps.signPost(model, floor * CFrame.new(4.6, 0, -0.6), "Bus 4", rgb(56, 92, 150), 2.2)
	return model, sign
end

--[[
	Pedestrian signal head on a pole, facing the floor CFrame's look
	direction, with "Wait" (orange hand) and "Walk" panels the client
	Crosswalks module lights, and a push button. Returns the button part.
]]
function OutdoorProps.crossingSignal(parent: Instance, floor: CFrame, crosswalkId: string)
	local model = Builder.model(parent, "CrossingSignal")
	Builder.cylinder(model, "Pole", floor * CFrame.new(0, 4.5, 0), 9, 0.35, Colors.DarkMetal, { Material = Materials.Metal })
	local head = Builder.model(model, "Head")
	detail(head, "Housing", floor * CFrame.new(0, 7.6, -0.45), Vector3.new(1.4, 2.6, 0.6), Colors.Charcoal)
	detail(head, "Visor", floor * CFrame.new(0, 8.95, -0.85), Vector3.new(1.4, 0.1, 0.5), Colors.Charcoal)
	detail(head, "Wait", floor * CFrame.new(0, 8.25, -0.77), Vector3.new(1.0, 1.0, 0.05), rgb(80, 60, 44))
	detail(head, "Walk", floor * CFrame.new(0, 6.95, -0.77), Vector3.new(1.0, 1.0, 0.05), rgb(60, 64, 66))
	head:SetAttribute(World.Attributes.CrosswalkId, crosswalkId)
	CollectionService:AddTag(head, World.Tags.CrosswalkSignal)
	detail(model, "ButtonBox", floor * CFrame.new(0, 3.6, -0.22), Vector3.new(0.8, 1.1, 0.2), Colors.Charcoal)
	local button = Builder.part(model, "Button", floor * CFrame.new(0, 3.6, -0.36), Vector3.new(0.5, 0.5, 0.12), Colors.Yellow)
	return button
end

---------------------------------------------------------------------------
-- Ground
---------------------------------------------------------------------------

-- Ground slab covering the rectangle (x1, z1)–(x2, z2) with its top at `top`.
function OutdoorProps.slab(parent: Instance, name: string, x1: number, z1: number, x2: number, z2: number, top: number, color: Color3, material: Enum.Material?, thickness: number?)
	local depth = thickness or 0.6
	return Builder.part(
		parent,
		name,
		CFrame.new((x1 + x2) / 2, top - depth / 2, (z1 + z2) / 2),
		Vector3.new(math.abs(x2 - x1), depth, math.abs(z2 - z1)),
		color,
		{ Material = material or Materials.Matte }
	)
end

-- A flat path strip from `a` to `b` (on the ground), with round joints.
function OutdoorProps.pathSegment(parent: Instance, a: Vector3, b: Vector3, width: number, top: number, color: Color3, material: Enum.Material)
	local flatA, flatB = Vector3.new(a.X, top - 0.15, a.Z), Vector3.new(b.X, top - 0.15, b.Z)
	local length = (flatB - flatA).Magnitude
	Builder.part(parent, "Path", CFrame.lookAt((flatA + flatB) / 2, flatB), Vector3.new(width, 0.3, length), color, { Material = material })
	Builder.cylinder(parent, "PathJoint", CFrame.new(flatB) * CFrame.new(0, -0.001, 0), 0.3, width, color, { Material = material })
end

--[[
	Mown-lawn stripes and a few softer patches over the rectangle, so big
	grass areas aren't one flat colour. Purely visual (non-colliding, a
	hair above the ground).
]]
function OutdoorProps.lawn(parent: Instance, x1: number, z1: number, x2: number, z2: number, seed: number, stripesAlongX: boolean?)
	local model = Builder.model(parent, "Lawn")
	local width, depth = x2 - x1, z2 - z1
	local count = math.max(2, math.floor((if stripesAlongX then depth else width) / 3.2))
	for i = 0, count - 1, 2 do
		local t0 = i / count
		local t1 = (i + 1) / count
		local color = C.Lawn:Lerp(C.GrassLight, 0.35 + hash(seed + i) * 0.15)
		if stripesAlongX then
			detail(model, "Stripe", CFrame.new((x1 + x2) / 2, 0.02, z1 + depth * (t0 + t1) / 2), Vector3.new(width, 0.04, depth * (t1 - t0)), color, { Material = Materials.Grass })
		else
			detail(model, "Stripe", CFrame.new(x1 + width * (t0 + t1) / 2, 0.02, (z1 + z2) / 2), Vector3.new(width * (t1 - t0), 0.04, depth), color, { Material = Materials.Grass })
		end
	end
	return model
end

-- Scattered soft patches of lighter/darker grass over a large area.
function OutdoorProps.grassPatches(parent: Instance, x1: number, z1: number, x2: number, z2: number, count: number, seed: number, avoid: ((Vector3) -> boolean)?)
	local model = Builder.model(parent, "GrassPatches")
	for i = 1, count do
		local point = Vector3.new(x1 + hash(seed + i) * (x2 - x1), 0, z1 + hash(seed + i * 7) * (z2 - z1))
		if avoid and avoid(point) then
			continue
		end
		local r = hash(seed + i * 3)
		local diameter = 6 + r * 12
		local color = if r > 0.5 then C.GrassDark:Lerp(C.Grass, 0.4) else C.GrassLight:Lerp(C.Grass, 0.3)
		detail(model, "Patch", CFrame.new(point + Vector3.new(0, 0.015 + r * 0.01, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.03, diameter, diameter * (0.6 + r * 0.4)), color, {
			Shape = Enum.PartType.Cylinder,
			Material = Materials.Grass,
		})
	end
	return model
end

--[[
	A curb along a sidewalk's road edge, from `a` to `b` (on the road
	surface): a lighter curb stone and a darker gutter strip on the road.
	`outward` points from the sidewalk toward the road.
]]
function OutdoorProps.curb(parent: Instance, a: Vector3, b: Vector3, sidewalkTop: number, outward: Vector3)
	local model = Builder.model(parent, "Curb")
	local along = (b - a).Unit
	local length = (b - a).Magnitude
	local middle = (a + b) / 2
	local function strip(name: string, offset: number, top: number, width: number, height: number, color: Color3)
		local center = middle + outward * offset
		detail(model, name, CFrame.lookAt(Vector3.new(center.X, top - height / 2, center.Z), Vector3.new(center.X, top - height / 2, center.Z) + along), Vector3.new(width, height, length), color, {
			Material = Materials.Concrete,
		})
	end
	strip("Curb", -0.35, sidewalkTop + 0.03, 0.7, 0.3, C.Curb)
	strip("Gutter", 0.6, a.Y + 0.015, 1.2, 0.04, C.Gutter)
	return model
end

OutdoorProps.rotY = rotY

return OutdoorProps
