--[[
	ZoneController

	Tracks which tagged zone parts the local character is standing in and
	reports enter/exit/tick to the GameController, which owns the rules and
	per-day limits. Also drives EnvironmentEffects for the zones' look and
	feel. Position checks run a few times per second (no Touched events), so
	they are stable even when standing still.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Zones = require(Shared.Data.Zones)
local GameController = require(Shared.Game.GameController)
local PlayerControl = require(script.Parent.PlayerControl)

local Phase = GameController.Phase

local CHECK_INTERVAL = 0.2

local ZoneController = {}
ZoneController.__index = ZoneController

function ZoneController.new(controller, effects)
	return setmetatable({
		_controller = controller,
		_effects = effects,
		_zoneParts = {} :: { [BasePart]: string },
		-- zoneId → seconds accumulated toward the next tick
		_inside = {} :: { [string]: number },
		_sinceCheck = 0,
	}, ZoneController)
end

local function isInside(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function ZoneController:start()
	local function add(instance: Instance)
		local zoneId = instance:GetAttribute(World.Attributes.ZoneId)
		if instance:IsA("BasePart") and type(zoneId) == "string" then
			if Zones.get(zoneId) then
				self._zoneParts[instance] = zoneId
			else
				warn(`[ZoneController] Zone part {instance:GetFullName()} has unknown zone "{zoneId}".`)
			end
		end
	end
	for _, instance in CollectionService:GetTagged(World.Tags.Zone) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.Zone):Connect(add)
	CollectionService:GetInstanceRemovedSignal(World.Tags.Zone):Connect(function(instance)
		self._zoneParts[instance :: any] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self._sinceCheck += deltaTime
		if self._sinceCheck >= CHECK_INTERVAL then
			local elapsed = self._sinceCheck
			self._sinceCheck = 0
			self:_check(elapsed)
		end
	end)

	self._controller.Changed:Connect(function(phase)
		if phase == Phase.CharacterSelect or phase == Phase.Results then
			self:_exitAll()
		end
	end)
	-- Picking up headphones etc. can change how a zone feels while inside it.
	self._controller.StateChanged:Connect(function()
		self:_refreshEffects()
	end)
end

function ZoneController:_check(elapsed: number)
	local phase = self._controller:getPhase()
	local sessionActive = phase ~= Phase.CharacterSelect and phase ~= Phase.Results
	local position = PlayerControl.getRootPosition()

	local current = {}
	if sessionActive and position then
		for part, zoneId in self._zoneParts do
			if part.Parent and isInside(part, position) then
				current[zoneId] = true
			end
		end
	end

	local changed = false
	for zoneId in self._inside do
		if not current[zoneId] then
			self._inside[zoneId] = nil
			self._controller:exitZone(zoneId)
			changed = true
		end
	end
	for zoneId in current do
		if self._inside[zoneId] == nil then
			self._inside[zoneId] = 0
			self._controller:enterZone(zoneId)
			changed = true
		end
	end
	if changed then
		self:_refreshEffects()
	end

	-- Ongoing effects only accumulate while exploring (not during dialogs).
	if phase == Phase.Exploring then
		for zoneId, accumulated in self._inside do
			local zone = Zones.get(zoneId)
			local interval = zone.tickSeconds or Zones.DEFAULT_TICK_SECONDS
			accumulated += elapsed
			if accumulated >= interval then
				accumulated -= interval
				self._controller:tickZone(zoneId)
			end
			self._inside[zoneId] = accumulated
		end
	end
end

function ZoneController:_refreshEffects()
	local resolved = {}
	for zoneId in self._inside do
		local zone = self._controller:getResolvedZone(zoneId)
		if zone then
			table.insert(resolved, zone)
		end
	end
	self._effects:apply(resolved)
end

function ZoneController:_exitAll()
	for zoneId in self._inside do
		self._controller:exitZone(zoneId)
	end
	table.clear(self._inside)
	self._effects:reset()
end

return ZoneController
