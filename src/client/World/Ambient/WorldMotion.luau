--[[
	WorldMotion

	Small looping motion for things tagged IgniteAmbientMotion by the world
	builders (attribute Motion):
		sway     tree canopies lean and rock gently in a light, gusting
		         breeze around their trunk top (MotionPivot, MotionAmount°)
		spin     a part turns about a world axis (sprinkler arm)
		gate     a garden gate (model, HingeCFrame / OpenAngle) swings open
		         when the player or a passer-by walks up, and closes again
		flutter  a flag (model of SegmentN parts) ripples from its hoist
		wag      a dog's tail wags in short bursts
	Everything is driven from one loop at ~30 Hz, only near the camera, and
	moved with one BulkMoveTo per tick. Motion is subtle on purpose; with
	"Background life" off in Settings, things settle back to rest.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

local Attributes = World.Attributes

local UPDATE_INTERVAL = 1 / 30
local RANGE = 130
local WIND = Vector3.new(1, 0, 0.35).Unit
local GATE_REACH = 4
local GATE_HOLD = 2.5
local GATE_SPEED = 2.2 -- rad/s

local WorldMotion = {}
WorldMotion.__index = WorldMotion

function WorldMotion.new(life)
	return setmetatable({
		_life = life,
		_trees = {} :: { [Vector3]: any },
		_spinners = {} :: { [BasePart]: any },
		_gates = {} :: { [Model]: any },
		_flags = {} :: { [Model]: any },
		_tails = {} :: { [BasePart]: any },
		_since = 0,
		_enabled = true,
		_parts = {} :: { BasePart },
		_cframes = {} :: { CFrame },
	}, WorldMotion)
end

local function hashPosition(position: Vector3): number
	local x = math.sin(position.X * 12.9898 + position.Z * 78.233) * 43758.5453
	return (x - math.floor(x)) * math.pi * 2
end

function WorldMotion:_add(instance: Instance)
	local kind = instance:GetAttribute(Attributes.Motion)
	if kind == "sway" and instance:IsA("BasePart") then
		local pivot = instance:GetAttribute(Attributes.MotionPivot)
		if typeof(pivot) ~= "Vector3" then
			return
		end
		local tree = self._trees[pivot]
		if not tree then
			tree = { pivot = pivot, phase = hashPosition(pivot), parts = {} }
			self._trees[pivot] = tree
		end
		tree.parts[instance] = {
			base = instance.CFrame,
			amount = math.rad(instance:GetAttribute(Attributes.MotionAmount) or 1),
		}
	elseif kind == "spin" and instance:IsA("BasePart") then
		local axis = instance:GetAttribute(Attributes.MotionAxis)
		local emitters = {}
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				table.insert(emitters, descendant)
			end
		end
		self._spinners[instance] = {
			base = instance.CFrame,
			axis = if typeof(axis) == "Vector3" then axis.Unit else Vector3.yAxis,
			speed = instance:GetAttribute(Attributes.MotionSpeed) or 1,
			angle = 0,
			emitters = emitters,
			spraying = nil :: boolean?,
		}
	elseif kind == "wag" and instance:IsA("BasePart") then
		local pivot = instance:GetAttribute(Attributes.MotionPivot)
		local axis = instance:GetAttribute(Attributes.MotionAxis)
		self._tails[instance] = {
			base = instance.CFrame,
			pivot = if typeof(pivot) == "Vector3" then pivot else instance.Position,
			axis = if typeof(axis) == "Vector3" then axis.Unit else Vector3.yAxis,
			speed = instance:GetAttribute(Attributes.MotionSpeed) or 8,
			amount = math.rad(instance:GetAttribute(Attributes.MotionAmount) or 20),
			phase = hashPosition(instance.Position),
			blend = 0,
		}
	elseif (kind == "gate" or kind == "flutter") and instance:IsA("Model") then
		-- Parts may stream in a moment after the model; collect them lazily.
		task.defer(function()
			self:_addModel(instance, kind)
		end)
	end
end

function WorldMotion:_addModel(model: Model, kind: string)
	if not model.Parent then
		return
	end
	if kind == "gate" then
		local hinge = model:GetAttribute(Attributes.HingeCFrame)
		if typeof(hinge) ~= "CFrame" then
			return
		end
		local entry = { hinge = hinge, angle = 0, openAngle = math.rad(model:GetAttribute(Attributes.OpenAngle) or 75), parts = {}, offsets = {}, holdUntil = 0 }
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(entry.parts, part)
				table.insert(entry.offsets, hinge:ToObjectSpace(part.CFrame))
			end
		end
		-- Centre of the opening, for "someone is walking up to it".
		local width = 0
		for _, offset in entry.offsets do
			width = math.max(width, -offset.Position.Z)
		end
		entry.center = (hinge * CFrame.new(0, 0, -width / 2)).Position
		self._gates[model] = entry
	else
		local hoist = model:GetAttribute(Attributes.MotionPivot)
		if typeof(hoist) ~= "CFrame" then
			return
		end
		local entry = { hoist = hoist, amount = math.rad(model:GetAttribute(Attributes.MotionAmount) or 12), parts = {}, segment = {}, rest = {} }
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local offset = hoist:ToObjectSpace(part.CFrame)
				local along = math.max(0, -offset.Position.Z)
				local index = math.clamp(math.floor(along) + 1, 1, 3)
				table.insert(entry.parts, part)
				table.insert(entry.segment, index)
				-- Relative to the start of its segment, at rest.
				table.insert(entry.rest, CFrame.new(0, 0, index - 1) * offset)
			end
		end
		self._flags[model] = entry
	end
end

function WorldMotion:_remove(instance: Instance)
	if instance:IsA("BasePart") then
		self._spinners[instance] = nil
		self._tails[instance] = nil
		local pivot = instance:GetAttribute(Attributes.MotionPivot)
		local tree = typeof(pivot) == "Vector3" and self._trees[pivot]
		if tree then
			tree.parts[instance] = nil
		end
	elseif instance:IsA("Model") then
		self._gates[instance] = nil
		self._flags[instance] = nil
	end
end

function WorldMotion:start()
	local tag = World.Tags.AmbientMotion
	for _, instance in CollectionService:GetTagged(tag) do
		self:_add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		self:_add(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		self:_remove(instance)
	end)
end

function WorldMotion:setEnabled(enabled: boolean)
	self._enabled = enabled
end

local function within(position: Vector3, cameraPosition: Vector3, range: number): boolean
	return (position - cameraPosition).Magnitude < range
end

function WorldMotion:update(dt: number, cameraPosition: Vector3)
	self._since += dt
	if self._since < UPDATE_INTERVAL then
		return
	end
	dt = self._since
	self._since = 0
	local now = os.clock()
	local parts, cframes = self._parts, self._cframes
	table.clear(parts)
	table.clear(cframes)
	local function move(part: BasePart, cframe: CFrame)
		table.insert(parts, part)
		table.insert(cframes, cframe)
	end
	-- Settle back to rest when disabled (once), then stop.
	local strength = if self._enabled then 1 else 0

	-- Wind: a slow breathing strength with occasional gusts.
	local wind = 0.65 + 0.25 * math.sin(now * 0.13) + 0.2 * math.max(0, math.sin(now * 0.31 + 1.2)) ^ 3
	local axis = Vector3.yAxis:Cross(WIND)
	for pivot, tree in self._trees do
		if within(pivot, cameraPosition, RANGE) then
			local sway = (math.sin(now * 1.1 + tree.phase) * 0.7 + math.sin(now * 2.3 + tree.phase * 1.7) * 0.3) * wind + 0.35 * wind
			local around = CFrame.new(pivot)
			local inverse = around:Inverse()
			for part, entry in tree.parts do
				local angle = sway * entry.amount * strength
				move(part, around * CFrame.fromAxisAngle(axis, angle) * inverse * entry.base)
			end
		end
	end

	for part, entry in self._spinners do
		local near = within(entry.base.Position, cameraPosition, RANGE)
		if near then
			entry.angle = (entry.angle + entry.speed * dt * strength) % (math.pi * 2)
			move(part, CFrame.new(entry.base.Position) * CFrame.fromAxisAngle(entry.axis, entry.angle) * entry.base.Rotation)
		end
		-- Water only while someone could see it.
		local spraying = near and self._enabled
		if spraying ~= entry.spraying then
			entry.spraying = spraying
			for _, emitter in entry.emitters do
				emitter.Enabled = spraying
			end
		end
	end

	for part, entry in self._tails do
		if within(entry.base.Position, cameraPosition, RANGE) then
			-- Bursts of wagging with rests in between.
			local wanted = if math.sin(now * 0.7 + entry.phase) > -0.2 then 1 else 0.15
			entry.blend += (wanted * strength - entry.blend) * math.min(1, dt * 2)
			local angle = math.sin(now * entry.speed + entry.phase) * entry.amount * entry.blend
			local around = CFrame.new(entry.pivot)
			move(part, around * CFrame.fromAxisAngle(entry.axis, angle) * around:Inverse() * entry.base)
		end
	end

	local people = self._life.people
	for _, gate in self._gates do
		if within(gate.center, cameraPosition, RANGE) then
			for _, position in people do
				if Vector3.new(position.X - gate.center.X, 0, position.Z - gate.center.Z).Magnitude < GATE_REACH then
					gate.holdUntil = now + GATE_HOLD
					break
				end
			end
			local target = if now < gate.holdUntil and self._enabled then gate.openAngle else 0
			if gate.angle ~= target then
				local step = GATE_SPEED * dt
				-- Ease near the ends of the swing.
				local remaining = math.abs(target - gate.angle)
				step *= math.clamp(remaining / 0.4, 0.25, 1)
				gate.angle += math.clamp(target - gate.angle, -step, step)
				local frame = gate.hinge * CFrame.Angles(0, gate.angle, 0)
				for i, part in gate.parts do
					move(part, frame * gate.offsets[i])
				end
			end
		end
	end

	for _, flag in self._flags do
		if within(flag.hoist.Position, cameraPosition, RANGE) then
			local frames = {}
			local frame = flag.hoist
			for index = 1, 3 do
				local angle = math.sin(now * 2.2 - index * 0.9) * flag.amount * (0.5 + index * 0.25) * strength
				frame = frame * CFrame.Angles(0, angle, 0)
				frames[index] = frame
				frame = frame * CFrame.new(0, 0, -1)
			end
			for i, part in flag.parts do
				move(part, frames[flag.segment[i]] * flag.rest[i])
			end
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return WorldMotion
