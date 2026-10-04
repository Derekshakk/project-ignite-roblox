--[[
	Server entry point.

	Applies lighting, builds the 3D prototype world and starts the server
	services (travel between areas, seating, item Tools). Gameplay state and rules run on the client for this
	single-player prototype (see ReplicatedStorage.Shared.Game.GameController).
]]

local Players = game:GetService("Players")

local LightingSetup = require(script.World.LightingSetup)
local WorldBuilder = require(script.World.WorldBuilder)
local ItemService = require(script.ItemService)
local SeatService = require(script.SeatService)
local TravelService = require(script.TravelService)

LightingSetup.apply()
local world = WorldBuilder.build()
TravelService.start(world.destinations)
SeatService.start(world.seats)
ItemService.start()

-- If a character spawned before the bedroom SpawnLocation existed, respawn
-- it so it starts in the bedroom.
for _, player in Players:GetPlayers() do
	if player.Character then
		player:LoadCharacter()
	end
end
