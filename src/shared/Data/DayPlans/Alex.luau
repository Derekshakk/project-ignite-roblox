--[[
	Alex — day plans.

	PLACEHOLDER CONTENT: objective wording for the 3D prototype.
]]

return {
	{
		characterId = "alex",
		day = 1,
		startArea = "bedroom",
		startDestination = "bedroom_start",
		objectives = {
			{
				id = "planner",
				text = "Check the planner on your desk",
				completeWhen = { scenario = "alex_d1_morning_planner" },
				marker = { default = "Scenario:bedroom_desk" },
			},
			{
				id = "school",
				text = "Head to school through the bedroom door",
				completeWhen = { flag = "visited:hallway" },
				marker = { default = "Travel:hallway_entrance" },
			},
			{
				id = "class",
				text = "Find your classroom at the end of the hallway and take your seat",
				completeWhen = { scenario = "alex_d1_s1_group_project" },
				marker = { default = "Sit:classroom_player_chair", bedroom = "Travel:hallway_entrance" },
			},
			{
				id = "recover",
				text = "Find somewhere calm to recharge before next period",
				completeWhen = { flag = "recoveredAfterClass" },
				marker = { default = "Activity:calm_corner_rest", bedroom = "Travel:hallway_entrance" },
			},
		},
		finalObjectiveText = "Head home and rest: use your bed to end the day",
		finalMarker = { default = "Travel:bedroom_door_arrival", bedroom = "EndDay:end_day" },
	},
}
