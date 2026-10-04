--[[
	Classroom at the end of the hallway.

	The west side is open to the hallway's east doorway (the hallway builds
	the shared wall section), so this room skips that part of its west wall.

	Interaction points:
		the character's chair → Sit "classroom_player_chair"; once seated,
		                        the scenario at location "classroom_seat"
		                        starts (if one is available)
		a spare chair         → Sit "classroom_chair_back"
		calm corner beanbag   → Activity "calm_corner_rest" (recovery)
		schedule by the board → Inspect "classroom_schedule"
		card by the beanbag   → Inspect "classroom_calm_card"
		your notebook         → Activity "write_question" (after class starts)
		question tray on the teacher's desk → Activity "leave_note"
	Sitting in either chair makes the teacher talk to the player.
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

local WIDTH, DEPTH, HEIGHT = 32, 30, 12
-- Width of the hallway (including its walls) that joins this room.
local HALLWAY_JOIN_WIDTH = 18
local DESK_HEIGHT = 2.8

local DESK_COLUMNS = { -5, 0.5, 6 }
local DESK_ROWS = { -8, 0, 8 }
local PLAYER_DESK = Vector2.new(0.5, 0)
-- Desks with a student standing at them; the rest get an empty chair. Some
-- students whisper now and then (client AmbientChatter), and each is turned
-- a little differently so the class doesn't face the board in lockstep.
local OCCUPIED = {
	["-5,-8"] = { chatter = { "Did you do the reading?", "Is this on the quiz?" } },
	["-5,8"] = {},
	["0.5,-8"] = { chatter = { "I forgot my pencil case.", "Can I borrow one?" } },
	["0.5,8"] = { chatter = { "I'm so tired today." } },
	["6,-8"] = {},
	["6,0"] = { chatter = { "What page are we on?" } },
}

local Classroom = {}

local function buildCalmCorner(room: Instance, origin: CFrame)
	local corner = Builder.model(room, "CalmCorner")
	Builder.detail(corner, "Rug", at(origin, -12.5, 0.03, -11.5), Vector3.new(6.5, 0.06, 6.5), C.Lavender, { Material = M.Carpet })
	local beanbag = Builder.part(corner, "Beanbag", at(origin, -13.3, 1.0, -12.6), Vector3.new(3.2, 2.2, 3.2), C.Teal, {
		Shape = Enum.PartType.Ball,
		Material = M.Fabric,
	})
	Builder.activityPrompt(beanbag, "calm_corner_rest")
	Builder.part(corner, "Cushion", at(origin, -11.0, 0.4, -10.4), Vector3.new(1.6, 0.6, 1.6), C.Accent:Lerp(C.Paper, 0.3), {
		Material = M.Fabric,
	})
	-- A small card on a stand next to the beanbag.
	local card = Builder.part(corner, "CalmCard", at(origin, -10.9, 0.75, -13.7) * CFrame.Angles(math.rad(-15), math.rad(30), 0), Vector3.new(1.1, 0.8, 0.06), C.Paper, {
		CanCollide = false,
	})
	Builder.detail(corner, "CardStand", at(origin, -10.9, 0.2, -13.65), Vector3.new(0.5, 0.4, 0.3), C.DarkWood)
	Builder.prompt(card, InteractionType.Inspect, "classroom_calm_card", {
		ActionText = "Read",
		ObjectText = "Card",
		MaxActivationDistance = 7,
	}):SetAttribute(World.Attributes.Feedback, "lift")
	Props.bookshelf(corner, facing(origin, -15.4, 0, -9.2, Vector3.xAxis), 3, 3.2, 1.1, 2, 31)
	Builder.detail(corner, "Headphones", at(origin, -15.3, 3.4, -9.2), Vector3.new(0.8, 0.3, 1), C.Charcoal)
	Props.floorLamp(corner, at(origin, -9.6, 0, -14.2))
	Props.plant(corner, at(origin, -15, 0, -14.1))
	Builder.sign(corner, "CalmCornerSign", facing(origin, -12.5, 7.2, -DEPTH / 2 + 0.08, Vector3.zAxis), Vector3.new(4.6, 1.1, 0.1), "Calm Corner", C.Lavender:Lerp(C.Paper, 0.4))
end

function Classroom.build(parent: Instance, origin: CFrame, context)
	local room = Builder.room(parent, origin, {
		name = "Classroom",
		width = WIDTH,
		depth = DEPTH,
		height = HEIGHT,
		floorColor = C.ClassroomFloor,
		floorMaterial = M.WoodPlanks,
		wallColor = C.ClassroomWall,
		wainscot = { height = 3.2, color = C.ClassroomWainscot },
		trimColor = C.Trim,
		ceilingGrid = 4,
		walls = {
			west = { { center = 0, width = HALLWAY_JOIN_WIDTH, top = HEIGHT + 1, threshold = false } },
			north = {
				{ center = 0, width = 6, bottom = 4, top = 9, glass = true },
				{ center = 9, width = 6, bottom = 4, top = 9, glass = true },
			},
			south = {},
			east = {},
		},
	})
	local furniture = Builder.model(room, "Furniture")
	local people = Builder.model(room, "People")

	-- Teaching area: framed whiteboard with tray and a few marks.
	local boardFace = WIDTH / 2 - 0.1
	Builder.detail(furniture, "BoardFrame", at(origin, boardFace + 0.02, 5.8, 0), Vector3.new(0.15, 4.9, 12.3), C.Metal, { Material = M.Metal })
	Builder.part(furniture, "Whiteboard", at(origin, boardFace - 0.05, 5.8, 0), Vector3.new(0.1, 4.5, 11.9), C.Whiteboard)
	Builder.detail(furniture, "BoardTray", at(origin, boardFace - 0.3, 3.5, 0), Vector3.new(0.45, 0.12, 11.5), C.Metal, { Material = M.Metal })
	for i, color in { C.Blue, C.Red, C.Green } do
		Builder.detail(furniture, "Writing", at(origin, boardFace - 0.11, 7.2 - i * 0.7, -3 + i * 0.4), Vector3.new(0.02, 0.18, 4 - i * 0.8), color)
	end
	Props.clock(furniture, facing(origin, boardFace - 0.05, 9.6, 0, -Vector3.xAxis))
	Props.desk(furniture, facing(origin, 11, 0, 0, -Vector3.xAxis), { name = "TeacherDesk", width = 6, depth = 2.8, height = 3.1, topColor = C.Wood })
	Props.drawers(furniture, facing(origin, 11.4, 0, 1.8, -Vector3.xAxis), 1.8, 2.6, 1.8, 3)
	Props.papers(furniture, at(origin, 10.8, 3.1, -1.4), 3, 5)
	Props.bookStack(furniture, at(origin, 11.2, 3.1, 1.9), 3, 2)
	Builder.cylinder(furniture, "Mug", at(origin, 10.6, 3.4, 0.6), 0.5, 0.4, C.Accent)
	-- Question tray: leave a written question here (it appears in the tray).
	local tray = Builder.part(furniture, "QuestionTray", at(origin, 10.5, 3.25, -2.45), Vector3.new(1.3, 0.25, 1.0), C.Blue, { CanCollide = false })
	Builder.sign(furniture, "TraySign", facing(origin, 9.85, 3.65, -2.45, -Vector3.xAxis), Vector3.new(1.2, 0.4, 0.05), "Questions?", C.Paper)
	local trayPrompt = Builder.activityPrompt(tray, "leave_note")
	if trayPrompt then
		trayPrompt.MaxActivationDistance = 7
	end
	local note = Builder.detail(furniture, "LeftNote", at(origin, 10.5, 3.39, -2.45) * CFrame.Angles(0, math.rad(12), 0), Vector3.new(0.7, 0.03, 0.7), C.Yellow)
	note:SetAttribute(World.Attributes.ShowWhenFlag, "noteLeft")
	CollectionService:AddTag(note, World.Tags.FlagVisibility)
	Npc.spawn(people, "Teacher", facing(origin, 13.5, 0, -1, -Vector3.xAxis), {
		seed = 40,
		shirt = Color3.fromRGB(110, 78, 130),
		adult = true,
		npcId = "teacher",
		talkative = true,
	})
	Builder.detail(furniture, "TeacherLaptop", at(origin, 11.4, 3.16, -0.4) * CFrame.Angles(0, math.rad(-15), 0), Vector3.new(1.6, 0.1, 1.1), C.Charcoal)

	-- Today's schedule next to the board.
	local schedule = Builder.sign(furniture, "Schedule", facing(origin, boardFace - 0.02, 6.2, 9.4, -Vector3.xAxis), Vector3.new(2.4, 2.8, 0.08), "Today", C.Paper)
	Builder.prompt(schedule, InteractionType.Inspect, "classroom_schedule", {
		ActionText = "Read",
		ObjectText = "Schedule",
		MaxActivationDistance = 9,
	})

	-- Student desks facing the board.
	local seed = 20
	for _, x in DESK_COLUMNS do
		for _, z in DESK_ROWS do
			local deskFloor = facing(origin, x, 0, z, Vector3.xAxis)
			Props.desk(furniture, deskFloor, {
				name = "StudentDesk",
				width = 3,
				depth = 2.2,
				height = DESK_HEIGHT,
				bookBox = true,
			})
			local seatCFrame = facing(origin, x - 1.9, 0, z, Vector3.xAxis)
			local isPlayerDesk = x == PLAYER_DESK.X and z == PLAYER_DESK.Y
			local surface = at(origin, x, DESK_HEIGHT, z)
			if isPlayerDesk then
				local notebook = Builder.part(furniture, "Notebook", surface * CFrame.new(0, 0.06, 0.3), Vector3.new(1, 0.12, 1.4), C.Accent, {
					CanCollide = false,
				})
				local notePrompt = Builder.activityPrompt(notebook, "write_question")
				if notePrompt then
					notePrompt.MaxActivationDistance = 6
					notePrompt:SetAttribute(World.Attributes.Feedback, "lift")
				end
				Builder.cylinder(furniture, "PencilCup", surface * CFrame.new(0.4, 0.3, -0.8), 0.6, 0.4, C.Teal)
				local _, seat = Props.chair(furniture, seatCFrame, C.Blue, {
					context = context,
					id = "classroom_player_chair",
					listenTo = "teacher",
				})
				local prompt = Builder.prompt(seat, InteractionType.Sit, "classroom_player_chair", {
					ActionText = "Sit",
					ObjectText = "Your desk",
					MaxActivationDistance = 8,
				})
				prompt:SetAttribute(World.Attributes.ScenarioLocation, "classroom_seat")
			elseif OCCUPIED[`{x},{z}`] then
				seed += 1
				Npc.spawn(people, `Student{seed}`, seatCFrame, {
					seed = seed,
					chatter = OCCUPIED[`{x},{z}`].chatter,
					talkative = false,
					turnRange = 28,
				})
				Props.papers(furniture, surface, 1 + seed % 2, seed)
			elseif x == -5 and z == 0 then
				-- A spare seat: sit and listen to the teacher.
				local _, seat = Props.chair(furniture, seatCFrame, C.Blue, {
					context = context,
					id = "classroom_chair_back",
					listenTo = "teacher",
				})
				Builder.prompt(seat, InteractionType.Sit, "classroom_chair_back", {
					ActionText = "Sit and listen",
					ObjectText = "Empty seat",
					MaxActivationDistance = 7,
				})
			else
				Props.chair(furniture, seatCFrame, C.Blue)
				Props.bookStack(furniture, surface * CFrame.new(0.3, 0, -0.4), 2, seed)
			end
		end
	end
	Props.backpack(furniture, facing(origin, -3.0, 0, -10.4, Vector3.xAxis), C.Green)
	Props.backpack(furniture, facing(origin, 7.9, 0, 2.3, -Vector3.zAxis), C.Purple)

	buildCalmCorner(room, origin)

	-- Storage and wall decor.
	Props.cubbies(furniture, facing(origin, -4, 0, DEPTH / 2 - 0.7, -Vector3.zAxis), 5, 2, 3)
	Props.bookshelf(furniture, facing(origin, 6, 0, DEPTH / 2 - 0.65, -Vector3.zAxis), 5, 5.2, 1.3, 3, 41)
	Props.bulletinBoard(furniture, facing(origin, -4, 6.4, DEPTH / 2 - 0.08, -Vector3.zAxis), 7, 3, 12)
	Props.poster(furniture, facing(origin, 12, 6.4, DEPTH / 2 - 0.06, -Vector3.zAxis), 2.6, 3.2, C.Blue, 13)
	Props.poster(furniture, facing(origin, 14.3, 6.2, -DEPTH / 2 + 0.06, Vector3.zAxis), 2.4, 3, C.Yellow, 14)
	Props.poster(furniture, facing(origin, -WIDTH / 2 + 0.06, 6.2, 12.5, Vector3.xAxis), 2.2, 2.8, C.Red, 15)
	Props.bin(furniture, at(origin, 14, 0, 12.8))
	-- Globe on top of the bookshelf.
	Builder.cylinder(furniture, "GlobeStand", at(origin, 6, 5.35, DEPTH / 2 - 0.8), 0.3, 0.6, C.DarkWood)
	Builder.detail(furniture, "Globe", at(origin, 6, 6.05, DEPTH / 2 - 0.8), Vector3.new(1.1, 1.1, 1.1), C.Blue:Lerp(C.Teal, 0.4), {
		Shape = Enum.PartType.Ball,
	})

	-- Reaches into the doorway so there's no gap between areas.
	Builder.areaVolume(room, "classroom", at(origin, -1, HEIGHT / 2, 0), Vector3.new(WIDTH + 2, HEIGHT, DEPTH))

	for _, x in { -8, 8 } do
		for _, z in { -7, 7 } do
			Builder.ceilingLight(room, origin, x, z, HEIGHT, { length = 4, width = 2, brightness = 0.7, range = 22 })
		end
	end

	return room
end

return Classroom
