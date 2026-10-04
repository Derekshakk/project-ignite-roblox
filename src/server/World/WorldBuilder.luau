--[[
	WorldBuilder

	Builds the prototype world into Workspace.IgniteWorld. Each area is a
	module with build(parent, origin, context); its position is set here, so
	areas can be rearranged or added without touching their contents.

	The bedroom is built first because it contains the SpawnLocation.
]]

local Bedroom = require(script.Parent.Areas.Bedroom)
local Hallway = require(script.Parent.Areas.Hallway)
local Classroom = require(script.Parent.Areas.Classroom)

local AREAS = {
	{ module = Bedroom, origin = CFrame.new(0, 0, 0) },
	-- Hallway centre; it spans x 0..112 and joins the classroom at x = 112.
	{ module = Hallway, origin = CFrame.new(56, 0, 120) },
	{ module = Classroom, origin = CFrame.new(129, 0, 120) },
}

local WorldBuilder = {}

function WorldBuilder.build()
	local existing = workspace:FindFirstChild("IgniteWorld")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "IgniteWorld"
	folder.Parent = workspace

	local context = {
		-- destinationId → { cframe: CFrame, areaId: string }
		destinations = {},
		-- seatId → Seat
		seats = {},
	}
	for _, area in AREAS do
		area.module.build(folder, area.origin, context)
	end

	return {
		folder = folder,
		destinations = context.destinations,
		seats = context.seats,
	}
end

return WorldBuilder
