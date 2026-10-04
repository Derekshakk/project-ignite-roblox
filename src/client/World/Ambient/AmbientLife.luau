--[[
	AmbientLife

	Background life around the walk to school, all local to this client and
	driven from a single Heartbeat connection:
		Pedestrians   walkers on waypoint routes (Data/Ambient)
		Traffic       pooled cars on lane paths
		WorldMotion   swaying trees, sprinkler, gates, flag, tail wags
		AmbientAudio  outdoor birds/wind beds and neighbour murmur
	Each frame it gathers where people are (the player plus walkers) so
	cars yield to them and gates open for them.

	Nothing here touches gameplay state. "Background life" in Settings
	turns traffic, walkers and world motion off (they fade away/settle).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Ambient = require(Shared.Data.Ambient)
local Settings = require(script.Parent.Parent.Parent.Settings)
local Traffic = require(script.Parent.Traffic)
local Pedestrians = require(script.Parent.Pedestrians)
local WorldMotion = require(script.Parent.WorldMotion)
local AmbientAudio = require(script.Parent.AmbientAudio)

local SETTING = "backgroundLife"
local AUDIO_INTERVAL = 0.5

local AmbientLife = {}
AmbientLife.__index = AmbientLife

function AmbientLife.new(controller, crosswalks)
	local self = setmetatable({
		controller = controller,
		crosswalks = crosswalks,
		data = Ambient,
		-- Ground positions of the player and visible walkers, this frame.
		people = {} :: { Vector3 },
		_sinceAudio = 0,
	}, AmbientLife)
	self.traffic = Traffic.new(self)
	self.pedestrians = Pedestrians.new(self)
	self.motion = WorldMotion.new(self)
	self.audio = AmbientAudio.new(self)
	return self
end

-- In-game minutes since midnight (nil outside a run).
function AmbientLife:gameMinutes(): number?
	return self.controller:getTime()
end

function AmbientLife:_setEnabled(enabled: boolean)
	self.traffic:setEnabled(enabled)
	self.pedestrians:setEnabled(enabled)
	self.motion:setEnabled(enabled)
end

function AmbientLife:start()
	local folder = Instance.new("Folder")
	folder.Name = "IgniteAmbientLife"
	folder.Parent = workspace
	self.worldFolder = folder

	self.motion:start()
	task.spawn(function()
		local ok, err = pcall(function()
			self.audio:start()
		end)
		if not ok then
			warn(`[AmbientLife] Audio: {err}`)
		end
	end)
	-- Templates are built by the server (AmbientTemplates); wait for them
	-- without holding up the rest of the client.
	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild(World.AmbientFolder, 30)
		if not templates then
			warn("[AmbientLife] No ambient templates; traffic and pedestrians disabled.")
			return
		end
		for _, system in { self.traffic, self.pedestrians } do
			task.spawn(function()
				local ok, err = pcall(system.start, system, templates)
				if not ok then
					warn(`[AmbientLife] {err}`)
				end
			end)
		end
		self:_setEnabled(Settings.get(SETTING))
	end)
	Settings.Changed:Connect(function(key, value)
		if key == SETTING then
			self:_setEnabled(value)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn(`[AmbientLife] {err}`)
		end
	end)
end

function AmbientLife:_update(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero

	-- Who's around: the player, then walkers (updated by Pedestrians).
	local people = self.people
	table.clear(people)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		table.insert(people, root.Position)
	end
	for _, position in self.pedestrians.positions do
		table.insert(people, position)
	end

	self.pedestrians:update(dt, cameraPosition)
	self.traffic:update(dt)
	self.motion:update(dt, cameraPosition)

	self._sinceAudio += dt
	if self._sinceAudio >= AUDIO_INTERVAL then
		self._sinceAudio = 0
		self.audio:update()
	end
end

return AmbientLife
