--[[
	WorldBuilder

	Builds the prototype world into Workspace.IgniteWorld. Each area is a
	module with build(parent, origin, context); its position is set here, so
	areas can be rearranged or added without touching their contents.

	Layout (world space, top-down; see Areas/Neighborhood for the streets):
		house      bedroom + front hall around the origin
		walk       Maple Street → School Road (or through Elm Park)
		school     hallway origin (330, 0, 300), classroom east of it
	The outdoor ground only covers this map; there is no baseplate.

	The bedroom is built first because it contains the SpawnLocation.
]]

local Bedroom = require(script.Parent.Areas.Bedroom)
local Home = require(script.Parent.Areas.Home)
local Neighborhood = require(script.Parent.Areas.Neighborhood)
local Hallway = require(script.Parent.Areas.Hallway)
local Classroom = require(script.Parent.Areas.Classroom)
local SchoolExterior = require(script.Parent.Areas.SchoolExterior)

local HALLWAY_ORIGIN = CFrame.new(330, 0, 300)

local AREAS = {
	{ module = Bedroom, origin = CFrame.new(0, 0, 0) },
	{ module = Home, origin = CFrame.new(0, 0, 0) },
	{ module = Neighborhood, origin = CFrame.new(0, 0, 0) },
	-- Hallway centre; it spans x ±56 and joins the classroom at its east end.
	{ module = Hallway, origin = HALLWAY_ORIGIN },
	{ module = Classroom, origin = HALLWAY_ORIGIN * CFrame.new(73, 0, 0) },
	{ module = SchoolExterior, origin = HALLWAY_ORIGIN },
}

local WorldBuilder = {}

function WorldBuilder.build()
	local existing = workspace:FindFirstChild("IgniteWorld")
	if existing then
		existing:Destroy()
	end
	-- An older place file (or Studio's template) may still have the giant
	-- default baseplate; the world brings its own ground now.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
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
