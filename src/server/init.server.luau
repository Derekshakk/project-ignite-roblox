--[[
	Server entry point.

	Applies lighting, builds the 3D prototype world and starts the server
	services (travel/placement, seating, item Tools, fall safety). Gameplay state and rules run on the client for this
	single-player prototype (see ReplicatedStorage.Shared.Game.GameController).
	Background traffic and pedestrians are client-side too; the server only
	builds the templates they are cloned from (World/AmbientTemplates).
]]

local Players = game:GetService("Players")

local LightingSetup = require(script.World.LightingSetup)
local WorldBuilder = require(script.World.WorldBuilder)
local AmbientTemplates = require(script.World.AmbientTemplates)
local ItemService = require(script.ItemService)
local SeatService = require(script.SeatService)
local TravelService = require(script.TravelService)
local SafetyService = require(script.SafetyService)

LightingSetup.apply()
local world = WorldBuilder.build()
AmbientTemplates.build()
TravelService.start(world.destinations)
SeatService.start(world.seats)
ItemService.start()
SafetyService.start(function()
	local start = world.destinations.bedroom_start
	return start and start.cframe
end)

-- If a character spawned before the bedroom SpawnLocation existed, respawn
-- it so it starts in the bedroom.
for _, player in Players:GetPlayers() do
	if player.Character then
		player:LoadCharacter()
	end
end
