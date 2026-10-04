--[[
	Alex — day plans.

	PLACEHOLDER CONTENT: objective wording for the 3D prototype.

	Markers can be a single target or a route: a list of targets the
	objective marker follows in order ("Waypoint:<id>" points are placed by
	the neighbourhood builder).
]]

-- The walk between home and school, in both directions.
local TO_SCHOOL = { "Waypoint:main_corner", "Waypoint:school_crossing", "Door:school_entrance" }
local TO_HOME = { "Waypoint:school_crossing", "Waypoint:main_corner", "Door:house_front_door" }

return {
	{
		characterId = "alex",
		day = 1,
		startArea = "bedroom",
		startDestination = "bedroom_start",
		startTime = "7:05 AM",
		objectives = {
			{
				id = "planner",
				text = "Check the planner on your desk",
				completeWhen = { scenario = "alex_d1_morning_planner" },
				marker = { default = "Scenario:bedroom_desk" },
			},
			{
				id = "leave",
				text = "Get ready, then head out the front door",
				completeWhen = { flag = "visited:neighborhood" },
				marker = { bedroom = "Door:bedroom_door", default = "Door:house_front_door" },
			},
			{
				id = "school",
				text = "Walk to school",
				completeWhen = { flag = "visited:hallway" },
				marker = { neighborhood = TO_SCHOOL, bedroom = "Door:bedroom_door", default = "Door:house_front_door" },
			},
			{
				id = "class",
				text = "Find your classroom at the end of the hallway and take your seat",
				completeWhen = { scenario = "alex_d1_s1_group_project" },
				marker = {
					default = "Sit:classroom_player_chair",
					neighborhood = TO_SCHOOL,
					home = "Door:house_front_door",
					bedroom = "Door:bedroom_door",
				},
			},
			{
				id = "recover",
				text = "Find somewhere calm to recharge before next period",
				completeWhen = { flag = "recoveredAfterClass" },
				marker = {
					default = "Activity:calm_corner_rest",
					neighborhood = TO_SCHOOL,
					home = "Door:house_front_door",
					bedroom = "Door:bedroom_door",
				},
			},
		},
		finalObjectiveText = "School's out. Walk home and rest: use your bed to end the day",
		finalMarker = {
			default = "Door:school_entrance",
			neighborhood = TO_HOME,
			home = "Door:bedroom_door",
			bedroom = "EndDay:end_day",
		},
	},
}
