--[[
	AreaController

	Works out which area (bedroom, hallway, classroom) the character is in
	from the tagged area volumes, tells the GameController (which drives
	ambience and the objective marker), and shows a short area title when
	the player enters a new one.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Areas = require(Shared.Data.Areas)
local GameController = require(Shared.Game.GameController)
local PlayerControl = require(script.Parent.PlayerControl)

local CHECK_INTERVAL = 0.3

local AreaController = {}
AreaController.__index = AreaController

function AreaController.new(controller, transitions)
	return setmetatable({
		_controller = controller,
		_transitions = transitions,
		_volumes = {} :: { [BasePart]: string },
		_current = nil :: string?,
	}, AreaController)
end

local function isInside(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function AreaController:start()
	local function add(instance: Instance)
		local areaId = instance:GetAttribute(World.Attributes.AreaId)
		if instance:IsA("BasePart") and type(areaId) == "string" then
			self._volumes[instance] = areaId
		end
	end
	for _, instance in CollectionService:GetTagged(World.Tags.Area) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.Area):Connect(add)
	CollectionService:GetInstanceRemovedSignal(World.Tags.Area):Connect(function(instance)
		self._volumes[instance :: any] = nil
	end)

	local previousPhase = self._controller:getPhase()
	self._controller.Changed:Connect(function(phase)
		-- Title card when a run starts, for wherever the character is.
		if previousPhase == GameController.Phase.CharacterSelect and phase == GameController.Phase.Exploring then
			self._current = nil
		end
		previousPhase = phase
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			self:_check()
		end
	end)
end

function AreaController:_check()
	local phase = self._controller:getPhase()
	if phase == GameController.Phase.CharacterSelect or phase == GameController.Phase.Results then
		return
	end
	local position = PlayerControl.getRootPosition()
	if not position then
		return
	end
	local found = nil
	for part, areaId in self._volumes do
		if part.Parent and isInside(part, position) then
			found = areaId
			break
		end
	end
	if found and found ~= self._current then
		self._current = found
		self._controller:arriveAt(found)
		local area = Areas[found]
		if area then
			self._transitions:showAreaTitle(area.title)
		end
	end
end

return AreaController
