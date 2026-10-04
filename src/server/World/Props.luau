--[[
	Props

	Reusable furniture and set dressing. Each function builds a small model
	at a floor (or wall) CFrame so areas can place them with one line.

	Orientation: furniture faces its CFrame's LookVector (a chair's seat
	faces forward, its back is behind). Wall items face the reader.
	Part counts are kept low: small details are non-colliding and cast no
	shadows (Builder.detail), legs and posts are cylinders for softer shapes.
]]

local Builder = require(script.Parent.Builder)
local Palette = require(script.Parent.Palette)

local Colors = Palette.Colors
local Materials = Palette.Materials
local detail = Builder.detail

local Props = {}

local function rotY(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- Deterministic pseudo-random in [0, 1) so the world looks the same every run.
local function hash(seed: number): number
	local x = math.sin(seed * 12.9898) * 43758.5453
	return x - math.floor(x)
end
Props.hash = hash

---------------------------------------------------------------------------
-- Furniture
---------------------------------------------------------------------------

--[[
	Desk/table. Options:
		width (X), depth (Z), height
		topColor, legColor
		bookBox: boolean?   shallow storage tray under the top
	Returns (model, topPart).
]]
function Props.desk(parent: Instance, floor: CFrame, options: { [string]: any })
	local width, depth, height = options.width, options.depth, options.height
	local model = Builder.model(parent, options.name or "Desk")
	local top = Builder.part(model, "Top", floor * CFrame.new(0, height - 0.12, 0), Vector3.new(width, 0.24, depth), options.topColor or Colors.LightWood, {
		Material = Materials.Wood,
	})
	-- Slightly darker edge band makes the top read as a separate surface.
	detail(model, "Edge", floor * CFrame.new(0, height - 0.3, 0), Vector3.new(width - 0.1, 0.12, depth - 0.1), Colors.Trim)
	local legColor = options.legColor or Colors.DarkMetal
	local legX, legZ = width / 2 - 0.2, depth / 2 - 0.2
	for _, offset in { Vector2.new(legX, legZ), Vector2.new(-legX, legZ), Vector2.new(legX, -legZ), Vector2.new(-legX, -legZ) } do
		Builder.cylinder(model, "Leg", floor * CFrame.new(offset.X, (height - 0.36) / 2, offset.Y), height - 0.36, 0.22, legColor, {
			Material = Materials.Metal,
		})
	end
	if options.bookBox then
		detail(model, "BookBox", floor * CFrame.new(0, height - 0.75, 0), Vector3.new(width - 0.5, 0.5, depth - 0.6), legColor)
	end
	return model, top
end

--[[
	Chair facing the CFrame's LookVector. With `seat` ({ context, id,
	listenTo? }) the seat is a real Seat the player can be placed in (see
	Builder.seat). Returns (model, seatPart).
]]
function Props.chair(parent: Instance, floor: CFrame, color: Color3, seat: { [string]: any }?)
	local model = Builder.model(parent, "Chair")
	local seatCFrame, seatSize = floor * CFrame.new(0, 1.75, 0), Vector3.new(1.9, 0.22, 1.9)
	local seatPart = if seat
		then Builder.seat(model, seat.context, seat.id, seatCFrame, seatSize, color, seat.listenTo)
		else Builder.part(model, "Seat", seatCFrame, seatSize, color)
	Builder.part(model, "Back", floor * CFrame.new(0, 3.1, 0.85), Vector3.new(1.8, 1.3, 0.18), color)
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.75, 0.75 } do
			Builder.cylinder(model, "Leg", floor * CFrame.new(x, 0.82, z), 1.64, 0.16, Colors.DarkMetal, { Material = Materials.Metal })
		end
		Builder.cylinder(model, "BackPost", floor * CFrame.new(x, 2.3, 0.85), 1.0, 0.14, Colors.DarkMetal, { Material = Materials.Metal })
	end
	return model, seatPart
end

--[[
	Open bookshelf facing its LookVector, filled with books.
	`floor` is the floor point under the shelf's centre.
]]
function Props.bookshelf(parent: Instance, floor: CFrame, width: number, height: number, depth: number, shelves: number, seed: number?)
	seed = seed or 1
	local model = Builder.model(parent, "Bookshelf")
	local wood = { Material = Materials.Wood }
	Builder.part(model, "Back", floor * CFrame.new(0, height / 2, depth / 2 - 0.1), Vector3.new(width, height, 0.2), Colors.DarkWood, wood)
	Builder.part(model, "Side", floor * CFrame.new(-width / 2 + 0.1, height / 2, 0), Vector3.new(0.2, height, depth), Colors.Wood, wood)
	Builder.part(model, "Side", floor * CFrame.new(width / 2 - 0.1, height / 2, 0), Vector3.new(0.2, height, depth), Colors.Wood, wood)
	local gap = height / shelves
	for shelf = 0, shelves do
		Builder.part(model, "Shelf", floor * CFrame.new(0, math.min(shelf * gap + 0.1, height - 0.1), 0), Vector3.new(width - 0.2, 0.2, depth), Colors.Wood, wood)
	end
	-- Books: varied widths/heights, with occasional gaps and a leaning book.
	for shelf = 0, shelves - 1 do
		local x = -width / 2 + 0.3
		local i = 0
		while x < width / 2 - 0.5 do
			i += 1
			local r = hash(seed * 31 + shelf * 7 + i)
			local bookWidth = 0.25 + r * 0.25
			local bookHeight = math.min(gap - 0.35, 1.0 + r * 0.6)
			if r > 0.9 then
				x += 0.4 -- gap
			else
				detail(
					model,
					"Book",
					floor * CFrame.new(x + bookWidth / 2, shelf * gap + 0.2 + bookHeight / 2, -0.05),
					Vector3.new(bookWidth, bookHeight, depth - 0.45),
					Palette.pick(Palette.Assorted, math.floor(r * 100))
				)
			end
			x += bookWidth + 0.03
		end
	end
	return model
end

-- Single bed with frame, legs, mattress, bedding and pillow. The headboard
-- is behind (local +Z); the foot of the bed points along the LookVector.
-- Returns (model, mattress).
function Props.bed(parent: Instance, floor: CFrame, beddingColor: Color3)
	local model = Builder.model(parent, "Bed")
	local wood = { Material = Materials.Wood }
	Builder.part(model, "Frame", floor * CFrame.new(0, 0.95, 0), Vector3.new(5.6, 0.5, 8.6), Colors.Wood, wood)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -4.1, 4.1 } do
			Builder.cylinder(model, "Leg", floor * CFrame.new(x, 0.35, z), 0.7, 0.35, Colors.DarkWood, wood)
		end
	end
	Builder.part(model, "Headboard", floor * CFrame.new(0, 2.4, 4.4), Vector3.new(5.8, 4.4, 0.35), Colors.DarkWood, wood)
	Builder.part(model, "Footboard", floor * CFrame.new(0, 1.55, -4.4), Vector3.new(5.8, 1.7, 0.3), Colors.DarkWood, wood)
	local mattress = Builder.part(model, "Mattress", floor * CFrame.new(0, 1.55, 0), Vector3.new(5.3, 0.7, 8.2), Colors.Sheets, {
		Material = Materials.Fabric,
	})
	Builder.part(model, "Blanket", floor * CFrame.new(0, 1.95, -1.1), Vector3.new(5.5, 0.18, 6), beddingColor, { Material = Materials.Fabric })
	Builder.part(model, "BlanketFold", floor * CFrame.new(0, 2.05, 1.75), Vector3.new(5.5, 0.22, 0.5), Colors.Sheets, { Material = Materials.Fabric })
	Builder.part(model, "Pillow", floor * CFrame.new(0, 2.15, 3.3), Vector3.new(3.8, 0.55, 1.5), Colors.Paper, { Material = Materials.Fabric })
	return model, mattress
end

-- Chest of drawers / nightstand with handles.
function Props.drawers(parent: Instance, floor: CFrame, width: number, height: number, depth: number, rows: number)
	local model = Builder.model(parent, "Drawers")
	Builder.part(model, "Body", floor * CFrame.new(0, height / 2, 0), Vector3.new(width, height, depth), Colors.Wood, { Material = Materials.Wood })
	local rowHeight = (height - 0.3) / rows
	for row = 1, rows do
		local y = 0.15 + rowHeight * (row - 0.5)
		detail(model, "DrawerFront", floor * CFrame.new(0, y, -depth / 2 - 0.03), Vector3.new(width - 0.25, rowHeight - 0.12, 0.06), Colors.LightWood)
		detail(model, "Handle", floor * CFrame.new(0, y, -depth / 2 - 0.1), Vector3.new(0.6, 0.1, 0.08), Colors.DarkMetal)
	end
	return model
end

---------------------------------------------------------------------------
-- Lights and small props
---------------------------------------------------------------------------

-- Desk/table lamp with a soft warm light.
function Props.deskLamp(parent: Instance, surface: CFrame)
	local model = Builder.model(parent, "DeskLamp")
	Builder.cylinder(model, "Base", surface * CFrame.new(0, 0.08, 0), 0.16, 0.8, Colors.Charcoal)
	Builder.cylinder(model, "Stem", surface * CFrame.new(0, 0.7, 0), 1.1, 0.12, Colors.Metal, { Material = Materials.Metal })
	local shade = Builder.cylinder(model, "Shade", surface * CFrame.new(0, 1.4, 0), 0.6, 1.0, Colors.LightFixture, {
		CanCollide = false,
		CastShadow = false,
	})
	Builder.pointLight(shade, 0.6, 10, Colors.Light, false)
	return model
end

-- Floor lamp with a soft warm light.
function Props.floorLamp(parent: Instance, floor: CFrame)
	local model = Builder.model(parent, "FloorLamp")
	Builder.cylinder(model, "Base", floor * CFrame.new(0, 0.08, 0), 0.16, 1.2, Colors.Charcoal)
	Builder.cylinder(model, "Pole", floor * CFrame.new(0, 2.6, 0), 5, 0.16, Colors.Metal, { Material = Materials.Metal })
	local shade = Builder.cylinder(model, "Shade", floor * CFrame.new(0, 5.3, 0), 0.9, 1.5, Colors.LightFixture, {
		CanCollide = false,
		CastShadow = false,
	})
	Builder.pointLight(shade, 0.65, 13, Color3.fromRGB(255, 214, 165), true)
	return model
end

function Props.plant(parent: Instance, floor: CFrame, scale: number?)
	local s = scale or 1
	local model = Builder.model(parent, "Plant")
	Builder.cylinder(model, "Pot", floor * CFrame.new(0, 0.8 * s, 0), 1.6 * s, 1.3 * s, Colors.Pot)
	detail(model, "Soil", floor * CFrame.new(0, 1.58 * s, 0), Vector3.new(1.05, 0.05, 1.05) * s, Colors.DarkWood)
	detail(model, "Leaves", floor * CFrame.new(0, 2.5 * s, 0), Vector3.new(2.1, 2.1, 2.1) * s, Colors.Plant, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Grass,
	})
	detail(model, "Leaves", floor * CFrame.new(0.4 * s, 3.3 * s, 0.2 * s), Vector3.new(1.3, 1.3, 1.3) * s, Colors.Green, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Grass,
	})
	return model
end

-- Backpack on the floor, front facing the LookVector.
function Props.backpack(parent: Instance, floor: CFrame, color: Color3)
	local model = Builder.model(parent, "Backpack")
	Builder.part(model, "Body", floor * CFrame.new(0, 0.85, 0) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(1.4, 1.7, 0.7), color, {
		Material = Materials.Fabric,
	})
	detail(model, "Pocket", floor * CFrame.new(0, 0.55, -0.42), Vector3.new(1.0, 0.7, 0.2), color:Lerp(Colors.Charcoal, 0.25), {
		Material = Materials.Fabric,
	})
	return model
end

-- A few loose sheets of paper on a surface.
function Props.papers(parent: Instance, surface: CFrame, count: number, seed: number)
	for i = 1, count do
		local r = hash(seed * 13 + i)
		detail(parent, "Paper", surface * CFrame.new((r - 0.5) * 0.6, 0.02 + i * 0.01, (hash(seed + i) - 0.5) * 0.6) * rotY((r - 0.5) * 40), Vector3.new(0.85, 0.02, 1.1), Colors.Paper)
	end
end

-- Small stack of books lying flat.
function Props.bookStack(parent: Instance, surface: CFrame, count: number, seed: number)
	local y = 0
	for i = 1, count do
		local r = hash(seed * 17 + i)
		local thickness = 0.15 + r * 0.1
		detail(parent, "Book", surface * CFrame.new(0, y + thickness / 2, 0) * rotY((r - 0.5) * 25), Vector3.new(0.9, thickness, 1.25), Palette.pick(Palette.Assorted, seed + i))
		y += thickness
	end
end

-- Wall clock facing the reader (`cframe` built with Builder.facing).
function Props.clock(parent: Instance, cframe: CFrame)
	local model = Builder.model(parent, "Clock")
	local axis = cframe * CFrame.Angles(0, math.rad(90), 0)
	detail(model, "Rim", axis, Vector3.new(0.15, 1.6, 1.6), Colors.Charcoal, { Shape = Enum.PartType.Cylinder })
	detail(model, "Face", axis * CFrame.new(0.05, 0, 0), Vector3.new(0.12, 1.4, 1.4), Colors.Paper, { Shape = Enum.PartType.Cylinder })
	detail(model, "HourHand", cframe * CFrame.new(0.15, 0.15, -0.14) * CFrame.Angles(0, 0, math.rad(-45)), Vector3.new(0.08, 0.5, 0.03), Colors.Charcoal)
	detail(model, "MinuteHand", cframe * CFrame.new(0, 0.28, -0.15), Vector3.new(0.06, 0.6, 0.03), Colors.Charcoal)
	return model
end

-- Framed poster facing the reader.
function Props.poster(parent: Instance, cframe: CFrame, width: number, height: number, color: Color3, seed: number?)
	local model = Builder.model(parent, "Poster")
	detail(model, "Frame", cframe, Vector3.new(width, height, 0.08), Colors.Charcoal)
	detail(model, "Print", cframe * CFrame.new(0, 0, -0.05), Vector3.new(width - 0.25, height - 0.25, 0.04), color)
	-- Simple graphic: a band and a block in a contrasting tone.
	local r = hash(seed or 3)
	detail(model, "Band", cframe * CFrame.new(0, height * (0.15 - r * 0.2), -0.08), Vector3.new(width - 0.6, height * 0.12, 0.03), color:Lerp(Colors.Paper, 0.55))
	detail(model, "Block", cframe * CFrame.new(width * (r - 0.5) * 0.4, height * 0.22, -0.08), Vector3.new(width * 0.3, height * 0.25, 0.03), color:Lerp(Colors.Charcoal, 0.35))
	return model
end

-- Framed cork board with pinned notes, facing the reader.
function Props.bulletinBoard(parent: Instance, cframe: CFrame, width: number, height: number, seed: number)
	local model = Builder.model(parent, "BulletinBoard")
	detail(model, "Frame", cframe, Vector3.new(width, height, 0.12), Colors.Trim)
	detail(model, "Cork", cframe * CFrame.new(0, 0, -0.07), Vector3.new(width - 0.3, height - 0.3, 0.04), Colors.Cork, { Material = Materials.Fabric })
	local notes = math.floor(width * height / 3)
	for i = 1, notes do
		local rx, ry = hash(seed * 7 + i), hash(seed * 11 + i * 3)
		local noteWidth = 0.6 + hash(seed + i) * 0.4
		local x = (rx - 0.5) * (width - 1.2)
		local y = (ry - 0.5) * (height - 1.2)
		local color = if i % 3 == 0 then Palette.pick(Palette.Assorted, seed + i):Lerp(Colors.Paper, 0.5) else Colors.Paper
		detail(model, "Note", cframe * CFrame.new(x, y, -0.1) * CFrame.Angles(0, 0, math.rad((rx - 0.5) * 12)), Vector3.new(noteWidth, noteWidth * 1.25, 0.02), color)
	end
	return model
end

---------------------------------------------------------------------------
-- School fixtures
---------------------------------------------------------------------------

--[[
	One locker facing its LookVector. `floor` is the floor point under the
	locker's centre. Returns the body part (used for interaction prompts)
	and, when `openable`, the hinged door leaf (animated by the client).
]]
function Props.locker(parent: Instance, floor: CFrame, color: Color3, seed: number, openable: boolean?)
	local width, height, depth = 1.9, 6.6, 1.4
	local front = -depth / 2 - 0.02
	local seam = color:Lerp(Colors.Charcoal, 0.45)
	local plate = Colors.Paper:Lerp(color, 0.2 + hash(seed) * 0.2)

	if not openable then
		local body = Builder.part(parent, "Locker", floor * CFrame.new(0, height / 2 + 0.3, 0), Vector3.new(width, height, depth), color, {
			Material = Materials.Metal,
		})
		detail(parent, "Seam", floor * CFrame.new(width / 2 - 0.02, height / 2 + 0.3, front), Vector3.new(0.05, height, 0.04), seam)
		for i = 0, 2 do
			detail(parent, "Vent", floor * CFrame.new(0, height - 0.4 - i * 0.22, front), Vector3.new(1.1, 0.07, 0.04), seam)
		end
		detail(parent, "Handle", floor * CFrame.new(width / 2 - 0.35, height / 2 + 0.1, front - 0.04), Vector3.new(0.12, 0.6, 0.08), Colors.Metal, {
			Material = Materials.Metal,
		})
		detail(parent, "NumberPlate", floor * CFrame.new(0, height - 1.2, front), Vector3.new(0.45, 0.25, 0.03), plate)
		return body, nil
	end

	-- Openable: a hollow shell (so the inside is visible), a shelf and a few
	-- things inside, and a door hinged on one edge that swings outwards.
	local metal = { Material = Materials.Metal }
	local midY = height / 2 + 0.3
	local body = Builder.part(parent, "Locker", floor * CFrame.new(0, midY, depth / 2 - 0.05), Vector3.new(width, height, 0.1), color:Lerp(Colors.Charcoal, 0.55), metal)
	for _, side in { -1, 1 } do
		Builder.part(parent, "Side", floor * CFrame.new(side * (width / 2 - 0.05), midY, 0), Vector3.new(0.1, height, depth), color, metal)
	end
	Builder.part(parent, "Top", floor * CFrame.new(0, height + 0.25, 0), Vector3.new(width, 0.1, depth), color, metal)
	Builder.part(parent, "Bottom", floor * CFrame.new(0, 0.35, 0), Vector3.new(width, 0.1, depth), color, metal)
	detail(parent, "Shelf", floor * CFrame.new(0, height - 1.4, -0.1), Vector3.new(width - 0.2, 0.08, depth - 0.3), Colors.DarkMetal)
	detail(parent, "Books", floor * CFrame.new(-0.3, 2.6, -0.2), Vector3.new(0.9, 1.1, 0.8), Colors.Red)
	detail(parent, "Hoodie", floor * CFrame.new(0.35, 4.3, -0.25), Vector3.new(0.6, 1.4, 0.5), Colors.Green, { Material = Materials.Fabric })
	local hinge = floor * CFrame.new(width / 2 - 0.02, height / 2 + 0.3, front - 0.03)
	local door = Builder.hingedLeaf(parent, "LockerDoor", hinge, Vector3.new(width - 0.06, height - 0.1, 0.06), color, -1, -100, {
		Material = Materials.Metal,
	})
	local doorFront = door.CFrame * CFrame.new(0, 0, -0.05)
	for i = 0, 2 do
		Builder.attached(door, "Vent", doorFront * CFrame.new(0, height / 2 - 0.6 - i * 0.22, 0), Vector3.new(1.1, 0.07, 0.04), seam)
	end
	Builder.attached(door, "Handle", doorFront * CFrame.new(-(width / 2) + 0.35, -0.2, -0.02), Vector3.new(0.12, 0.6, 0.08), Colors.Metal, {
		Material = Materials.Metal,
	})
	Builder.attached(door, "NumberPlate", doorFront * CFrame.new(0, height / 2 - 1.5, 0), Vector3.new(0.45, 0.25, 0.03), plate)
	return body, door
end

--[[
	A bank of lockers in area coordinates: lockers every 2 studs from fromX
	to toX along the area's X axis at depth `z`, facing `direction` (local to
	`origin`), on a dark plinth with a top cap. Skips any x in `skip`.
]]
function Props.lockerBank(parent: Instance, origin: CFrame, fromX: number, toX: number, z: number, direction: Vector3, seed: number, skip: { number }?)
	local model = Builder.model(parent, "LockerBank")
	local length = toX - fromX + 2
	local centre = (fromX + toX) / 2
	Builder.part(model, "Plinth", Builder.facing(origin, centre, 0.15, z, direction), Vector3.new(length, 0.3, 1.3), Colors.Charcoal)
	detail(model, "Cap", Builder.facing(origin, centre, 7.0, z, direction), Vector3.new(length + 0.2, 0.2, 1.6), Colors.DarkMetal)
	local index = 0
	for x = fromX, toX, 2 do
		index += 1
		if not (skip and table.find(skip, x)) then
			local color = if (index + seed) % 5 == 0 then Colors.LockerAlt:Lerp(Colors.Locker, hash(seed + index)) else Colors.Locker
			Props.locker(model, Builder.facing(origin, x, 0, z, direction), color, seed * 50 + index)
		end
	end
	return model
end

-- Decorative classroom door on a wall face, facing the reader, with a
-- window, handle, frame and a room sign.
function Props.classroomDoor(parent: Instance, cframe: CFrame, label: string)
	local model = Builder.model(parent, "ClassroomDoor")
	detail(model, "Frame", cframe * CFrame.new(0, 0.2, 0.02), Vector3.new(4.5, 8.3, 0.12), Colors.Trim)
	detail(model, "Door", cframe * CFrame.new(0, 0, -0.06), Vector3.new(3.8, 7.7, 0.12), Colors.Door, { Material = Materials.Wood })
	detail(model, "Window", cframe * CFrame.new(0.8, 1.4, -0.13), Vector3.new(0.8, 1.7, 0.04), Colors.Glass, {
		Material = Materials.Glass,
		Transparency = 0.25,
	})
	detail(model, "Handle", cframe * CFrame.new(-1.45, -0.2, -0.16), Vector3.new(0.5, 0.12, 0.12), Colors.Metal, { Material = Materials.Metal })
	Builder.sign(model, "RoomSign", cframe * CFrame.new(0, 4.75, -0.06), Vector3.new(2.6, 0.75, 0.08), label, Colors.Sign)
	return model
end

-- Cubby storage unit with coloured bins, facing its LookVector.
function Props.cubbies(parent: Instance, floor: CFrame, columns: number, rows: number, seed: number)
	local model = Builder.model(parent, "Cubbies")
	local cell = 1.4
	local width, height = columns * cell + 0.2, rows * cell + 0.2
	Builder.part(model, "Body", floor * CFrame.new(0, height / 2, 0.1), Vector3.new(width, height, 1.2), Colors.LightWood, { Material = Materials.Wood })
	for c = 1, columns do
		for r = 1, rows do
			local x = -width / 2 + 0.1 + cell * (c - 0.5)
			local y = 0.1 + cell * (r - 0.5)
			detail(model, "Bin", floor * CFrame.new(x, y - 0.1, -0.52), Vector3.new(cell - 0.25, cell - 0.4, 0.06), Palette.pick(Palette.Assorted, seed + c * 3 + r))
		end
	end
	return model
end

-- Simple wastebasket.
function Props.bin(parent: Instance, floor: CFrame)
	return Builder.cylinder(parent, "Bin", floor * CFrame.new(0, 1.1, 0), 2.2, 1.4, Colors.DarkMetal, { Material = Materials.Metal })
end

return Props
