--[[
	AmbientTemplates

	Builds the templates the client clones for background life into
	ReplicatedStorage.IgniteAmbient (World.AmbientFolder):
		People/   R15 rigs (students with backpacks, adults), never parented
		          to the workspace; attribute Kind = "student" | "adult"
		Cars/     one car per body style (Vehicles), recoloured per car
		Props/    a walking dog and a grocery bag (pivot at the grip)
		Markers   route points as Vector3 attributes (Builder.routeMarker)

	Pedestrians and traffic are purely visual and local to each client, so
	they cost nothing on the network and can't be affected by streaming.
	Rigs are only creatable on the server, which is why they are built
	here. Templates aren't tagged as NPCs, so no NPC system picks them up.
]]

local Builder = require(script.Parent.Builder)
local HeldProps = require(script.Parent.HeldProps)
local Npc = require(script.Parent.Npc)
local OutdoorProps = require(script.Parent.OutdoorProps)
local Vehicles = require(script.Parent.Vehicles)

local rgb = Color3.fromRGB

local STUDENTS = 8
local ADULTS = 7
local DOG_COATS = { rgb(176, 128, 72), rgb(60, 50, 44), rgb(214, 196, 160) }

local AmbientTemplates = {}

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

function AmbientTemplates.build()
	local root = Builder.ambientFolder()
	local people = folder(root, "People")
	local cars = folder(root, "Cars")
	local props = folder(root, "Props")

	for _, style in Vehicles.StyleNames do
		local car = Vehicles.car(cars, CFrame.new(), Vehicles.Colors[1], style)
		car.Name = style
	end
	for i, coat in DOG_COATS do
		OutdoorProps.dog(props, CFrame.new(), coat, "stand").Name = `Dog{i}`
	end
	HeldProps.build(props, "groceries")

	-- Rigs take a moment each; build them in parallel threads. The client
	-- waits for whatever has arrived.
	local function person(name: string, seed: number, options: { [string]: any }, kind: string)
		task.spawn(function()
			local model, isRig = Npc.build(name, seed, options)
			if not isRig then
				-- A block figure can't walk; leave it out.
				model:Destroy()
				return
			end
			model:SetAttribute("Kind", kind)
			model.Parent = people
		end)
	end
	for i = 1, STUDENTS do
		person(`Student{i}`, 400 + i * 3, { backpack = true }, "student")
	end
	for i = 1, ADULTS do
		person(`Adult{i}`, 500 + i * 5, { adult = true, backpack = false }, "adult")
	end
end

return AmbientTemplates
