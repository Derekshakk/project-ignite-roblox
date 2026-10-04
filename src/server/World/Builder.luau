--[[
	Builder

	Reusable helpers for constructing the prototype world from code: parts,
	rooms with framed door/window openings and wall trim, lights, signs, and
	the gameplay hooks (interaction prompts, zones, travel destinations).
	Furniture and small props live in Props.luau; colours and materials in
	Palette.luau.

	Conventions:
	- Every area is built relative to an `origin` CFrame at the centre of its
	  floor, so areas can be moved by changing one value in WorldBuilder.
	- `y` values passed to Builder.at are heights above the floor surface.
	- Gameplay hooks only tag instances and set attributes (Constants/World);
	  the rules for what they do live in shared data and the controller.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Activities = require(Shared.Data.Activities)
local Zones = require(Shared.Data.Zones)
local Palette = require(script.Parent.Palette)

local Colors = Palette.Colors
local Materials = Palette.Materials

local Builder = {}

Builder.FLOOR_TOP = 0.2 -- floors sit just above the ground (y = 0)
Builder.WALL_THICKNESS = 1

local TRIM_DEPTH = 0.15
local BASEBOARD_HEIGHT = 0.5
local FRAME_WIDTH = 0.35

-- Position relative to an area origin, with y measured from the floor.
function Builder.at(origin: CFrame, x: number, y: number, z: number): CFrame
	return origin * CFrame.new(x, Builder.FLOOR_TOP + y, z)
end

-- Like Builder.at, but facing `direction` (in the origin's local space).
function Builder.facing(origin: CFrame, x: number, y: number, z: number, direction: Vector3): CFrame
	local position = Builder.at(origin, x, y, z).Position
	return CFrame.lookAt(position, position + origin:VectorToWorldSpace(direction))
end

function Builder.part(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Materials.Matte
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A WedgePart: full height at the back (+Z), sloping down to the front
-- (the CFrame's LookVector side).
function Builder.wedge(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Materials.Matte
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A stretched sphere filling `size` (bushes, canopies, hair, rounded
-- caps). Rendered with a SpecialMesh, so it costs about the same as a
-- block; collision (if any) is the box.
function Builder.ellipsoid(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	local part = Builder.part(parent, name, cframe, size, color, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

--[[
	A plank from point `a` to point `b` (world space): `width` runs
	horizontally across it (or along `up`'s perpendicular), `thickness`
	along its normal. Used for roof planes, rafters, railings and arms.
]]
function Builder.beam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, thickness: number, color: Color3, props: { [string]: any }?, up: Vector3?)
	local frame = CFrame.lookAt((a + b) / 2, b, up or Vector3.yAxis)
	return Builder.part(parent, name, frame, Vector3.new(width, thickness, (b - a).Magnitude), color, props)
end

--[[
	A pitched (gable) roof. `base` is the centre of the top of the walls it
	covers; the ridge runs along the base's local X, the slopes fall toward
	its local ±Z. Options:
		length, span: number    wall extents along X (ridge) and Z
		rise: number            ridge height above the wall top
		eave: number?           overhang past the walls along Z (default 1.2)
		rake: number?           overhang past the gable ends (default 0.8)
		thickness: number?      default 0.5
		color: Color3, material: Enum.Material?
		gableColor: Color3?     fill the triangles at both ends (wall colour)
		gableEnds: { number }?  which ends to fill: 1 = +X, -1 = -X (default both)
		trimColor: Color3?      rake boards along the sloped edges
		gutterColor: Color3?    gutters along the eaves
		gutterSides: { number }?  which eaves: 1 = +Z, -1 = -Z (default both)
	Returns the model and the eave drop (how far below the wall top the
	eave edge sits), for downspouts.
]]
function Builder.gableRoof(parent: Instance, base: CFrame, options: { [string]: any })
	local model = Builder.model(parent, options.name or "Roof")
	local length, span, rise = options.length, options.span, options.rise
	local eave, rake = options.eave or 1.2, options.rake or 0.8
	local thickness = options.thickness or 0.5
	local material = options.material or Enum.Material.Slate
	local half = span / 2
	local slope = rise / half
	local run = half + eave
	local drop = eave * slope
	local width = length + rake * 2

	local ridge = base * Vector3.new(0, rise, 0)
	for _, side in { 1, -1 } do
		local eavePoint = base * Vector3.new(0, -drop, side * run)
		local plane = Builder.beam(model, "RoofPlane", ridge, eavePoint, width, thickness, options.color, { Material = material }, base.UpVector)
		-- Lift by half the thickness so the underside follows the pitch line.
		plane.CFrame *= CFrame.new(0, thickness / 2, 0)
		if options.gutterColor and table.find(options.gutterSides or { 1, -1 }, side) then
			local gutter = Builder.detail(model, "Gutter", base * CFrame.new(0, -drop - 0.12, side * (run + 0.12)), Vector3.new(width, 0.42, 0.42), options.gutterColor, {
				Shape = Enum.PartType.Cylinder,
				Material = Materials.Metal,
			})
			gutter.CastShadow = false
		end
		if options.trimColor then
			for _, endSide in { 1, -1 } do
				local x = endSide * (width / 2 - 0.12)
				local from = base * Vector3.new(x, rise + 0.05, 0)
				local to = base * Vector3.new(x, -drop - 0.05, side * (run + 0.05))
				Builder.beam(model, "RakeBoard", from, to, 0.28, thickness + 0.25, options.trimColor, { CanCollide = false, CastShadow = false }, base.UpVector)
			end
		end
	end
	-- Rounded ridge cap.
	Builder.detail(model, "Ridge", base * CFrame.new(0, rise + thickness * 0.75, 0), Vector3.new(width + 0.1, 0.6, 0.6), (options.color :: Color3):Lerp(Color3.new(0, 0, 0), 0.15), {
		Shape = Enum.PartType.Cylinder,
		Material = material,
	})

	if options.gableColor then
		for _, endSide in options.gableEnds or { 1, -1 } do
			local x = endSide * (length / 2 - 0.3)
			local size = Vector3.new(0.6, rise, half)
			-- WedgeParts are tall at the back: turn each half so its tall
			-- edge meets the ridge.
			Builder.wedge(model, "Gable", base * CFrame.new(x, rise / 2, half / 2) * CFrame.Angles(0, math.pi, 0), size, options.gableColor, {
				Material = options.gableMaterial or Materials.WoodPlanks,
			})
			Builder.wedge(model, "Gable", base * CFrame.new(x, rise / 2, -half / 2), size, options.gableColor, {
				Material = options.gableMaterial or Materials.WoodPlanks,
			})
		end
	end
	return model, drop
end

-- Upright cylinder centred at `cframe` (legs, posts, bins, lamp stems).
function Builder.cylinder(parent: Instance, name: string, cframe: CFrame, height: number, diameter: number, color: Color3, props: { [string]: any }?)
	local part = Builder.part(parent, name, cframe * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, diameter, diameter), color, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Small detail parts that shouldn't block movement or cast shadows.
function Builder.detail(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	local part = Builder.part(parent, name, cframe, size, color, props)
	part.CanCollide = false
	part.CastShadow = false
	return part
end

function Builder.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Builder.pointLight(part: BasePart, brightness: number, range: number, color: Color3?, shadows: boolean?)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color or Colors.Light
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

--[[
	Recessed ceiling fixture: a trim housing with a soft diffuser panel and a
	warm point light. Options: brightness, range, shadows (default true),
	length (along X), width (along Z).
]]
function Builder.ceilingLight(parent: Instance, origin: CFrame, x: number, z: number, roomHeight: number, options: { [string]: any }?)
	options = options or {}
	local length, width = options.length or 4, options.width or 2
	local fixture = Builder.model(parent, "CeilingLight")
	Builder.detail(fixture, "Housing", Builder.at(origin, x, roomHeight - 0.08, z), Vector3.new(length + 0.4, 0.16, width + 0.4), Colors.CeilingTrim)
	local diffuser = Builder.detail(fixture, "Diffuser", Builder.at(origin, x, roomHeight - 0.18, z), Vector3.new(length, 0.06, width), Colors.LightFixture, {
		Material = Materials.Neon,
		Transparency = 0.25,
	})
	Builder.pointLight(diffuser, options.brightness or 0.75, options.range or 24, Colors.Light, options.shadows ~= false)
	return fixture
end

--[[
	A sign with text. `cframe` faces the reader: the text is drawn on the
	part's front face (its LookVector side), so build it with
	CFrame.lookAt(position, position + directionTowardReader).
]]
function Builder.sign(parent: Instance, name: string, cframe: CFrame, size: Vector3, text: string, color: Color3, textColor: Color3?)
	local part = Builder.detail(parent, name, cframe, size, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor or Colors.Charcoal
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label
	return part
end

---------------------------------------------------------------------------
-- Walls and rooms
---------------------------------------------------------------------------

--[[
	Opening in a wall, measured along the wall's local X axis:
		center, width: number
		bottom: number?  default 0 (a doorway)
		top: number      height of the top edge above the floor
		glass: boolean?  fill with a framed window pane
		threshold: boolean?  floor strip under a doorway (default true)
		frame: boolean?  door frame (default true for doorways lower than
		                 the wall)
]]
export type Opening = {
	center: number,
	width: number,
	bottom: number?,
	top: number,
	glass: boolean?,
	threshold: boolean?,
	frame: boolean?,
}

--[[
	Wall style:
		color, material
		wainscot: { height, color, material? }?   lower band in another finish
		trimColor: Color3?                         baseboards, rails, frames
		interiorSide: number?   +1 / -1: which local-Z side faces the room;
		                        trim is placed on that side only
]]
export type WallStyle = {
	color: Color3,
	material: Enum.Material?,
	wainscot: { height: number, color: Color3, material: Enum.Material? }?,
	trimColor: Color3?,
	interiorSide: number?,
}

-- Spans along [-half, half] not covered by the given openings.
local function solidSpans(half: number, openings: { Opening }): { { number } }
	local spans = {}
	local cursor = -half
	for _, opening in openings do
		local left = opening.center - opening.width / 2
		if left > cursor then
			table.insert(spans, { cursor, left })
		end
		cursor = math.max(cursor, opening.center + opening.width / 2)
	end
	if cursor < half then
		table.insert(spans, { cursor, half })
	end
	return spans
end

--[[
	A straight wall. `baseCFrame` is the centre of the wall's base (at the
	floor surface); the wall runs along the CFrame's local X axis.
]]
function Builder.wall(parent: Instance, baseCFrame: CFrame, length: number, height: number, openings: { Opening }, style: WallStyle)
	local thickness = Builder.WALL_THICKNESS
	local wainscot = style.wainscot
	local trimColor = style.trimColor or Colors.Trim
	local side = style.interiorSide

	local function block(fromX: number, toX: number, fromY: number, toY: number, color: Color3, material: Enum.Material?)
		if toX - fromX <= 0.01 or toY - fromY <= 0.01 then
			return
		end
		Builder.part(
			parent,
			"Wall",
			baseCFrame * CFrame.new((fromX + toX) / 2, (fromY + toY) / 2, 0),
			Vector3.new(toX - fromX, toY - fromY, thickness),
			color,
			{ Material = material or Materials.Plaster }
		)
	end

	-- Splits a wall piece at the wainscot line so the lower band can differ.
	local function segment(fromX: number, toX: number, fromY: number, toY: number)
		if wainscot and fromY < wainscot.height and toY > wainscot.height then
			block(fromX, toX, fromY, wainscot.height, wainscot.color, wainscot.material)
			block(fromX, toX, wainscot.height, toY, style.color, style.material)
		elseif wainscot and toY <= wainscot.height then
			block(fromX, toX, fromY, toY, wainscot.color, wainscot.material)
		else
			block(fromX, toX, fromY, toY, style.color, style.material)
		end
	end

	-- Strip of trim on the interior face (baseboard, chair rail).
	local function trimStrip(name: string, fromX: number, toX: number, y: number, stripHeight: number)
		if not side or toX - fromX <= 0.05 then
			return
		end
		Builder.detail(
			parent,
			name,
			baseCFrame * CFrame.new((fromX + toX) / 2, y, side * (thickness / 2 + TRIM_DEPTH / 2)),
			Vector3.new(toX - fromX, stripHeight, TRIM_DEPTH),
			trimColor
		)
	end

	local sorted = table.clone(openings)
	table.sort(sorted, function(a, b)
		return a.center < b.center
	end)

	local cursor = -length / 2
	for _, opening in sorted do
		local left = opening.center - opening.width / 2
		local right = opening.center + opening.width / 2
		local bottom = opening.bottom or 0
		segment(cursor, left, -Builder.FLOOR_TOP, height)
		segment(left, right, -Builder.FLOOR_TOP, bottom)
		segment(left, right, opening.top, height)

		if opening.glass then
			Builder.part(parent, "Window", baseCFrame * CFrame.new(opening.center, (bottom + opening.top) / 2, 0), Vector3.new(opening.width, opening.top - bottom, 0.15), Colors.Glass, {
				Material = Materials.Glass,
				Transparency = 0.6,
				CastShadow = false,
			})
			-- Frame (top, sides, mullion) and an interior sill.
			local depth = thickness + 0.2
			local frameHeight = opening.top - bottom
			local midY = (bottom + opening.top) / 2
			Builder.detail(parent, "WindowFrame", baseCFrame * CFrame.new(opening.center, opening.top - FRAME_WIDTH / 2, 0), Vector3.new(opening.width, FRAME_WIDTH, depth), Colors.OffWhite)
			Builder.detail(parent, "WindowFrame", baseCFrame * CFrame.new(left + FRAME_WIDTH / 2, midY, 0), Vector3.new(FRAME_WIDTH, frameHeight, depth), Colors.OffWhite)
			Builder.detail(parent, "WindowFrame", baseCFrame * CFrame.new(right - FRAME_WIDTH / 2, midY, 0), Vector3.new(FRAME_WIDTH, frameHeight, depth), Colors.OffWhite)
			Builder.detail(parent, "Mullion", baseCFrame * CFrame.new(opening.center, midY, 0), Vector3.new(0.2, frameHeight, depth - 0.1), Colors.OffWhite)
			if side then
				Builder.detail(parent, "Sill", baseCFrame * CFrame.new(opening.center, bottom + 0.1, side * 0.35), Vector3.new(opening.width + 0.6, 0.2, thickness + 0.7), Colors.OffWhite)
			end
		elseif bottom == 0 then
			if opening.threshold ~= false then
				Builder.part(parent, "Threshold", baseCFrame * CFrame.new(opening.center, -Builder.FLOOR_TOP, 0), Vector3.new(opening.width, Builder.FLOOR_TOP * 2, thickness), Colors.Trim)
			end
			if opening.frame ~= false and opening.top < height then
				-- Jambs and header, proud of the wall on both faces.
				local depth = thickness + 0.3
				Builder.detail(parent, "DoorFrame", baseCFrame * CFrame.new(left - FRAME_WIDTH / 2, opening.top / 2, 0), Vector3.new(FRAME_WIDTH, opening.top, depth), trimColor)
				Builder.detail(parent, "DoorFrame", baseCFrame * CFrame.new(right + FRAME_WIDTH / 2, opening.top / 2, 0), Vector3.new(FRAME_WIDTH, opening.top, depth), trimColor)
				Builder.detail(parent, "DoorFrame", baseCFrame * CFrame.new(opening.center, opening.top + FRAME_WIDTH / 2, 0), Vector3.new(opening.width + FRAME_WIDTH * 2, FRAME_WIDTH, depth), trimColor)
			end
		end
		cursor = right
	end
	segment(cursor, length / 2, -Builder.FLOOR_TOP, height)

	-- Baseboards everywhere except doorways; chair rail where the wall
	-- isn't interrupted below the wainscot line.
	local doorways, lowOpenings = {}, {}
	for _, opening in sorted do
		local bottom = opening.bottom or 0
		if bottom == 0 then
			table.insert(doorways, { center = opening.center, width = opening.width + FRAME_WIDTH * 2 })
		end
		if wainscot and bottom < wainscot.height then
			table.insert(lowOpenings, { center = opening.center, width = opening.width + FRAME_WIDTH * 2 })
		end
	end
	for _, span in solidSpans(length / 2, doorways) do
		trimStrip("Baseboard", span[1], span[2], BASEBOARD_HEIGHT / 2, BASEBOARD_HEIGHT)
	end
	if wainscot then
		for _, span in solidSpans(length / 2, lowOpenings) do
			trimStrip("ChairRail", span[1], span[2], wainscot.height, 0.22)
		end
	end
end

--[[
	A box room centred on `origin`. Options:
		name, width (X), depth (Z), height
		floorColor, floorMaterial
		wallColor, wallMaterial, wainscot, trimColor   (see WallStyle)
		ceilingColor
		ceilingGrid: number?   spacing of ceiling tile strips (studs)
		walls = { north = {Opening}, south = ..., east = ..., west = ... }
		  north/south openings are measured along X; east/west along Z.
		  Set a side to `false` to skip it (when a neighbouring area
		  provides that wall).
	Returns the room Model.
]]
function Builder.room(parent: Instance, origin: CFrame, options: { [string]: any }): Model
	local model = Builder.model(parent, options.name)
	local width, depth, height = options.width, options.depth, options.height
	local thickness = Builder.WALL_THICKNESS
	local wallHeight = height + 1 -- includes the ceiling slab
	local walls = options.walls or {}

	Builder.part(model, "Floor", origin, Vector3.new(width, Builder.FLOOR_TOP * 2, depth), options.floorColor, {
		Material = options.floorMaterial or Materials.Matte,
	})
	Builder.part(model, "Ceiling", Builder.at(origin, 0, height + 0.5, 0), Vector3.new(width, 1, depth), options.ceilingColor or Colors.Ceiling, {
		Material = Materials.Plaster,
	})
	if options.ceilingGrid then
		local spacing = options.ceilingGrid
		for x = -width / 2 + spacing, width / 2 - 0.01, spacing do
			Builder.detail(model, "CeilingGrid", Builder.at(origin, x, height - 0.05, 0), Vector3.new(0.15, 0.1, depth), Colors.CeilingTrim)
		end
		for z = -depth / 2 + spacing, depth / 2 - 0.01, spacing do
			Builder.detail(model, "CeilingGrid", Builder.at(origin, 0, height - 0.05, z), Vector3.new(width, 0.1, 0.15), Colors.CeilingTrim)
		end
	end

	local sides = {
		-- base CFrame (wall runs along local X), length, interior side (local Z)
		north = { CFrame.new(0, Builder.FLOOR_TOP, -depth / 2 - thickness / 2), width + thickness * 2, 1 },
		south = { CFrame.new(0, Builder.FLOOR_TOP, depth / 2 + thickness / 2), width + thickness * 2, -1 },
		-- Rotated so local X points along +Z (and local +Z along world -X).
		west = { CFrame.new(-width / 2 - thickness / 2, Builder.FLOOR_TOP, 0) * CFrame.Angles(0, -math.pi / 2, 0), depth, -1 },
		east = { CFrame.new(width / 2 + thickness / 2, Builder.FLOOR_TOP, 0) * CFrame.Angles(0, -math.pi / 2, 0), depth, 1 },
	}
	for side, spec in sides do
		local openings = walls[side]
		if openings ~= false then
			Builder.wall(model, origin * spec[1], spec[2], wallHeight, openings or {}, {
				color = options.wallColor,
				material = options.wallMaterial,
				wainscot = options.wainscot,
				trimColor = options.trimColor,
				interiorSide = spec[3],
			})
		end
	end
	return model
end

---------------------------------------------------------------------------
-- Gameplay hooks
---------------------------------------------------------------------------

--[[
	Adds a tagged ProximityPrompt to `part`. The client InteractionController
	finds it by tag and routes triggers to the GameController.
]]
function Builder.prompt(part: BasePart, interactionType: string, interactionId: string, props: { [string]: any }?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Interact"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	if props then
		for key, value in props do
			(prompt :: any)[key] = value
		end
	end
	prompt:SetAttribute(World.Attributes.InteractionType, interactionType)
	prompt:SetAttribute(World.Attributes.InteractionId, interactionId)
	CollectionService:AddTag(prompt, World.Tags.Interactable)
	prompt.Parent = part
	return prompt
end

-- Prompt for an activity, with labels taken from the activity data.
function Builder.activityPrompt(part: BasePart, activityId: string)
	local activity = Activities.get(activityId)
	if not activity then
		warn(`[Builder] Unknown activity "{activityId}"; prompt not created.`)
		return nil
	end
	return Builder.prompt(part, World.InteractionTypes.Activity, activityId, {
		ActionText = activity.actionText,
		ObjectText = activity.objectText,
		HoldDuration = activity.holdDuration or 0,
	})
end

local function volume(parent: Instance, name: string, cframe: CFrame, size: Vector3): Part
	return Builder.part(parent, name, cframe, size, Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	})
end

--[[
	Invisible box the client checks the player's position against. If the
	zone's data has an `ambientSound` with a soundId, a quiet looping 3D
	sound is placed in it (routed through the environment sound group by
	the client).
]]
function Builder.zone(parent: Instance, zoneId: string, cframe: CFrame, size: Vector3)
	local part = volume(parent, `Zone_{zoneId}`, cframe, size)
	part:SetAttribute(World.Attributes.ZoneId, zoneId)
	CollectionService:AddTag(part, World.Tags.Zone)

	local zone = Zones.get(zoneId)
	local ambient = zone and zone.ambientSound
	if ambient and ambient.soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Ambience"
		sound.SoundId = ambient.soundId
		sound.Volume = ambient.volume or 0.3
		sound.Looped = true
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = math.max(size.X, size.Z) / 2
		sound.RollOffMaxDistance = math.max(size.X, size.Z) * 1.5
		sound.Playing = true
		CollectionService:AddTag(sound, World.Tags.AmbientSound)
		sound.Parent = part
	end
	return part
end

-- Invisible box marking an area (bedroom, hallway, …) for the client's
-- area detection: ambience, area titles and the objective marker.
function Builder.areaVolume(parent: Instance, areaId: string, cframe: CFrame, size: Vector3)
	local part = volume(parent, `Area_{areaId}`, cframe, size)
	part:SetAttribute(World.Attributes.AreaId, areaId)
	CollectionService:AddTag(part, World.Tags.Area)
	return part
end

--[[
	A seat the player can be placed in by the server (SeatService). Seats
	start Disabled so walking into them never sits you down. Registers the
	seat in `context.seats`. `listenTo` (an NPC id) makes that NPC talk to
	the player while seated.
]]
function Builder.seat(parent: Instance, context: any, seatId: string, cframe: CFrame, size: Vector3, color: Color3, listenTo: string?): Seat
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = size
	seat.CFrame = cframe
	seat.Color = color
	seat.Material = Materials.Matte
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Disabled = true
	if listenTo then
		seat:SetAttribute(World.Attributes.ListenTo, listenTo)
	end
	seat.Parent = parent
	if context.seats[seatId] then
		warn(`[Builder] Duplicate seat "{seatId}".`)
	end
	context.seats[seatId] = seat
	return seat
end

--[[
	A door leaf that rotates around a vertical hinge. `hinge` is a CFrame on
	the hinge line (at the leaf's mid-height); the leaf extends from it
	along the hinge's local X by `side` (+1/-1). `openAngle` (degrees, sign
	sets the direction) is how far it swings. The client animates it.
	Leaves don't collide, so a half-open door can never trap the player.
]]
function Builder.hingedLeaf(parent: Instance, name: string, hinge: CFrame, size: Vector3, color: Color3, side: number, openAngle: number, props: { [string]: any }?)
	local offset = CFrame.new(side * size.X / 2, 0, 0)
	local leaf = Builder.part(parent, name, hinge * offset, size, color, props)
	leaf.CanCollide = false
	leaf:SetAttribute(World.Attributes.HingeCFrame, hinge)
	leaf:SetAttribute(World.Attributes.ClosedOffset, offset)
	leaf:SetAttribute(World.Attributes.OpenAngle, openAngle)
	return leaf
end

-- Unanchored detail welded to a moving part (e.g. a handle on a door leaf).
--[[
	A door that uses the shared door system (client World/Doors): a hinged
	leaf plus, by default, an "Open Door" prompt. Every door in the world
	is built with this, so they all open, close, sound and behave the same.
	Options:
		name: string?
		hinge: CFrame        on the hinge line; the leaf extends along the
		                     hinge's local X toward `side`
		size: Vector3        leaf size (X = width)
		color: Color3, material: Enum.Material?
		side: number         1 or -1
		openAngle: number    degrees around the hinge's local Y; the sign
		                     picks the swing direction (choose the side with
		                     free space, so the door never swings into a wall)
		doorId: string       used by prompts and objective markers
		objectText: string?  prompt label, e.g. "Front door"
		prompt: boolean?     default true (false for the second leaf of a pair)
		group: string?       leaves in a group open and close together
		autoClose: number?   seconds before closing again by itself
		locked: string?      if set, the door is locked: trying it rattles it
		                     and shows this message
		solid: boolean?      collides while closed (default true)
]]
function Builder.door(parent: Instance, options: { [string]: any }): BasePart
	local leaf = Builder.hingedLeaf(parent, options.name or "Door", options.hinge, options.size, options.color, options.side, options.openAngle, {
		Material = options.material or Materials.Wood,
	})
	leaf.CanCollide = options.solid ~= false
	leaf:SetAttribute(World.Attributes.DoorId, options.doorId)
	if options.group then
		leaf:SetAttribute(World.Attributes.DoorGroup, options.group)
	end
	if options.autoClose then
		leaf:SetAttribute(World.Attributes.AutoClose, options.autoClose)
	end
	if options.locked then
		leaf:SetAttribute(World.Attributes.Locked, true)
		leaf:SetAttribute(World.Attributes.LockedMessage, options.locked)
	end
	CollectionService:AddTag(leaf, World.Tags.Door)
	if options.prompt ~= false then
		Builder.prompt(leaf, World.InteractionTypes.Door, options.doorId, {
			ActionText = if options.locked then "Try Door" else "Open Door",
			ObjectText = options.objectText or "",
			MaxActivationDistance = 8,
		}):SetAttribute(World.Attributes.Feedback, "none")
	end
	return leaf
end

-- The ReplicatedStorage folder ambient-life templates and route markers
-- live in (see AmbientTemplates), created on first use.
function Builder.ambientFolder(): Folder
	local ReplicatedStorageService = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorageService:FindFirstChild(World.AmbientFolder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = World.AmbientFolder
		folder.Parent = ReplicatedStorageService
	end
	local markers = folder:FindFirstChild("Markers")
	if not markers then
		markers = Instance.new("Folder")
		markers.Name = "Markers"
		markers.Parent = folder
	end
	return folder :: Folder
end

--[[
	A named point that ambient pedestrian routes (Data/Ambient) can use
	instead of fixed coordinates, e.g. the foot of a neighbour's steps.
	Stored as a Vector3 attribute in ReplicatedStorage so it is available
	to the client regardless of streaming.
]]
function Builder.routeMarker(name: string, position: Vector3)
	(Builder.ambientFolder():FindFirstChild("Markers") :: Instance):SetAttribute(name, position)
end

-- An invisible route point for the objective marker ("Waypoint:<id>").
function Builder.waypoint(parent: Instance, waypointId: string, position: Vector3): Part
	local part = volume(parent, `Waypoint_{waypointId}`, CFrame.new(position), Vector3.new(1, 1, 1))
	part:SetAttribute(World.Attributes.WaypointId, waypointId)
	CollectionService:AddTag(part, World.Tags.Waypoint)
	return part
end

--[[
	Exterior walls around a building, following its footprint: `points`
	are the outer faces of the interior walls (Vector2 x/z, world space, in
	order around the building). Each edge gets a wall just outside it, so
	the inside of the rooms is untouched. Options:
		color, material
		height: number | { number }    per edge (index i = points[i]→points[i+1])
		openings: { [edgeIndex]: { { at, width, top, bottom? } } }
		                               `at` is the world x (or z) of the
		                               opening's centre along that edge
		windows: { [edgeIndex]: { { at, width, top, bottom } } }
		                               decorative glass on the outer face
]]
function Builder.cladding(parent: Instance, points: { Vector2 }, options: { [string]: any })
	local model = Builder.model(parent, options.name or "Exterior")
	local count = #points
	local area = 0
	for i = 1, count do
		local a, b = points[i], points[i % count + 1]
		area += a.X * b.Y - b.X * a.Y
	end
	local thickness = Builder.WALL_THICKNESS
	for i = 1, count do
		local a, b = points[i], points[i % count + 1]
		local direction = (b - a).Unit
		local outward = if area > 0 then Vector2.new(direction.Y, -direction.X) else Vector2.new(-direction.Y, direction.X)
		local mid = (a + b) / 2 + outward * thickness / 2
		local along3 = Vector3.new(direction.X, 0, direction.Y)
		local base = CFrame.fromMatrix(Vector3.new(mid.X, Builder.FLOOR_TOP, mid.Y), along3, Vector3.yAxis)
		local height = if type(options.height) == "table" then options.height[i] else options.height
		-- Where a world coordinate falls along this edge, from its centre.
		local function alongOf(at: number): number
			local point = if math.abs(direction.X) > 0.5 then Vector2.new(at, mid.Y) else Vector2.new(mid.X, at)
			return (point - mid):Dot(direction)
		end
		local openings = {}
		for _, opening in (options.openings and options.openings[i]) or {} do
			table.insert(openings, {
				center = alongOf(opening.at),
				width = opening.width,
				bottom = opening.bottom,
				top = opening.top,
				threshold = false,
				frame = false,
			})
		end
		Builder.wall(model, base, (b - a).Magnitude + thickness * 2, height, openings, {
			color = options.color,
			material = options.material,
		})
		for _, window in (options.windows and options.windows[i]) or {} do
			local center = base * CFrame.new(alongOf(window.at), (window.bottom + window.top) / 2, 0)
			local outwardOffset = CFrame.new(0, 0, 0)
			-- base's local Z is along × up; flip so the glass sits on the outer face.
			local zSign = if base.ZVector:Dot(Vector3.new(outward.X, 0, outward.Y)) > 0 then 1 else -1
			outwardOffset = CFrame.new(0, 0, zSign * (thickness / 2 + 0.05))
			local size = Vector3.new(window.width, window.top - window.bottom, 0.1)
			Builder.detail(model, "WindowFrame", center * outwardOffset, size + Vector3.new(0.5, 0.5, -0.04), options.trimColor or Colors.OffWhite)
			Builder.detail(model, "Window", center * outwardOffset * CFrame.new(0, 0, zSign * 0.04), size, Colors.Glass:Lerp(Colors.Charcoal, 0.45), {
				Material = Materials.Glass,
				Reflectance = 0.15,
			})
		end
	end
	return model
end

function Builder.attached(to: BasePart, name: string, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	local part = Builder.detail(to, name, cframe, size, color, props)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	return part
end

--[[
	Registers a travel destination. `context.destinations` is read by the
	server TravelService. The character is placed standing at `cframe`,
	facing its LookVector.
]]
function Builder.destination(context: any, destinationId: string, areaId: string, cframe: CFrame)
	if context.destinations[destinationId] then
		warn(`[Builder] Duplicate destination "{destinationId}".`)
	end
	context.destinations[destinationId] = { cframe = cframe, areaId = areaId }
end

return Builder
