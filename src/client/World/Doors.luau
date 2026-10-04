--[[
	Doors

	Animates hinged door leaves built with Builder.hingedLeaf (attributes
	HingeCFrame, ClosedOffset, OpenAngle). Doors tagged IgniteAutoDoor open
	when the player is near and close when they leave; any other leaf (e.g.
	a locker door) can be opened briefly with Doors.pulse.

	Movement is eased and local to this client. Leaves don't collide, so a
	moving door can never push or trap the player.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local PlayerControl = require(script.Parent.PlayerControl)

local Attributes = World.Attributes

local AUTO_OPEN_DISTANCE = 10
local EASE_SPEED = 5 -- higher = faster

local Doors = {}

-- leaf → { hinge, offset, openAngle, angle, target, auto, token }
local leaves: { [BasePart]: any } = {}

local function register(leaf: BasePart, auto: boolean)
	local existing = leaves[leaf]
	if existing then
		existing.auto = existing.auto or auto
		return existing
	end
	local hinge = leaf:GetAttribute(Attributes.HingeCFrame)
	local offset = leaf:GetAttribute(Attributes.ClosedOffset)
	local openAngle = leaf:GetAttribute(Attributes.OpenAngle)
	if typeof(hinge) ~= "CFrame" or typeof(offset) ~= "CFrame" or type(openAngle) ~= "number" then
		return nil
	end
	local state = { hinge = hinge, offset = offset, openAngle = openAngle, angle = 0, target = 0, auto = auto, token = 0 }
	leaves[leaf] = state
	return state
end

function Doors.setOpen(leaf: BasePart, open: boolean)
	local state = register(leaf, false)
	if state then
		state.target = if open then state.openAngle else 0
	end
end

-- Opens a door, then closes it after `seconds`.
function Doors.pulse(leaf: BasePart, seconds: number)
	local state = register(leaf, false)
	if not state then
		return
	end
	state.token += 1
	local token = state.token
	state.target = state.openAngle
	task.delay(seconds, function()
		if state.token == token then
			state.target = 0
		end
	end)
end

function Doors.start()
	local function addAuto(instance: Instance)
		if instance:IsA("BasePart") then
			register(instance, true)
		end
	end
	for _, instance in CollectionService:GetTagged(World.Tags.AutoDoor) do
		addAuto(instance)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.AutoDoor):Connect(addAuto)

	RunService.Heartbeat:Connect(function(dt)
		local position = PlayerControl.getRootPosition()
		for leaf, state in leaves do
			if not leaf.Parent then
				leaves[leaf] = nil
				continue
			end
			if state.auto then
				local closedPosition = (state.hinge * state.offset).Position
				local near = position ~= nil and (position - closedPosition).Magnitude < AUTO_OPEN_DISTANCE
				state.target = if near then state.openAngle else 0
			end
			if math.abs(state.target - state.angle) > 0.05 then
				state.angle += (state.target - state.angle) * math.min(1, dt * EASE_SPEED)
				leaf.CFrame = state.hinge * CFrame.Angles(0, math.rad(state.angle), 0) * state.offset
			end
		end
	end)
end

return Doors
