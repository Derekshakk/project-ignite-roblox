--[[
	Bedroom — the starting area.

	Interaction points:
		desk planner  → Scenario location "bedroom_desk"
		headphones    → Pickup "headphones"
		photo         → Inspect "bedroom_photo"
		desk chair    → Sit "bedroom_desk_chair"
		bedroom door  → Travel to "hallway_entrance"
		bed           → EndDay
	Destinations: "bedroom_start" (spawn), "bedroom_door_arrival".
]]

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
	local planner = Builder.part(
		furniture,
		"Planner",
		at(origin, 11.1, 3.42, -5.4) * CFrame.Angles(0, math.rad(12), 0),
		Vector3.new(1.5, 0.22, 2),
		C.Accent,
		{ CanCollide = false }
	)
	Builder.detail(furniture, "PlannerPage", at(origin, 11.1, 3.535, -5.4) * CFrame.Angles(0, math.rad(12), 0), Vector3.new(1.35, 0.02, 1.85), C.Paper)
	Builder.prompt(planner, InteractionType.Scenario, "bedroom_desk", {
		ActionText = "Look",
		ObjectText = "Planner",
		MaxActivationDistance = 8,
	}):SetAttribute(World.Attributes.Feedback, "lift")

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
		prompt:SetAttribute(World.Attributes.Feedback, "none")
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
	Props.bookshelf(furniture, facing(origin, -13.1, 0, 5.5, Vector3.xAxis), 4.5, 6, 1.6, 3, 11)
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
	Props.backpack(furniture, facing(origin, 6.4, 0, -2.6, -Vector3.zAxis) * CFrame.Angles(0, math.rad(20), 0), C.Red)
	Props.plant(furniture, at(origin, 3, 0, 9.4))
	Builder.cylinder(furniture, "LaundryBasket", at(origin, -11.6, 0.8, 9.2), 1.6, 1.8, C.Paper:Lerp(C.Wood, 0.3), {
		Material = M.Fabric,
	})

	-- Wall decor.
	Props.poster(furniture, facing(origin, WIDTH / 2 - 0.06, 7, -5, -Vector3.xAxis), 2.4, 3.2, C.Purple, 2)
	Props.poster(furniture, facing(origin, -4, 7.2, DEPTH / 2 - 0.06, -Vector3.zAxis), 2.8, 2.1, C.Accent, 5)
	Props.bulletinBoard(furniture, facing(origin, WIDTH / 2 - 0.08, 6.6, 1.5, -Vector3.xAxis), 3.6, 2.4, 3)
	Props.clock(furniture, facing(origin, -WIDTH / 2 + 0.1, 8.4, 5.5, Vector3.xAxis))

	-- Door (south wall) — travel to school.
	local door = Builder.part(furniture, "Door", at(origin, 8, 3.95, 11.5), Vector3.new(4.8, 7.9, 0.35), C.Door, { Material = M.Wood })
	for _, offset in { -1.9, 1.9 } do
		Builder.detail(furniture, "DoorPanel", at(origin, 8, 3.95 + offset, 11.31), Vector3.new(3.4, 2.8, 0.05), C.Door:Lerp(C.DarkWood, 0.25))
	end
	Builder.detail(furniture, "DoorKnob", at(origin, 6.2, 3.8, 11.22), Vector3.new(0.35, 0.35, 0.35), C.Metal, {
		Shape = Enum.PartType.Ball,
		Material = M.Metal,
	})
	Builder.prompt(door, InteractionType.Travel, "hallway_entrance", {
		ActionText = "Go to school",
		ObjectText = "Bedroom door",
		MaxActivationDistance = 8,
	})

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
