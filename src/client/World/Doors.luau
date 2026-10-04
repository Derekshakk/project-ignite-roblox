--[[
	Doors

	The one door system used by every hinged thing in the world: house and
	school doors (tagged IgniteDoor, built with Builder.door), the locker
	door and the planner cover. A leaf is described by attributes set at
	build time — HingeCFrame, ClosedOffset, OpenAngle — so any orientation
	works: the leaf rotates around its hinge's local Y axis, and the sign of
	OpenAngle picks the swing direction.

	Behaviour:
	- open/close is one eased swing (sine in-out, ~0.8 s for a full swing).
	  Each leaf has a single motion; a new request mid-swing turns it around
	  from where it is, so tweens never stack and doors can't get stuck.
	- toggles are rate-limited per door (spam is ignored)
	- doors in the same DoorGroup (double doors) move together
	- AutoClose: closes by itself after that many seconds, but never on
	  someone standing in the doorway (it waits and tries again)
	- Locked: trying it gives a small rattle and the door stays shut
	- a soft swing sound when opening and a latch click when it shuts
	- leaves that are solid only collide while fully closed, so a moving
	  door can never push or trap the player
	Movement is local to this client (single-player prototype).

	API: toggle(door), setOpen(door, open), pulse(door, seconds),
	isOpen(door), isLocked(door), resetAll(); `door` is a leaf part or a
	DoorId. Changed(leaf) fires when a door starts opening or closing.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Signal = require(Shared.Util.Signal)
local PlayerControl = require(script.Parent.PlayerControl)

local Attributes = World.Attributes

local FULL_SWING_SECONDS = 0.8
local MIN_SWING_SECONDS = 0.3
local TOGGLE_COOLDOWN = 0.45
local DOORWAY_CLEARANCE = 4 -- studs from the closed leaf's centre
local RETRY_CLOSE_SECONDS = 1.5
local RATTLE_DEGREES = 3

-- Sounds bundled with every Roblox client (PLACEHOLDERS: swap for door
-- sounds from the Creator Store later). Quiet, positional.
local SOUNDS = {
	open = { id = "rbxasset://sounds/swoosh.wav", volume = 0.18, speed = 0.7 },
	close = { id = "rbxasset://sounds/clickfast.wav", volume = 0.25, speed = 0.85 },
	rattle = { id = "rbxasset://sounds/clickfast.wav", volume = 0.3, speed = 1.25 },
}

local Doors = {}
Doors.Changed = Signal.new()

type State = {
	leaf: BasePart,
	hinge: CFrame,
	offset: CFrame,
	openAngle: number,
	angle: number,
	from: number,
	to: number,
	started: number,
	duration: number,
	moving: boolean,
	open: boolean,
	collides: boolean,
	group: string?,
	autoClose: number?,
	locked: boolean,
	lastToggle: number,
	closeToken: number,
	rattling: boolean,
}

local leaves: { [BasePart]: State } = {}
local byId: { [string]: BasePart } = {}

local function ease(t: number): number
	return (1 - math.cos(math.pi * math.clamp(t, 0, 1))) / 2
end

local function register(leaf: BasePart): State?
	local existing = leaves[leaf]
	if existing then
		return existing
	end
	local hinge = leaf:GetAttribute(Attributes.HingeCFrame)
	local offset = leaf:GetAttribute(Attributes.ClosedOffset)
	local openAngle = leaf:GetAttribute(Attributes.OpenAngle)
	if typeof(hinge) ~= "CFrame" or typeof(offset) ~= "CFrame" or type(openAngle) ~= "number" then
		return nil
	end
	local group = leaf:GetAttribute(Attributes.DoorGroup)
	local autoClose = leaf:GetAttribute(Attributes.AutoClose)
	local state: State = {
		leaf = leaf,
		hinge = hinge,
		offset = offset,
		openAngle = openAngle,
		angle = 0,
		from = 0,
		to = 0,
		started = 0,
		duration = 0,
		moving = false,
		open = false,
		collides = leaf.CanCollide,
		group = if type(group) == "string" then group else nil,
		autoClose = if type(autoClose) == "number" then autoClose else nil,
		locked = leaf:GetAttribute(Attributes.Locked) == true,
		lastToggle = -math.huge,
		closeToken = 0,
		rattling = false,
	}
	leaves[leaf] = state
	local doorId = leaf:GetAttribute(Attributes.DoorId)
	if type(doorId) == "string" and not byId[doorId] then
		byId[doorId] = leaf
	end
	return state
end

local function resolve(door: BasePart | string): State?
	local leaf = if type(door) == "string" then byId[door] else door
	return if leaf then register(leaf) else nil
end

-- The leaf and every other leaf in its group.
local function members(state: State): { State }
	if not state.group then
		return { state }
	end
	local list = {}
	for _, other in leaves do
		if other.group == state.group and other.leaf.Parent then
			table.insert(list, other)
		end
	end
	return list
end

local function playSound(leaf: BasePart, name: string)
	local spec = SOUNDS[name]
	local soundName = `IgniteDoor_{name}`
	local sound = leaf:FindFirstChild(soundName) :: Sound?
	if not sound then
		local created = Instance.new("Sound")
		created.Name = soundName
		created.SoundId = spec.id
		created.Volume = spec.volume
		created.PlaybackSpeed = spec.speed
		created.RollOffMinDistance = 6
		created.RollOffMaxDistance = 45
		created.Parent = leaf
		sound = created
	end
	(sound :: Sound):Play()
end

local function swingTo(state: State, angle: number)
	state.from = state.angle
	state.to = angle
	state.started = os.clock()
	local fraction = math.abs(angle - state.angle) / math.max(math.abs(state.openAngle), 1)
	state.duration = math.max(MIN_SWING_SECONDS, FULL_SWING_SECONDS * fraction)
	state.moving = true
end

local function closedPosition(state: State): Vector3
	return (state.hinge * state.offset).Position
end

local function scheduleAutoClose(state: State)
	if not state.autoClose then
		return
	end
	state.closeToken += 1
	local token = state.closeToken
	local function attempt(delaySeconds: number)
		task.delay(delaySeconds, function()
			if state.closeToken ~= token or not state.open then
				return
			end
			-- Never close on someone standing in the doorway.
			local position = PlayerControl.getRootPosition()
			for _, member in members(state) do
				if position and (position - closedPosition(member)).Magnitude < DOORWAY_CLEARANCE then
					attempt(RETRY_CLOSE_SECONDS)
					return
				end
			end
			Doors.setOpen(state.leaf, false)
		end)
	end
	attempt(state.autoClose)
end

-- Opens or closes a door (and its group). Returns false if unknown.
function Doors.setOpen(door: BasePart | string, open: boolean, silent: boolean?): boolean
	local state = resolve(door)
	if not state then
		return false
	end
	if state.open == open and not state.rattling then
		return true
	end
	for _, member in members(state) do
		member.open = open
		member.rattling = false
		member.closeToken += 1
		swingTo(member, if open then member.openAngle else 0)
	end
	if open and not silent then
		playSound(state.leaf, "open")
	end
	if open then
		scheduleAutoClose(state)
	end
	Doors.Changed:Fire(state.leaf)
	return true
end

--[[
	The player's "Open/Close Door". Returns "opened", "closed", "locked",
	or nil if ignored (pressed again too quickly, or unknown door).
]]
function Doors.toggle(door: BasePart | string): string?
	local state = resolve(door)
	if not state then
		return nil
	end
	local now = os.clock()
	if now - state.lastToggle < TOGGLE_COOLDOWN then
		return nil
	end
	for _, member in members(state) do
		member.lastToggle = now
	end
	if state.locked then
		if not state.moving then
			state.rattling = true
			swingTo(state, if state.openAngle >= 0 then RATTLE_DEGREES else -RATTLE_DEGREES)
			state.duration = 0.12
			playSound(state.leaf, "rattle")
		end
		return "locked"
	end
	local open = not state.open
	Doors.setOpen(state.leaf, open)
	return if open then "opened" else "closed"
end

-- Opens a door, then closes it after `seconds` (e.g. a locker).
function Doors.pulse(door: BasePart | string, seconds: number)
	local state = resolve(door)
	if not state then
		return
	end
	Doors.setOpen(state.leaf, true)
	state.closeToken += 1
	local token = state.closeToken
	task.delay(seconds, function()
		if state.closeToken == token then
			Doors.setOpen(state.leaf, false)
		end
	end)
end

function Doors.isOpen(door: BasePart | string): boolean
	local state = resolve(door)
	return state ~= nil and state.open
end

function Doors.isLocked(door: BasePart | string): boolean
	local state = resolve(door)
	return state ~= nil and state.locked
end

-- Closes every door quietly (new run).
function Doors.resetAll()
	for leaf, state in leaves do
		if state.open then
			state.closeToken += 1
			state.open = false
			swingTo(state, 0)
			Doors.Changed:Fire(leaf)
		end
	end
end

function Doors.start()
	for _, instance in CollectionService:GetTagged(World.Tags.Door) do
		if instance:IsA("BasePart") then
			register(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.Door):Connect(function(instance)
		if instance:IsA("BasePart") then
			register(instance)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for leaf, state in leaves do
			if not leaf.Parent then
				leaves[leaf] = nil
				continue
			end
			if not state.moving then
				continue
			end
			local t = (now - state.started) / state.duration
			local wasClosing = state.to == 0 and state.from ~= 0
			if t >= 1 then
				state.angle = state.to
				state.moving = false
			else
				state.angle = state.from + (state.to - state.from) * ease(t)
			end
			leaf.CFrame = state.hinge * CFrame.Angles(0, math.rad(state.angle), 0) * state.offset
			if state.collides then
				leaf.CanCollide = state.angle == 0
			end
			if not state.moving then
				if state.rattling and state.to ~= 0 then
					-- Rattle: straight back to closed.
					swingTo(state, 0)
					state.duration = 0.15
				elseif state.rattling then
					state.rattling = false
				elseif wasClosing then
					playSound(leaf, "close")
				end
			end
		end
	end)
end

return Doors
