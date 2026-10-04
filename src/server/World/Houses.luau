--[[
	Houses

	Reusable neighbour houses (decoration). Three variants share the same
	building blocks — a solid body for collision with layered, non-colliding
	detail on its faces — so they read as real houses from the sidewalk
	without many parts:

		ranch     single storey, side-gable roof, attached garage with a
		          panelled door, covered porch with a railing
		colonial  two storeys, side-gable roof, centred door under a small
		          gabled portico on columns, shutters, brick chimney
		cottage   front-gable roof with a round attic window, full-width
		          porch on columns with railings and a bench, flower box

	Common details: foundation band, corner boards, framed windows with
	sills, mullions and headers (shutters optional), panelled doors with
	knobs, rake boards, ridge caps, gutters and downspouts, a house number
	and a porch light. Only bodies, roofs, porches and steps collide.

	Houses.build(parent, variant, front, style) builds one. `front` is the
	centre of the front wall at ground level, facing the street (its
	LookVector points out of the house); the house extends behind it.
	Local +X is the front's RightVector. Style:
		wall, trim, roof, door, shutter: Color3
		accent: Color3?         gable/porch accent
		foundation: Color3?
		wallMaterial: Enum.Material?   (default WoodPlanks = siding)
		number: string?         house number by the door
		garageSide: number?     ranch: +1 / -1 (local X)
		shutters: boolean?      default true
	Returns a table of local points other builders use (door step, porch
	seat), already converted to world space.
]]

local Builder = require(script.Parent.Builder)
local Palette = require(script.Parent.Palette)

local Colors = Palette.Colors
local Materials = Palette.Materials
local detail = Builder.detail
local rgb = Color3.fromRGB

local GLASS = rgb(70, 88, 104)
local CONCRETE = rgb(168, 164, 156)
local METAL_DARK = rgb(60, 62, 66)

local Houses = {}

-- Rotation that makes a wall face (LookVector) point along local ±X.
local function sideFacing(side: number): CFrame
	return CFrame.Angles(0, -side * math.pi / 2, 0)
end
local BACK_FACING = CFrame.Angles(0, math.pi, 0)

--[[
	A framed window on a wall face. `face` sits on the wall surface at the
	window's centre with its LookVector pointing out of the wall. Options:
	shutters (Color3?), sill (default true), header (default true),
	mullions (default true).
]]
local function window(model: Instance, face: CFrame, width: number, height: number, trim: Color3, options: { [string]: any }?)
	local opts = options or {}
	detail(model, "WindowTrim", face * CFrame.new(0, 0, -0.06), Vector3.new(width + 0.7, height + 0.7, 0.12), trim)
	detail(model, "Window", face * CFrame.new(0, 0, -0.15), Vector3.new(width, height, 0.08), GLASS, {
		Material = Materials.Glass,
		Reflectance = 0.12,
	})
	if opts.mullions ~= false then
		detail(model, "Mullion", face * CFrame.new(0, 0, -0.2), Vector3.new(0.16, height, 0.06), trim)
		detail(model, "Mullion", face * CFrame.new(0, 0, -0.2), Vector3.new(width, 0.16, 0.06), trim)
	end
	if opts.sill ~= false then
		detail(model, "Sill", face * CFrame.new(0, -height / 2 - 0.42, -0.22), Vector3.new(width + 1.0, 0.2, 0.44), trim)
	end
	if opts.header ~= false then
		detail(model, "Header", face * CFrame.new(0, height / 2 + 0.47, -0.16), Vector3.new(width + 1.0, 0.26, 0.3), trim)
	end
	if opts.shutters then
		for _, side in { -1, 1 } do
			local shutter = detail(model, "Shutter", face * CFrame.new(side * (width / 2 + 0.85), 0, -0.1), Vector3.new(width * 0.42, height + 0.3, 0.12), opts.shutters)
			-- Louvre lines.
			for _, y in { height * 0.22, -height * 0.22 } do
				detail(model, "Louvre", shutter.CFrame * CFrame.new(0, y, -0.07), Vector3.new(width * 0.32, 0.08, 0.04), opts.shutters:Lerp(Colors.Charcoal, 0.25))
			end
		end
	end
end

-- A panelled front door. `face` is at the bottom centre of the doorway,
-- on the wall surface, facing out.
local function door(model: Instance, face: CFrame, width: number, height: number, color: Color3, trim: Color3, glassTop: boolean?)
	detail(model, "DoorTrim", face * CFrame.new(0, height / 2 + 0.2, -0.06), Vector3.new(width + 0.9, height + 0.4, 0.12), trim)
	Builder.part(model, "Door", face * CFrame.new(0, height / 2, -0.15), Vector3.new(width, height, 0.16), color, { Material = Materials.Wood })
	local panelColor = color:Lerp(Colors.Charcoal, 0.18)
	detail(model, "DoorPanel", face * CFrame.new(0, height * 0.27, -0.26), Vector3.new(width * 0.62, height * 0.3, 0.06), panelColor)
	if glassTop then
		detail(model, "DoorLight", face * CFrame.new(0, height * 0.7, -0.26), Vector3.new(width * 0.55, height * 0.26, 0.05), GLASS, {
			Material = Materials.Glass,
			Reflectance = 0.12,
		})
	else
		detail(model, "DoorPanel", face * CFrame.new(0, height * 0.68, -0.26), Vector3.new(width * 0.62, height * 0.3, 0.06), panelColor)
	end
	detail(model, "Knob", face * CFrame.new(width * 0.36, height * 0.46, -0.3), Vector3.new(0.3, 0.3, 0.3), Colors.Yellow:Lerp(Colors.Metal, 0.4), {
		Shape = Enum.PartType.Ball,
		Material = Materials.Metal,
	})
end

-- Wall-mounted lantern beside a door.
local function porchLight(model: Instance, face: CFrame)
	detail(model, "LampBracket", face * CFrame.new(0, 0, -0.12), Vector3.new(0.3, 0.5, 0.24), METAL_DARK)
	detail(model, "LampGlass", face * CFrame.new(0, -0.1, -0.42), Vector3.new(0.42, 0.6, 0.42), rgb(240, 222, 170), { Material = Materials.Glass, Transparency = 0.15 })
	detail(model, "LampCap", face * CFrame.new(0, 0.28, -0.42), Vector3.new(0.6, 0.14, 0.6), METAL_DARK)
end

local function houseNumber(model: Instance, face: CFrame, text: string?)
	if text then
		Builder.sign(model, "HouseNumber", face * CFrame.new(0, 0, -0.08), Vector3.new(1.4, 0.6, 0.08), text, rgb(46, 48, 52), rgb(226, 214, 180))
	end
end

-- Foundation band, siding body and corner boards for a box W × H × D whose
-- front face is at local z = 0, centred on local x = cx.
local function body(model: Instance, front: CFrame, cx: number, width: number, height: number, depth: number, style, foundationHeight: number)
	Builder.part(model, "Body", front * CFrame.new(cx, height / 2, depth / 2), Vector3.new(width, height, depth), style.wall, {
		Material = style.wallMaterial or Materials.WoodPlanks,
	})
	Builder.part(model, "Foundation", front * CFrame.new(cx, foundationHeight / 2, depth / 2), Vector3.new(width + 0.35, foundationHeight, depth + 0.35), style.foundation or CONCRETE, {
		Material = Materials.Concrete,
	})
	for _, x in { -1, 1 } do
		for _, z in { 0, depth } do
			local inward = if z == 0 then -0.06 else 0.06
			detail(model, "CornerBoard", front * CFrame.new(cx + x * (width / 2 - 0.15), (height + foundationHeight) / 2, z + inward), Vector3.new(0.55, height - foundationHeight, 0.55), style.trim)
		end
	end
	-- Frieze board under the eaves (front and back).
	for _, z in { -0.07, depth + 0.07 } do
		detail(model, "Frieze", front * CFrame.new(cx, height - 0.3, z), Vector3.new(width + 0.2, 0.6, 0.16), style.trim)
	end
end

-- Vertical downspout against a wall, with an elbow out to the gutter.
local function downspout(model: Instance, front: CFrame, x: number, height: number, eaveOut: number, color: Color3)
	detail(model, "Downspout", front * CFrame.new(x, (height - 0.4) / 2, -0.28), Vector3.new(0.32, height - 0.4, 0.32), color)
	detail(model, "Downspout", front * CFrame.new(x, height - 0.55, -(eaveOut + 0.28) / 2), Vector3.new(0.3, 0.3, eaveOut), color)
	detail(model, "Splash", front * CFrame.new(x, 0.08, -0.7), Vector3.new(0.6, 0.12, 1.0), CONCRETE)
end

-- Porch railing between two local x positions at depth z, standing on a
-- floor at `floorY`.
local function railing(model: Instance, front: CFrame, x1: number, x2: number, z: number, floorY: number, color: Color3)
	local span = math.abs(x2 - x1)
	if span < 0.8 then
		return
	end
	local mid = (x1 + x2) / 2
	Builder.part(model, "Rail", front * CFrame.new(mid, floorY + 2.9, z), Vector3.new(span, 0.22, 0.3), color)
	detail(model, "Rail", front * CFrame.new(mid, floorY + 0.55, z), Vector3.new(span, 0.18, 0.22), color)
	local count = math.max(1, math.floor(span / 0.9))
	for i = 1, count - 1 do
		local x = math.min(x1, x2) + span * i / count
		detail(model, "Baluster", front * CFrame.new(x, floorY + 1.7, z), Vector3.new(0.16, 2.2, 0.16), color)
	end
end

-- Steps up to a raised floor, centred on local x, starting at local z
-- (the edge of the porch/stoop) and descending toward the street.
local function steps(model: Instance, front: CFrame, x: number, z: number, width: number, topY: number, color: Color3)
	local count = math.max(1, math.ceil(topY / 0.42 - 0.01))
	local rise = topY / (count + 0)
	for i = 1, count - 1 do
		local top = topY - rise * i
		Builder.part(model, "Step", front * CFrame.new(x, top / 2, z - 0.45 - 0.9 * (i - 1)), Vector3.new(width, top, 0.9), color, {
			Material = Materials.Concrete,
		})
	end
	-- The last step's front edge, for paths leading up to it.
	return z - 0.9 * (count - 1)
end

---------------------------------------------------------------------------
-- Variants
---------------------------------------------------------------------------

local function ranch(model: Instance, front: CFrame, style)
	local garageSide = style.garageSide or 1
	local W, D, H = 22, 16, 10
	local GW, GD, GH = 11, 18, 9
	local cx = -garageSide * GW / 2
	local gx = cx + garageSide * (W / 2 + GW / 2)
	local floorY = 0.6

	body(model, front, cx, W, H, D, style, 0.8)
	Builder.gableRoof(model, front * CFrame.new(cx, H, D / 2), {
		length = W,
		span = D,
		rise = 4.5,
		eave = 1.6,
		rake = 1.1,
		color = style.roof,
		gableColor = style.wall,
		trimColor = style.trim,
		gutterColor = style.trim,
	})

	-- Garage: steps forward a little, with its own front-facing gable.
	Builder.part(model, "Garage", front * CFrame.new(gx, GH / 2, GD / 2 - 1), Vector3.new(GW, GH, GD), style.wall, {
		Material = style.wallMaterial or Materials.WoodPlanks,
	})
	detail(model, "Foundation", front * CFrame.new(gx, 0.25, GD / 2 - 1), Vector3.new(GW + 0.3, 0.5, GD + 0.3), style.foundation or CONCRETE)
	Builder.gableRoof(model, front * CFrame.new(gx, GH, GD / 2 - 1) * CFrame.Angles(0, math.pi / 2, 0), {
		length = GD,
		span = GW,
		rise = 3.2,
		eave = 1.0,
		rake = 1.2,
		color = style.roof,
		gableColor = style.accent or style.wall,
		gableEnds = { 1 },
		trimColor = style.trim,
		gutterColor = style.trim,
	})
	local garageFront = front * CFrame.new(gx, 0, -1)
	detail(model, "GarageTrim", garageFront * CFrame.new(0, 3.75, -0.05), Vector3.new(9.4, 7.5, 0.1), style.trim)
	local doorColor = style.trim:Lerp(rgb(236, 232, 222), 0.4)
	Builder.part(model, "GarageDoor", garageFront * CFrame.new(0, 3.5, -0.12), Vector3.new(8.4, 7, 0.14), doorColor)
	for _, y in { 1.8, 3.55, 5.3 } do
		detail(model, "DoorGroove", garageFront * CFrame.new(0, y, -0.2), Vector3.new(8.4, 0.08, 0.04), doorColor:Lerp(Colors.Charcoal, 0.3))
	end
	detail(model, "GarageWindows", garageFront * CFrame.new(0, 6.2, -0.2), Vector3.new(7.2, 0.6, 0.04), GLASS, { Material = Materials.Glass })
	for _, x in { -5.0, 5.0 } do
		porchLight(model, garageFront * CFrame.new(x, 5.8, 0))
	end

	-- Front door near the garage, under a long porch roof.
	local doorX = cx + garageSide * 6
	local porchX = cx + garageSide * 2.6
	local porchWidth = 13
	Builder.part(model, "Porch", front * CFrame.new(porchX, floorY / 2, -2.6), Vector3.new(porchWidth, floorY, 5.2), CONCRETE, { Material = Materials.Concrete })
	door(model, front * CFrame.new(doorX, floorY, 0), 3.2, 7, style.door, style.trim, true)
	porchLight(model, front * CFrame.new(doorX - garageSide * 2.6, 6.4, 0))
	houseNumber(model, front * CFrame.new(doorX + garageSide * 2.6, 6.2, 0), style.number)
	-- Tucked under the main roof's gutter line.
	local porchRoofHigh = front * Vector3.new(porchX, 8.9, 0.2)
	local porchRoofLow = front * Vector3.new(porchX, 8.0, -5.9)
	Builder.beam(model, "PorchRoof", porchRoofHigh, porchRoofLow, porchWidth + 0.6, 0.4, style.roof, { Material = Enum.Material.Slate }, front.UpVector)
	detail(model, "Fascia", front * CFrame.new(porchX, 7.85, -5.85), Vector3.new(porchWidth + 0.6, 0.5, 0.2), style.trim)
	local postXs = { porchX - garageSide * 6, porchX, porchX + garageSide * 6 }
	for _, x in postXs do
		Builder.cylinder(model, "PorchPost", front * CFrame.new(x, floorY + 3.7, -4.9), 7.4, 0.55, style.trim)
	end
	railing(model, front, postXs[1], postXs[2], -4.9, floorY, style.trim)
	detail(model, "Step", front * CFrame.new(doorX, 0.15, -5.65), Vector3.new(3.6, 0.3, 0.9), CONCRETE)

	-- Windows: a picture window away from the garage, one beside the door.
	window(model, front * CFrame.new(cx - garageSide * 6.8, 5.2, 0), 6, 4, style.trim)
	window(model, front * CFrame.new(cx - garageSide * 0.6, 5.2, 0), 3, 4, style.trim, { shutters = style.shutters ~= false and style.shutter })
	-- Gable end and back.
	local endX = cx - garageSide * W / 2
	for _, z in { 5, 11 } do
		window(model, front * CFrame.new(endX, 5.2, z) * sideFacing(-garageSide), 3, 3.6, style.trim, { header = false })
	end
	for _, x in { cx - 5, cx + 5 } do
		window(model, front * CFrame.new(x, 5.2, D) * BACK_FACING, 3, 3.6, style.trim, { header = false, sill = false })
	end
	downspout(model, front, cx - garageSide * (W / 2 - 0.3), H, 1.6 + 0.1, style.trim)
	downspout(model, garageFront, garageSide * (GW / 2 - 0.3), GH, 1.0, style.trim)

	return {
		doorStep = front * Vector3.new(doorX, 0, -6.3),
		garageFront = front * Vector3.new(gx, 0, -1),
	}
end

local function colonial(model: Instance, front: CFrame, style)
	local W, D, H = 24, 16, 17
	local floorY = 1.2
	body(model, front, 0, W, H, D, style, floorY)
	Builder.gableRoof(model, front * CFrame.new(0, H, D / 2), {
		length = W,
		span = D,
		rise = 6.5,
		eave = 1.4,
		rake = 1.0,
		color = style.roof,
		gableColor = style.wall,
		trimColor = style.trim,
		gutterColor = style.trim,
	})
	-- Band between the storeys.
	detail(model, "StoreyBand", front * CFrame.new(0, 9.1, -0.08), Vector3.new(W + 0.1, 0.35, 0.16), style.trim)

	-- Stoop, steps and a small gabled portico on two columns.
	Builder.part(model, "Stoop", front * CFrame.new(0, floorY / 2, -2.1), Vector3.new(6.4, floorY, 4.2), CONCRETE, { Material = Materials.Concrete })
	steps(model, front, 0, -4.2, 4, floorY, CONCRETE)
	door(model, front * CFrame.new(0, floorY, 0), 3.4, 7.2, style.door, style.trim, false)
	detail(model, "Transom", front * CFrame.new(0, floorY + 7.75, -0.2), Vector3.new(3.4, 0.7, 0.06), GLASS, { Material = Materials.Glass })
	for _, x in { -2.6, 2.6 } do
		Builder.cylinder(model, "Column", front * CFrame.new(x, floorY + 4.2, -3.7), 8.4, 0.6, style.trim)
	end
	Builder.gableRoof(model, front * CFrame.new(0, floorY + 8.4, -2.0) * CFrame.Angles(0, math.pi / 2, 0), {
		name = "Portico",
		length = 4.2,
		span = 6.2,
		rise = 1.9,
		eave = 0.35,
		rake = 0.4,
		thickness = 0.35,
		color = style.roof,
		gableColor = style.trim,
		gableEnds = { 1 }, -- the end facing the street
	})
	porchLight(model, front * CFrame.new(-3.6, floorY + 5.6, 0))
	houseNumber(model, front * CFrame.new(3.7, floorY + 5.6, 0), style.number)

	local shutters = style.shutters ~= false and style.shutter
	for _, x in { -7, 7 } do
		window(model, front * CFrame.new(x, 5.4, 0), 3.2, 4.6, style.trim, { shutters = shutters })
	end
	for _, x in { -7, 7 } do
		window(model, front * CFrame.new(x, 13.0, 0), 3.2, 4.0, style.trim, { shutters = shutters })
	end
	-- Smaller window over the portico, clear of its ridge.
	window(model, front * CFrame.new(0, 13.5, 0), 2.6, 3.2, style.trim, { sill = false, header = false })
	for _, side in { -1, 1 } do
		window(model, front * CFrame.new(side * W / 2, 5.4, 8) * sideFacing(side), 3, 4.2, style.trim, { header = false })
		window(model, front * CFrame.new(side * W / 2, 13.0, 8) * sideFacing(side), 3, 3.6, style.trim, { header = false })
	end
	for _, x in { -6, 6 } do
		window(model, front * CFrame.new(x, 5.4, D) * BACK_FACING, 3, 4.2, style.trim, { header = false, sill = false })
	end
	-- Gable vent and an outside brick chimney on one end.
	local chimneySide = style.chimneySide or -1
	detail(model, "GableVent", front * CFrame.new(-chimneySide * (W / 2 + 0.05), H + 2.3, D / 2) * sideFacing(-chimneySide), Vector3.new(1.6, 1.6, 0.1), style.trim)
	local chimneyHeight = H + 6.5 + 2.6
	Builder.part(model, "Chimney", front * CFrame.new(chimneySide * (W / 2 + 1.1), chimneyHeight / 2, D / 2), Vector3.new(2.2, chimneyHeight, 3.0), rgb(146, 84, 66), {
		Material = Materials.Brick,
	})
	detail(model, "ChimneyCap", front * CFrame.new(chimneySide * (W / 2 + 1.1), chimneyHeight + 0.2, D / 2), Vector3.new(2.7, 0.4, 3.5), CONCRETE)
	downspout(model, front, W / 2 - 0.3, H, 1.5, style.trim)
	downspout(model, front, -W / 2 + 0.3, H, 1.5, style.trim)

	return {
		doorStep = front * Vector3.new(0, 0, -4.2 - 0.9 * 2 - 0.4),
	}
end

local function cottage(model: Instance, front: CFrame, style)
	local W, D, H = 18, 20, 10.5
	local floorY = 1.0
	body(model, front, 0, W, H, D, style, floorY)
	local accent = style.accent or style.wall
	Builder.gableRoof(model, front * CFrame.new(0, H, D / 2) * CFrame.Angles(0, math.pi / 2, 0), {
		length = D,
		span = W,
		rise = 7.5,
		eave = 1.2,
		rake = 1.4,
		color = style.roof,
		gableColor = accent,
		gableMaterial = Enum.Material.WoodPlanks,
		trimColor = style.trim,
		gutterColor = style.trim,
	})
	-- Round attic window in the front gable.
	local attic = front * CFrame.new(0, H + 2.6, -0.32) * CFrame.Angles(0, math.pi / 2, 0)
	detail(model, "AtticTrim", attic, Vector3.new(0.14, 2.8, 2.8), style.trim, { Shape = Enum.PartType.Cylinder })
	detail(model, "AtticWindow", attic * CFrame.new(0.08, 0, 0), Vector3.new(0.1, 2.2, 2.2), GLASS, {
		Shape = Enum.PartType.Cylinder,
		Material = Materials.Glass,
	})
	detail(model, "AtticMullion", front * CFrame.new(0, H + 2.6, -0.5), Vector3.new(0.14, 2.2, 0.06), style.trim)

	-- Full-width porch with a shed roof, columns on piers and railings.
	local porchDepth = 6.2
	Builder.part(model, "Porch", front * CFrame.new(0, floorY / 2, -porchDepth / 2), Vector3.new(W + 1, floorY, porchDepth), style.trim:Lerp(Colors.Wood, 0.55), {
		Material = Materials.WoodPlanks,
	})
	local doorX = 3.6
	local stepEdge = steps(model, front, doorX, -porchDepth, 4, floorY, CONCRETE)
	door(model, front * CFrame.new(doorX, floorY, 0), 3.2, 7, style.door, style.trim, true)
	porchLight(model, front * CFrame.new(doorX + 2.6, floorY + 5.4, 0))
	houseNumber(model, front * CFrame.new(doorX - 2.6, floorY + 5.6, 0), style.number)
	local roofHigh = front * Vector3.new(0, 9.4, 0.2)
	local roofLow = front * Vector3.new(0, 8.4, -porchDepth - 0.7)
	Builder.beam(model, "PorchRoof", roofHigh, roofLow, W + 1.6, 0.4, style.roof, { Material = Enum.Material.Slate }, front.UpVector)
	detail(model, "Fascia", front * CFrame.new(0, 8.25, -porchDepth - 0.65), Vector3.new(W + 1.6, 0.5, 0.2), style.trim)
	local postZ = -porchDepth + 0.5
	local posts = { -8.8, -3.0, 8.8 }
	for _, x in posts do
		Builder.part(model, "Pier", front * CFrame.new(x, floorY + 1.0, postZ), Vector3.new(0.9, 2.0, 0.9), accent:Lerp(Colors.Charcoal, 0.15))
		Builder.cylinder(model, "Column", front * CFrame.new(x, floorY + 4.6, postZ), 5.2, 0.55, style.trim)
	end
	railing(model, front, -8.4, -3.4, postZ, floorY, style.trim)
	railing(model, front, -2.6, doorX - 2.3, postZ, floorY, style.trim)
	railing(model, front, doorX + 2.3, 8.4, postZ, floorY, style.trim)

	-- Porch bench against the wall (someone may sit here).
	local benchFloor = front * CFrame.new(-6, floorY, -1.1) * CFrame.Angles(0, 0, 0)
	local bench = Builder.model(model, "PorchBench")
	for _, z in { -0.35, 0.05, 0.45 } do
		Builder.part(bench, "Slat", benchFloor * CFrame.new(0, 1.22, z - 0.4), Vector3.new(4.6, 0.16, 0.36), Colors.LightWood, { Material = Materials.Wood })
	end
	detail(bench, "Back", benchFloor * CFrame.new(0, 2.2, 0.35), Vector3.new(4.6, 1.2, 0.16), Colors.LightWood, { Material = Materials.Wood })
	for _, x in { -2.1, 2.1 } do
		detail(bench, "Leg", benchFloor * CFrame.new(x, 0.6, -0.4), Vector3.new(0.2, 1.2, 1.1), Colors.DarkWood)
	end

	-- Windows (front window gets a flower box).
	local shutters = style.shutters ~= false and style.shutter
	local frontWindow = front * CFrame.new(-4.4, floorY + 4.6, 0)
	window(model, frontWindow, 3.4, 4.4, style.trim, { shutters = shutters })
	detail(model, "FlowerBox", frontWindow * CFrame.new(0, -3.0, -0.45), Vector3.new(4.2, 0.6, 0.6), style.trim:Lerp(Colors.Wood, 0.5))
	for i = 0, 4 do
		detail(model, "Flowers", frontWindow * CFrame.new(-1.7 + i * 0.85, -2.5, -0.45), Vector3.new(0.6, 0.6, 0.6), Palette.pick({ rgb(214, 96, 104), rgb(236, 196, 90), rgb(170, 120, 200), rgb(86, 140, 84) }, i + 1), {
			Shape = Enum.PartType.Ball,
			Material = Materials.Grass,
		})
	end
	for _, side in { -1, 1 } do
		for _, z in { 6, 14 } do
			window(model, front * CFrame.new(side * W / 2, floorY + 4.4, z) * sideFacing(side), 2.8, 3.8, style.trim, { header = false })
		end
	end
	for _, x in { -4.5, 4.5 } do
		window(model, front * CFrame.new(x, floorY + 4.4, D) * BACK_FACING, 2.8, 3.8, style.trim, { header = false, sill = false })
	end
	-- Chimney rising through the roof slope.
	local chimneyX = (style.chimneySide or 1) * 4.2
	Builder.part(model, "Chimney", front * CFrame.new(chimneyX, H + 4.6, 13), Vector3.new(2.2, 11, 2.2), rgb(150, 92, 72), { Material = Materials.Brick })
	detail(model, "ChimneyCap", front * CFrame.new(chimneyX, H + 10.2, 13), Vector3.new(2.6, 0.3, 2.6), CONCRETE)
	downspout(model, front, -W / 2 + 0.3, H, 1.3, style.trim)

	return {
		doorStep = front * Vector3.new(doorX, 0, stepEdge - 0.5),
		porchBench = benchFloor,
		benchSeatTop = 1.3,
	}
end

local VARIANTS = {
	ranch = ranch,
	colonial = colonial,
	cottage = cottage,
}

function Houses.build(parent: Instance, variant: string, front: CFrame, style: { [string]: any })
	local build = VARIANTS[variant]
	assert(build, `[Houses] Unknown house variant "{variant}"`)
	local model = Builder.model(parent, `House_{variant}`)
	-- Houses never change; let the engine stream the whole thing at once.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model, build(model, front, style)
end

return Houses
