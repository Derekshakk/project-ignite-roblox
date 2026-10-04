--[[
	Bedroom — the starting area.

	Interaction points:
		desk planner  → Scenario location "bedroom_desk" (cover swings open)
		headphones    → Pickup "headphones"
		photo, drawings, bookshelf, window → Inspect
		sketchbook, textbook, water bottle → Activity "pack_*" (room in the
		                backpack for two; packed items fly into the bag)
		stretching mat → Activity "morning_stretch" (a short guided stretch)
		desk chair    → Sit "bedroom_desk_chair"
		bedroom door  → Door "bedroom_door" into the front hall (see Home)
		bed           → EndDay
	Destinations: "bedroom_start" (spawn), "bedroom_door_arrival".
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Builder = require(script.Parent.Parent.Builder)
local ItemModels = require(script.Parent.Parent.ItemModels)
local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)

local at = Builder.at
local facing = Builder.facing
local C = Palette.Colors
local M = Palette.Materials
local InteractionType = World.InteractionTypes

local AREA_ID = "bedroom"
local WIDTH, DEPTH, HEIGHT = 28, 22, 11

local Bedroom = {}

-- A small prop the player can pack into the backpack. It hides (locally)
-- once its "packed:<id>" flag is set.
local function packable(model: Model, activityId: string, flag: string, backpackBody: BasePart?)
	model:SetAttribute(World.Attributes.InteractModel, true)
	model:SetAttribute(World.Attributes.HideWhenFlag, flag)
	CollectionService:AddTag(model, World.Tags.FlagVisibility)
	local prompt = Builder.activityPrompt(model.PrimaryPart :: BasePart, activityId)
	if prompt then
		prompt.MaxActivationDistance = 7
		prompt:SetAttribute(World.Attributes.Feedback, "pack")
		if backpackBody then
			local link = Instance.new("ObjectValue")
			link.Name = "PackInto"
			link.Value = backpackBody
			link.Parent = prompt
		end
	end
end

function Bedroom.build(parent: Instance, origin: CFrame, context)
	local room = Builder.room(parent, origin, {
		name = "Bedroom",
		width = WIDTH,
		depth = DEPTH,
		height = HEIGHT,
		floorColor = C.BedroomFloor,
		floorMaterial = M.WoodPlanks,
		wallColor = C.BedroomWall,
		trimColor = C.OffWhite,
		walls = {
			north = { { center = 3, width = 8, bottom = 4, top = 9, glass = true } },
			south = { { center = 8, width = 5, top = 8 } },
			east = {},
			west = {},
		},
	})
	local furniture = Builder.model(room, "Furniture")

	-- Bed (north-west corner, headboard against the north wall) — EndDay.
	local _, mattress = Props.bed(furniture, facing(origin, -9, 0, -6.4, Vector3.zAxis), C.Bedding)
	Builder.prompt(mattress, InteractionType.EndDay, "end_day", {
		ActionText = "Rest and end the day",
		ObjectText = "Bed",
		HoldDuration = 1,
	})
	-- Nightstand with lamp and a book.
	Props.drawers(furniture, facing(origin, -4.9, 0, -9.6, Vector3.zAxis), 1.8, 2.2, 1.6, 2)
	Props.deskLamp(furniture, at(origin, -4.9, 2.2, -9.8))
	Props.bookStack(furniture, at(origin, -4.6, 2.2, -9.1), 2, 4)

	-- Desk (east wall) with the planner — the morning scenario.
	local deskFloor = facing(origin, 11.5, 0, -5, -Vector3.xAxis)
	Props.desk(furniture, deskFloor, { name = "Desk", width = 7, depth = 3.6, height = 3.3, topColor = C.LightWood })
	Props.drawers(furniture, facing(origin, 12.4, 0, -7.1, -Vector3.xAxis), 1.9, 2.7, 1.8, 3)
	-- Planner: pages with a cover hinged along the right edge. The client
	-- swings the cover open when the planner is checked.
	local plannerModel = Builder.model(furniture, "Planner")
	plannerModel:SetAttribute(World.Attributes.InteractModel, true)
	local plannerCFrame = at(origin, 11.1, 3.42, -5.4) * CFrame.Angles(0, math.rad(12), 0)
	local planner = Builder.part(plannerModel, "Pages", plannerCFrame * CFrame.new(0, -0.02, 0), Vector3.new(1.48, 0.18, 1.98), C.Paper, {
		CanCollide = false,
	})
	Builder.detail(plannerModel, "BackCover", plannerCFrame * CFrame.new(0, -0.125, 0), Vector3.new(1.52, 0.03, 2.02), C.Accent)
	for i = 1, 4 do
		Builder.detail(plannerModel, "Line", plannerCFrame * CFrame.new(0.05, 0.075, -0.75 + i * 0.32), Vector3.new(1.1, 0.01, 0.04), C.Blue:Lerp(C.Paper, 0.55))
	end
	Builder.detail(plannerModel, "Note", plannerCFrame * CFrame.new(-0.35, 0.077, 0.75), Vector3.new(0.5, 0.01, 0.12), C.Red:Lerp(C.Paper, 0.3))
	local coverHinge = plannerCFrame * CFrame.new(0.76, 0.085, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	local cover = Builder.hingedLeaf(plannerModel, "Cover", coverHinge, Vector3.new(1.52, 2.02, 0.03), C.Accent, -1, -170)
	cover.CastShadow = false
	local plannerPrompt = Builder.prompt(planner, InteractionType.Scenario, "bedroom_desk", {
		ActionText = "Look",
		ObjectText = "Planner",
		MaxActivationDistance = 8,
	})
	plannerPrompt:SetAttribute(World.Attributes.Feedback, "open")
	local coverLink = Instance.new("ObjectValue")
	coverLink.Name = "AnimatedCover"
	coverLink.Value = cover
	coverLink.Parent = plannerPrompt

	-- Headphones: a real item the player can pick up and wear.
	local headphones = ItemModels.buildPickup(
		furniture,
		"Headphones",
		at(origin, 11.3, 3.3 + 0.5, -2.7) * CFrame.Angles(0, math.rad(70), 0),
		0.9
	)
	if headphones then
		headphones:SetAttribute("PickupItemId", "headphones")
		local prompt = Builder.prompt(headphones.PrimaryPart :: BasePart, InteractionType.Pickup, "headphones", {
			ActionText = "Pick up",
			ObjectText = "Headphones",
			MaxActivationDistance = 8,
		})
		prompt:SetAttribute(World.Attributes.Feedback, "collect")
	end

	-- Framed photo to inspect.
	local photo = Builder.part(furniture, "PhotoFrame", at(origin, 10.25, 3.3 + 0.45, -1.95) * CFrame.Angles(0, 0, math.rad(-10)), Vector3.new(0.12, 0.9, 0.75), C.DarkWood, {
		CanCollide = false,
	})
	Builder.detail(furniture, "Photo", photo.CFrame * CFrame.new(-0.07, 0, 0), Vector3.new(0.02, 0.7, 0.55), C.Teal:Lerp(C.Accent, 0.4))
	Builder.prompt(photo, InteractionType.Inspect, "bedroom_photo", {
		ActionText = "Look",
		ObjectText = "Photo",
		MaxActivationDistance = 7,
	}):SetAttribute(World.Attributes.Feedback, "lift")
	Builder.detail(furniture, "Pen", at(origin, 10.6, 3.36, -4.3) * CFrame.Angles(0, math.rad(40), 0), Vector3.new(0.12, 0.12, 1), C.Blue)
	Builder.detail(furniture, "Laptop", at(origin, 12.3, 3.36, -7.4), Vector3.new(1.8, 0.12, 1.3), C.Charcoal)
	Props.deskLamp(furniture, at(origin, 12.8, 3.3, -1.9))
	Props.bookStack(furniture, at(origin, 10.5, 3.3, -7.7), 3, 9)
	Builder.cylinder(furniture, "PencilCup", at(origin, 12.8, 3.65, -3.9), 0.7, 0.45, C.Teal)
	for i, color in { C.Yellow, C.Red, C.Blue } do
		Builder.detail(furniture, "Pencil", at(origin, 12.75 + i * 0.05, 4.1, -3.95 + i * 0.04) * CFrame.Angles(math.rad(8 * i - 16), 0, 0), Vector3.new(0.07, 0.9, 0.07), color)
	end
	local _, deskChair = Props.chair(furniture, facing(origin, 8.9, 0, -5, Vector3.xAxis), C.Blue, { context = context, id = "bedroom_desk_chair" })
	Builder.prompt(deskChair, InteractionType.Sit, "bedroom_desk_chair", {
		ActionText = "Sit",
		ObjectText = "Desk chair",
		MaxActivationDistance = 7,
	})

	-- Window curtains (north wall, either side of the window).
	for _, x in { -1.6, 7.6 } do
		Builder.detail(furniture, "Curtain", at(origin, x, 6.2, -10.75), Vector3.new(1.4, 6.6, 0.25), C.Purple:Lerp(C.Paper, 0.25), {
			Material = M.Fabric,
		})
	end
	Builder.detail(furniture, "CurtainRod", at(origin, 3, 9.6, -10.7), Vector3.new(11, 0.15, 0.15), C.DarkWood)
	Props.plant(furniture, at(origin, 5.6, 4.2, -10.75), 0.35)

	-- Bookshelf and wardrobe (west wall).
	local bookshelf = Props.bookshelf(furniture, facing(origin, -13.1, 0, 5.5, Vector3.xAxis), 4.5, 6, 1.6, 3, 11)
	bookshelf:SetAttribute(World.Attributes.InteractModel, true)
	Builder.prompt(bookshelf:FindFirstChild("Back") :: BasePart, InteractionType.Inspect, "bedroom_bookshelf", {
		ActionText = "Look",
		ObjectText = "Bookshelf",
		MaxActivationDistance = 8,
	})
	local wardrobe = Builder.model(furniture, "Wardrobe")
	Builder.part(wardrobe, "Body", at(origin, -12.9, 3.6, -0.6), Vector3.new(2, 7.2, 4.4), C.Wood, { Material = M.Wood })
	Builder.detail(wardrobe, "DoorSeam", at(origin, -11.88, 3.7, -0.6), Vector3.new(0.05, 6.6, 0.06), C.DarkWood)
	for _, z in { -0.95, -0.25 } do
		Builder.detail(wardrobe, "Handle", at(origin, -11.85, 3.8, z), Vector3.new(0.08, 0.7, 0.1), C.DarkMetal)
	end

	-- Floor details.
	Builder.detail(furniture, "Rug", at(origin, 0, 0.03, 1), Vector3.new(10, 0.06, 7), C.Rug, { Material = M.Carpet })
	Builder.detail(furniture, "RugBorder", at(origin, 0, 0.02, 1), Vector3.new(10.6, 0.04, 7.6), C.Rug:Lerp(C.Charcoal, 0.35), {
		Material = M.Carpet,
	})
	local backpack = Props.backpack(furniture, facing(origin, 6.4, 0, -2.6, -Vector3.zAxis) * CFrame.Angles(0, math.rad(20), 0), C.Red)
	local backpackBody = backpack:FindFirstChild("Body") :: BasePart?

	-- Things Alex could pack (room for two of them).
	local sketchbook = Builder.model(furniture, "Sketchbook")
	sketchbook.PrimaryPart = Builder.part(sketchbook, "Cover", at(origin, -8.2, 2.1, -3.6) * CFrame.Angles(0, math.rad(25), 0), Vector3.new(1.2, 0.1, 1.6), C.Teal:Lerp(C.Charcoal, 0.3), {
		CanCollide = false,
	})
	Builder.detail(sketchbook, "Spiral", at(origin, -8.2, 2.16, -3.6) * CFrame.Angles(0, math.rad(25), 0) * CFrame.new(-0.55, 0, 0), Vector3.new(0.08, 0.05, 1.5), C.Metal)
	packable(sketchbook, "pack_sketchbook", "packed:sketchbook", backpackBody)

	local water = Builder.model(furniture, "WaterBottle")
	water.PrimaryPart = Builder.cylinder(water, "Bottle", at(origin, -5.45, 2.65, -9.15), 0.9, 0.36, C.Teal, { CanCollide = false })
	Builder.cylinder(water, "Cap", at(origin, -5.45, 3.16, -9.15), 0.14, 0.24, C.Charcoal, { CanCollide = false, CastShadow = false })
	packable(water, "pack_water", "packed:water", backpackBody)

	local textbook = Builder.model(furniture, "Textbook")
	textbook.PrimaryPart = Builder.part(textbook, "Book", at(origin, 5.1, 0.17, -1.3) * CFrame.Angles(0, math.rad(-30), 0), Vector3.new(1.4, 0.3, 1.8), C.Blue, {
		CanCollide = false,
	})
	Builder.detail(textbook, "Pages", at(origin, 5.1, 0.17, -1.3) * CFrame.Angles(0, math.rad(-30), 0) * CFrame.new(0.05, 0, 0), Vector3.new(1.32, 0.24, 1.7), C.Paper)
	packable(textbook, "pack_textbook", "packed:textbook", backpackBody)
	Props.plant(furniture, at(origin, 3, 0, 9.4))
	Builder.cylinder(furniture, "LaundryBasket", at(origin, -11.6, 0.8, 9.2), 1.6, 1.8, C.Paper:Lerp(C.Wood, 0.3), {
		Material = M.Fabric,
	})

	-- Wall decor.
	Props.poster(furniture, facing(origin, WIDTH / 2 - 0.06, 7, -5, -Vector3.xAxis), 2.4, 3.2, C.Purple, 2)
	Props.poster(furniture, facing(origin, -4, 7.2, DEPTH / 2 - 0.06, -Vector3.zAxis), 2.8, 2.1, C.Accent, 5)
	local drawings = Props.bulletinBoard(furniture, facing(origin, WIDTH / 2 - 0.08, 6.6, 1.5, -Vector3.xAxis), 3.6, 2.4, 3)
	drawings:SetAttribute(World.Attributes.InteractModel, true)
	Builder.prompt(drawings:FindFirstChild("Frame") :: BasePart, InteractionType.Inspect, "bedroom_drawings", {
		ActionText = "Look",
		ObjectText = "Drawings",
		MaxActivationDistance = 9,
	})

	-- The window: an invisible part to look through.
	local window = Builder.part(furniture, "WindowView", at(origin, 3, 6.5, -10.4), Vector3.new(7, 4.5, 0.2), C.Glass, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	Builder.prompt(window, InteractionType.Inspect, "bedroom_window", {
		ActionText = "Look outside",
		ObjectText = "Window",
		MaxActivationDistance = 9,
	}):SetAttribute(World.Attributes.Feedback, "none")
	Props.clock(furniture, facing(origin, -WIDTH / 2 + 0.1, 8.4, 5.5, Vector3.xAxis))

	-- Door (south wall) into the front hall. Hinged on the east side; it
	-- swings into the bedroom, clear of the furniture.
	local door = Builder.door(furniture, {
		hinge = at(origin, 10.4, 3.95, 11.5),
		size = Vector3.new(4.8, 7.9, 0.35),
		color = C.Door,
		side = -1,
		openAngle = -80,
		doorId = "bedroom_door",
		objectText = "Bedroom door",
	})
	for _, offset in { -1.9, 1.9 } do
		Builder.attached(door, "DoorPanel", at(origin, 8, 3.95 + offset, 11.31), Vector3.new(3.4, 2.8, 0.05), C.Door:Lerp(C.DarkWood, 0.25))
	end
	Builder.attached(door, "DoorKnob", at(origin, 6.2, 3.8, 11.22), Vector3.new(0.35, 0.35, 0.35), C.Metal, {
		Shape = Enum.PartType.Ball,
		Material = M.Metal,
	})

	-- Stretching mat by the bookshelf: a short movement break.
	local mat = Builder.part(furniture, "StretchMat", at(origin, -6.5, 0.04, 6), Vector3.new(2.4, 0.08, 5.4), C.Purple:Lerp(C.Paper, 0.35), {
		Material = M.Fabric,
		CanCollide = false,
	})
	local matPrompt = Builder.activityPrompt(mat, "morning_stretch")
	if matPrompt then
		matPrompt.MaxActivationDistance = 7
		matPrompt:SetAttribute(World.Attributes.Feedback, "none")
	end

	Builder.ceilingLight(room, origin, 0, 0, HEIGHT, { length = 3, width = 3, brightness = 0.8, range = 26 })
	Builder.areaVolume(room, AREA_ID, at(origin, 0, HEIGHT / 2, 0), Vector3.new(WIDTH, HEIGHT, DEPTH))

	-- Spawn point and destinations.
	local spawnCFrame = at(origin, 0, 0, 2)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BedroomSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(4, 0.2, 4)
	spawn.CFrame = spawnCFrame
	spawn.Parent = room

	Builder.destination(context, "bedroom_start", AREA_ID, CFrame.lookAt(spawnCFrame.Position, (at(origin, 6, 0, -5)).Position))
	local arrival = at(origin, 8, 0, 7.5)
	Builder.destination(context, "bedroom_door_arrival", AREA_ID, CFrame.lookAt(arrival.Position, (at(origin, 8, 0, 0)).Position))

	return room
end

return Bedroom
