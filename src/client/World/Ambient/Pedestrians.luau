--[[
	Pedestrians

	Background walkers on the waypoint routes in Data/Ambient: students
	heading to school (and home again in the afternoon), neighbours on a
	stroll, someone walking a dog, someone bringing groceries home, someone
	checking the mail. Simple and predictable — no pathfinding:
	- each walker moves along its route at its own pace, easing into and
	  out of stops, slowing for sharp turns and turning its body smoothly
	  toward where it's going
	- it pauses at points of interest (with a small gesture: reaching into
	  a mailbox, reading, looking around), waits at the curb for the walk
	  signal or for traffic, keeps a little to the right, and steps around
	  the player and other walkers instead of walking through them
	- students sometimes walk in pairs, glancing at each other as they go
	- one-way walkers appear at the start of their route only while it is
	  out of sight, fade in, and fade out at the end (going indoors)

	Animation: Roblox's default R15 walk and idle (placeholders, the same
	ones the default Animate script uses), blended by speed, with the walk
	played at a rate that matches the ground speed so feet don't slide.
	If the walk can't be loaded, a procedural walk cycle on the leg and arm
	joints is used instead. Head turns and gestures are layered on the
	joints. Rigs that can't animate (no joints) are never used.

	Walkers are local to this client, anchored, and don't collide. Far
	away they are moved a few times a second without animation.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Clock = require(Shared.Game.Clock)
local Paths = require(script.Parent.Paths)

-- Roblox-owned default R15 animations. PLACEHOLDERS: swap for custom ones.
local WALK_ANIMATION_ID = "rbxassetid://913402848"
local IDLE_ANIMATION_ID = "rbxassetid://507766666"
-- The default walk plays at normal speed when moving about this many studs
-- per second per stud of hip height (as in Roblox's Animate script).
local WALK_SPEED_PER_HIP = 3.2

local JOINT_NAMES = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"LeftShoulder",
	"RightElbow",
	"LeftElbow",
	"RightHip",
	"LeftHip",
	"RightKnee",
	"LeftKnee",
}
local ACCEL = 2.5
local DECEL = 4
local MAX_TURN_RATE = 4.5 -- rad/s
local CORNER_RADIUS = 1.2
local FADE_SECONDS = 0.8
local FAR_UPDATE = 1 / 4
local AVOID_INTERVAL = 0.12
local FOOTSTEP_DISTANCE = 24
local DOG_BEHIND = 1.6
local DOG_SIDE = 1.25

local Pedestrians = {}
Pedestrians.__index = Pedestrians

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Pedestrians.new(life)
	return setmetatable({
		_life = life,
		_random = Random.new(),
		_routes = {} :: { any },
		_walkers = {} :: { any },
		_pool = {} :: { [string]: { any } },
		_inUse = {} :: { [string]: number },
		_enabled = true,
		_ready = false,
		_sinceAvoid = 0,
		positions = {} :: { Vector3 },
	}, Pedestrians)
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

local function parseSchedule(schedule)
	if not schedule then
		return nil
	end
	local windows = {}
	for _, window in schedule do
		table.insert(windows, {
			from = Clock.parse(window.fromTime),
			upTo = Clock.parse(window.untilTime),
			reverse = window.reverse == true,
		})
	end
	return windows
end

function Pedestrians:_resolve(point: any): Vector3?
	if typeof(point) == "Vector3" then
		return point
	elseif type(point) == "string" then
		local value = self._markers:GetAttribute(point)
		if typeof(value) ~= "Vector3" then
			warn(`[Pedestrians] Route marker "{point}" not found.`)
			return nil
		end
		return value
	end
	return nil
end

function Pedestrians:_buildRoute(spec)
	local points, events = {}, {}
	for _, raw in spec.points do
		local entry = if type(raw) == "table" then raw else { at = raw }
		local position = self:_resolve(entry.at)
		if not position then
			return nil
		end
		table.insert(points, position)
		events[#points] = entry
	end
	local path = Paths.build(points, nil, CORNER_RADIUS)
	local route = {
		spec = spec,
		path = path,
		events = {},
		walkers = {} :: { any },
		schedule = parseSchedule(spec.schedule),
		nextSpawn = os.clock() + self._random:NextNumber(0.5, 3),
		look = {},
	}
	local crossings = self._life.data.crossings
	for i, entry in events do
		local event = {
			distance = path.marks[i],
			pause = entry.pause,
			gesture = entry.gesture,
			look = if entry.look then self:_resolve(entry.look) else nil,
			wait = entry.wait,
			-- Only wait when the next steps lead into the road.
			waitsWhen = {} :: { [number]: boolean },
		}
		if entry.wait and crossings[entry.wait] then
			local crossing = crossings[entry.wait]
			for _, direction in { 1, -1 } do
				local ahead = Paths.sample(path, path.marks[i] + direction * 2.5)
				event.waitsWhen[direction] = ahead.X >= crossing.min.X and ahead.X <= crossing.max.X and ahead.Z >= crossing.min.Y and ahead.Z <= crossing.max.Y
			end
		end
		table.insert(route.events, event)
	end
	table.sort(route.events, function(a, b)
		return a.distance < b.distance
	end)
	return route
end

function Pedestrians:start(templates: Instance)
	self._people = templates:WaitForChild("People", 20)
	self._props = templates:WaitForChild("Props", 20)
	self._markers = templates:WaitForChild("Markers", 20)
	if not (self._people and self._props and self._markers) then
		warn("[Pedestrians] Templates missing; pedestrians disabled.")
		return
	end
	-- Rigs are built in parallel on the server; give them a moment.
	local deadline = os.clock() + 10
	while #self._people:GetChildren() < 4 and os.clock() < deadline do
		task.wait(0.25)
	end
	for _, spec in self._life.data.pedestrians do
		local ok, route = pcall(self._buildRoute, self, spec)
		if ok and route then
			table.insert(self._routes, route)
		elseif not ok then
			warn(`[Pedestrians] Route "{spec.id}": {route}`)
		end
	end
	self._ready = true
	self:_populate()
end

-- Places the back-and-forth walkers somewhere along their routes.
function Pedestrians:_populate()
	for _, route in self._routes do
		if route.spec.mode == "pingpong" and #route.walkers == 0 then
			local distance = self._random:NextNumber(0.1, 0.9) * route.path.length
			self:_spawn(route, distance, if self._random:NextNumber() < 0.5 then 1 else -1, true)
		end
	end
end

function Pedestrians:setEnabled(enabled: boolean)
	if enabled == self._enabled then
		return
	end
	self._enabled = enabled
	if enabled then
		if self._ready then
			self:_populate()
		end
	else
		for _, walker in table.clone(self._walkers) do
			self:_release(walker)
		end
	end
end

---------------------------------------------------------------------------
-- Walkers
---------------------------------------------------------------------------

function Pedestrians:_pickTemplate(kind: string): Instance?
	local best, bestUse = nil, math.huge
	for _, template in self._people:GetChildren() do
		if template:GetAttribute("Kind") == kind then
			local use = (self._inUse[template.Name] or 0) + self._random:NextNumber(0, 0.5)
			if use < bestUse then
				best, bestUse = template, use
			end
		end
	end
	return best
end

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack?
	local ok, track = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = priority
	track.Looped = true
	return track
end

function Pedestrians:_create(template: Instance)
	local model = (template :: Model):Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return nil
	end
	pcall(function()
		(humanoid :: any).EvaluateStateMachine = false
	end)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	local walker = {
		template = template.Name,
		model = model,
		root = root,
		humanoid = humanoid,
		joints = {},
		fadeParts = {},
		hipHeight = humanoid.HipHeight,
		standingHeight = model:GetAttribute("StandingHeight") or (humanoid.HipHeight + root.Size.Y / 2),
	}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			table.insert(walker.fadeParts, descendant)
		elseif descendant:IsA("Decal") then
			table.insert(walker.fadeParts, descendant)
		elseif descendant:IsA("Motor6D") and table.find(JOINT_NAMES, descendant.Name) then
			walker.joints[descendant.Name] = { motor = descendant, base = descendant.C0 }
		end
	end
	if not walker.joints.Neck or not walker.joints.RightHip then
		model:Destroy()
		return nil
	end
	return walker
end

function Pedestrians:_ensureTracks(walker)
	if walker.walkTrack or walker.tracksTried then
		return
	end
	walker.tracksTried = true
	local animator = walker.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		walker.procedural = true
		return
	end
	walker.walkTrack = loadTrack(animator, WALK_ANIMATION_ID, Enum.AnimationPriority.Movement)
	walker.idleTrack = loadTrack(animator, IDLE_ANIMATION_ID, Enum.AnimationPriority.Idle)
	if not walker.walkTrack then
		walker.procedural = true
	else
		-- If the asset never loads (Length stays 0), walk procedurally.
		task.delay(3, function()
			if walker.walkTrack and walker.walkTrack.Length == 0 then
				walker.walkTrack:Stop(0)
				walker.walkTrack = nil
				walker.procedural = true
			end
		end)
	end
end

function Pedestrians:_playTracks(walker)
	self:_ensureTracks(walker)
	walker.walkWeight = -1
	if walker.idleTrack then
		walker.idleTrack:Play(0.3, 1, self._random:NextNumber(0.9, 1.1))
	end
	if walker.walkTrack then
		walker.walkTrack:Play(0.3, 0.01, 1)
		walker.walkTrack.TimePosition = self._random:NextNumber(0, 1)
	end
	walker.tracksPlaying = true
end

function Pedestrians:_stopTracks(walker)
	for _, track in { walker.walkTrack, walker.idleTrack } do
		if track then
			track:Stop(0.2)
		end
	end
	walker.tracksPlaying = false
end

-- Welds a prop template into the walker's hand.
function Pedestrians:_carry(walker, propName: string, handName: string)
	local template = self._props:FindFirstChild(propName)
	local hand = walker.model:FindFirstChild(handName)
	if not template or not hand or not hand:IsA("BasePart") then
		return
	end
	local prop = (template :: Model):Clone()
	local grip = prop:GetAttribute("Grip")
	prop:PivotTo(hand.CFrame * (if typeof(grip) == "CFrame" then grip else CFrame.new()))
	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = part
			weld.Parent = part
			table.insert(walker.fadeParts, part)
		end
	end
	prop.Parent = walker.model
	walker.prop = prop
end

-- A dog on a leash for this walker (from the Props templates).
function Pedestrians:_attachDog(walker)
	local templates = {}
	for _, child in self._props:GetChildren() do
		if string.sub(child.Name, 1, 3) == "Dog" then
			table.insert(templates, child)
		end
	end
	if #templates == 0 then
		return
	end
	local model = (templates[self._random:NextInteger(1, #templates)] :: Model):Clone()
	model:PivotTo(CFrame.new())
	local dog = {
		model = model,
		parts = {} :: { BasePart },
		offsets = {} :: { CFrame },
		kinds = {} :: { string },
		pivots = {} :: { CFrame },
		cframes = {} :: { CFrame },
		phase = 0,
		yaw = walker.yaw,
		wag = 0,
		sniff = 0,
	}
	local neck = CFrame.new(0, 1.85, -1.0)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local offset = part.CFrame
			local pivot = part:GetAttribute("Pivot")
			local kind, pivotFrame = "body", CFrame.new()
			if typeof(pivot) == "CFrame" then
				kind = if part.Name == "Tail" then "tail" else part.Name
				pivotFrame = pivot
			elseif part:GetAttribute("HeadPart") then
				kind, pivotFrame = "head", neck
			end
			table.insert(dog.parts, part)
			table.insert(dog.offsets, pivotFrame:Inverse() * offset)
			table.insert(dog.kinds, kind)
			table.insert(dog.pivots, pivotFrame)
			table.insert(dog.cframes, offset)
			table.insert(walker.fadeParts, part)
		end
	end
	-- Leash from the walker's left hand to the collar, sagging a little.
	local hand = walker.model:FindFirstChild("LeftHand")
	local collar = model:FindFirstChild("LeashPoint", true) :: Attachment?
	if hand and collar then
		local down = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
		local handPoint = Instance.new("Attachment")
		handPoint.Name = "LeashHand"
		handPoint.CFrame = CFrame.new(0, -0.2, 0) * down
		handPoint.Parent = hand
		collar.CFrame = down
		local leash = Instance.new("Beam")
		leash.Attachment0 = handPoint
		leash.Attachment1 = collar
		leash.Color = ColorSequence.new(Color3.fromRGB(150, 50, 50))
		leash.Width0 = 0.1
		leash.Width1 = 0.1
		leash.CurveSize0 = 0.9
		leash.CurveSize1 = -0.9
		leash.Segments = 8
		leash.FaceCamera = true
		leash.LightInfluence = 1
		leash.Transparency = NumberSequence.new(0)
		leash.Parent = model.PrimaryPart
		dog.leash = leash
		dog.handPoint = handPoint
	end
	model.Parent = self._life.worldFolder
	walker.dog = dog
end

function Pedestrians:_spawn(route, distance: number, direction: number, instant: boolean?, buddy: any?, groupOffset: number?)
	local spec = route.spec
	local template = self:_pickTemplate(spec.kind)
	if not template then
		return nil
	end
	local pool = self._pool[template.Name]
	local walker = if pool and #pool > 0 then table.remove(pool) else self:_create(template)
	if not walker then
		return nil
	end
	self._inUse[walker.template] = (self._inUse[walker.template] or 0) + 1
	local _, tangent = Paths.sample(route.path, distance)
	walker.route = route
	walker.distance = distance
	walker.direction = direction
	walker.baseSpeed = if buddy then buddy.baseSpeed else self._random:NextNumber(spec.speed[1], spec.speed[2])
	walker.speed = if instant then walker.baseSpeed else walker.baseSpeed * 0.6
	walker.groupOffset = groupOffset or 0
	walker.lateral = (spec.keepRight or 0) + walker.groupOffset
	walker.avoid = 0
	walker.slow = 1
	walker.yaw = yawOf(tangent * direction)
	walker.state = "walk"
	walker.pauseUntil = 0
	walker.event = nil
	walker.look = nil
	walker.gesture = nil
	walker.gestureStart = 0
	walker.leaving = false
	walker.fade = if instant then 1 else 0
	walker.buddy = buddy
	walker.phase = self._random:NextNumber(0, math.pi * 2)
	walker.stride = 0
	walker.headYaw, walker.headPitch = 0, 0
	walker.glanceYaw, walker.nextGlance = 0, os.clock() + self._random:NextNumber(1, 4)
	walker.sinceUpdate = 0
	walker.position = Vector3.zero
	walker.travel = tangent * direction
	walker.right = Vector3.new(-walker.travel.Z, 0, walker.travel.X)
	if buddy then
		buddy.buddy = walker
	end
	for _, part in walker.fadeParts do
		part.LocalTransparencyModifier = 1 - walker.fade
	end
	walker.model.Parent = self._life.worldFolder
	if spec.carry and not walker.prop then
		self:_carry(walker, spec.carry, "RightHand")
	end
	if spec.dog and not walker.dog then
		self:_attachDog(walker)
	end
	self:_playTracks(walker)
	self:_findNextEvent(walker)
	table.insert(route.walkers, walker)
	table.insert(self._walkers, walker)
	self:_move(walker, 0, os.clock(), true)
	return walker
end

function Pedestrians:_release(walker)
	local route = walker.route
	local index = table.find(route.walkers, walker)
	if index then
		table.remove(route.walkers, index)
	end
	index = table.find(self._walkers, walker)
	if index then
		table.remove(self._walkers, index)
	end
	if walker.buddy and walker.buddy.buddy == walker then
		walker.buddy.buddy = nil
	end
	walker.buddy = nil
	self._inUse[walker.template] = math.max(0, (self._inUse[walker.template] or 1) - 1)
	self:_stopTracks(walker)
	if walker.steps then
		walker.steps:Stop()
	end
	-- Props and dogs belong to a route; drop them so the rig can be reused
	-- anywhere.
	local function forget(instance: Instance?)
		if not instance then
			return
		end
		local keep = {}
		for _, part in walker.fadeParts do
			if not part:IsDescendantOf(instance) then
				table.insert(keep, part)
			end
		end
		walker.fadeParts = keep
		instance:Destroy()
	end
	if walker.prop then
		forget(walker.prop)
		walker.prop = nil
	end
	if walker.dog then
		if walker.dog.handPoint then
			walker.dog.handPoint:Destroy()
		end
		forget(walker.dog.model)
		walker.dog = nil
	end
	walker.model.Parent = nil
	self._pool[walker.template] = self._pool[walker.template] or {}
	table.insert(self._pool[walker.template], walker)
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------

-- The next route event in the walker's direction of travel. Events at the
-- very ends are handled by _endOfRoute (the turnaround) instead.
function Pedestrians:_findNextEvent(walker)
	local events = walker.route.events
	local length = walker.route.path.length
	walker.event = nil
	if walker.direction > 0 then
		for _, event in events do
			if event.distance >= length - 0.05 then
				return
			end
			if event.distance > walker.distance + 0.05 then
				walker.event = event
				return
			end
		end
	else
		for i = #events, 1, -1 do
			if events[i].distance <= 0.05 then
				return
			end
			if events[i].distance < walker.distance - 0.05 then
				walker.event = events[i]
				return
			end
		end
	end
end

-- Whether the walker should stop at this event (pause, or a curb with
-- the road ahead).
local function stopsAt(walker, event): boolean
	return event.pause ~= nil or (event.wait ~= nil and event.waitsWhen[walker.direction] == true)
end

function Pedestrians:_arrive(walker, event, now: number)
	if event.wait and event.waitsWhen[walker.direction] then
		walker.state = "wait"
		walker.waitFor = event.wait
		walker.waitSince = now
		walker.look = nil
	elseif event.pause then
		walker.state = "pause"
		walker.pauseUntil = now + self._random:NextNumber(event.pause[1], event.pause[2])
		walker.look = event.look
		walker.gesture = event.gesture
		walker.gestureStart = now
		walker.gestureEnd = walker.pauseUntil
	end
	self:_findNextEvent(walker)
end

function Pedestrians:_mayCross(walker, now: number): boolean
	local crossing = self._life.data.crossings[walker.waitFor]
	if not crossing then
		return true
	end
	if crossing.signal then
		return self._life.crosswalks:isWalking(crossing.signal)
	end
	-- Look both ways first, then go once nothing is about to pass.
	return now - walker.waitSince > 1.4 and self._life.traffic:isSafeToCross(walker.waitFor)
end

function Pedestrians:_endOfRoute(walker, now: number)
	local spec = walker.route.spec
	if spec.mode == "oneway" then
		walker.leaving = true
		walker.state = "pause"
		walker.pauseUntil = math.huge
		return
	end
	-- Turn around after a pause (with the end point's gesture, if any).
	local events = walker.route.events
	local endEvent = if walker.direction > 0 then events[#events] else events[1]
	walker.state = "pause"
	walker.reverseAfterPause = true
	local range = (endEvent and endEvent.pause) or spec.endPause or { 1, 3 }
	walker.pauseUntil = now + self._random:NextNumber(range[1], range[2])
	walker.look = endEvent and endEvent.look
	walker.gesture = endEvent and endEvent.gesture
	walker.gestureStart = now
	walker.gestureEnd = walker.pauseUntil
end

function Pedestrians:_move(walker, dt: number, now: number, snap: boolean?)
	local route = walker.route
	local path = route.path
	local spec = route.spec

	-- State changes.
	if walker.state == "pause" and now >= walker.pauseUntil then
		walker.state = "walk"
		walker.gesture = nil
		walker.look = nil
		if walker.reverseAfterPause then
			walker.reverseAfterPause = false
			walker.direction = -walker.direction
			self:_findNextEvent(walker)
		end
	elseif walker.state == "wait" and self:_mayCross(walker, now) then
		walker.state = "walk"
	end

	-- Speed.
	local target = 0
	if walker.state == "walk" and not walker.leaving then
		target = walker.baseSpeed * walker.slow
		local event = walker.event
		if event and stopsAt(walker, event) then
			local remaining = math.abs(event.distance - walker.distance)
			target = math.min(target, math.sqrt(2 * DECEL * 0.6 * remaining) + 0.15)
		end
		local remainingRoute = if walker.direction > 0 then path.length - walker.distance else walker.distance
		if spec.mode == "pingpong" then
			target = math.min(target, math.sqrt(2 * DECEL * 0.6 * remainingRoute) + 0.15)
		end
		-- Slow for sharp turns.
		local _, tangent = Paths.sample(path, walker.distance)
		local turn = math.abs(wrap(yawOf(tangent * walker.direction) - walker.yaw))
		target *= math.clamp(1 - turn / 1.8, 0.3, 1)
		if walker.buddy then
			target = math.min(target, walker.buddy.speed + 0.4)
		end
	end
	if snap then
		walker.speed = if walker.state == "walk" then walker.speed else 0
	elseif walker.speed < target then
		walker.speed = math.min(target, walker.speed + ACCEL * dt)
	else
		walker.speed = math.max(target, walker.speed - DECEL * dt)
	end

	-- Advance, and handle events passed on the way.
	local previous = walker.distance
	walker.distance = math.clamp(walker.distance + walker.direction * walker.speed * dt, 0, path.length)
	local event = walker.event
	if event and walker.state == "walk" and (event.distance - previous) * walker.direction >= 0 and (event.distance - walker.distance) * walker.direction <= 0 then
		if stopsAt(walker, event) then
			walker.distance = event.distance
		end
		self:_arrive(walker, event, now)
	end
	if walker.state == "walk" and not walker.leaving then
		local atEnd = if walker.direction > 0 then walker.distance >= path.length - 0.02 else walker.distance <= 0.02
		if atEnd then
			self:_endOfRoute(walker, now)
		end
	end

	-- Where to stand, and which way to face.
	local position, tangent = Paths.sample(path, walker.distance)
	local travel = tangent * walker.direction
	walker.travel = travel
	walker.right = Vector3.new(-travel.Z, 0, travel.X)
	local lateralTarget = (spec.keepRight or 0) + walker.groupOffset + walker.avoid
	local limit = if (spec.keepRight or 0) > 0 then 1.9 else 0.7
	lateralTarget = math.clamp(lateralTarget, -limit, limit)
	local step = 1.6 * dt
	walker.lateral += math.clamp(lateralTarget - walker.lateral, -step, step)
	local ground = position + walker.right * walker.lateral

	local desired = yawOf(travel)
	if walker.state ~= "walk" and walker.look then
		local toLook = walker.look - ground
		if Vector3.new(toLook.X, 0, toLook.Z).Magnitude > 0.5 then
			desired = yawOf(Vector3.new(toLook.X, 0, toLook.Z))
		end
	elseif walker.state == "pause" and walker.reverseAfterPause then
		desired = walker.yaw -- turn around only once moving off
	end
	if snap then
		walker.yaw = desired
	else
		local difference = wrap(desired - walker.yaw)
		local turnStep = math.clamp(difference * math.min(1, dt * 6), -MAX_TURN_RATE * dt, MAX_TURN_RATE * dt)
		walker.yaw = wrap(walker.yaw + turnStep)
	end
	walker.position = ground
	walker.root.CFrame = CFrame.new(ground.X, position.Y + walker.standingHeight, ground.Z) * CFrame.Angles(0, walker.yaw, 0)
end

---------------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------------

function Pedestrians:_animate(walker, dt: number, now: number, cameraPosition: Vector3)
	if not walker.tracksPlaying then
		self:_playTracks(walker)
	end
	local speed = walker.speed
	-- Blend walk/idle by speed; play the walk at the matching rate.
	local walkWeight = math.clamp(speed / 1.4, 0, 1)
	if walker.walkTrack then
		if math.abs(walkWeight - walker.walkWeight) > 0.04 then
			walker.walkWeight = walkWeight
			walker.walkTrack:AdjustWeight(math.max(walkWeight, 0.01), 0.2)
			if walker.idleTrack then
				walker.idleTrack:AdjustWeight(math.max(1 - walkWeight, 0.05), 0.2)
			end
		end
		if speed > 0.2 then
			walker.walkTrack:AdjustSpeed(speed / (WALK_SPEED_PER_HIP * math.max(walker.hipHeight, 0.5)))
		end
	end

	-- Head: glances, a buddy, looking both ways at the curb, or a target.
	local yawTarget, pitchTarget = 0, 0
	if walker.state == "wait" then
		local crossing = self._life.data.crossings[walker.waitFor]
		if crossing and not crossing.signal then
			yawTarget = math.sin((now - walker.waitSince) * 2.4) * 0.85
		else
			pitchTarget = 0.12 -- watching the signal across the road
		end
	elseif walker.look and walker.state == "pause" then
		local relative = walker.root.CFrame:PointToObjectSpace(walker.look)
		yawTarget = math.clamp(math.atan2(-relative.X, -relative.Z), -1, 1)
		pitchTarget = math.clamp(math.atan2(relative.Y - 1.5, math.max(math.sqrt(relative.X ^ 2 + relative.Z ^ 2), 0.1)), -0.5, 0.3)
	else
		if now >= walker.nextGlance then
			walker.nextGlance = now + self._random:NextNumber(2.5, 6)
			if walker.buddy and self._random:NextNumber() < 0.6 then
				local relative = walker.root.CFrame:PointToObjectSpace(walker.buddy.root.Position)
				walker.glanceYaw = math.clamp(math.atan2(-relative.X, -relative.Z), -0.9, 0.9)
			else
				walker.glanceYaw = self._random:NextNumber(-0.5, 0.5)
			end
			walker.glanceUntil = now + self._random:NextNumber(1, 2)
		end
		if now < (walker.glanceUntil or 0) then
			yawTarget = walker.glanceYaw
		end
	end
	local alpha = math.min(1, dt * 4)
	walker.headYaw += (yawTarget - walker.headYaw) * alpha
	walker.headPitch += (pitchTarget - walker.headPitch) * alpha

	-- Gestures during pauses.
	local rsX, rsZ, reX, lsX, lsZ, leX = 0, 0, 0, 0, 0, 0
	local neckPitch, waistPitch = walker.headPitch, 0
	local gesture = walker.gesture
	if gesture and walker.state == "pause" then
		local duration = math.max(walker.gestureEnd - walker.gestureStart, 0.5)
		local elapsed = now - walker.gestureStart
		local env = math.min(smooth01(elapsed / 0.6), smooth01((duration - elapsed) / 0.6))
		if gesture == "reach" then
			rsX += 1.3 * env
			reX += 0.25 * env
			waistPitch -= 0.12 * env
		elseif gesture == "read" then
			rsX += 0.6 * env
			reX += 1.1 * env
			rsZ -= 0.2 * env
			lsX += 0.6 * env
			leX += 1.1 * env
			lsZ += 0.2 * env
			neckPitch -= 0.35 * env
		elseif gesture == "lookAround" then
			walker.headYaw = math.sin(elapsed * 0.9) * 0.9 * env
		end
	end
	if walker.prop then
		reX += 0.2 -- a little bend holding the bag
	end

	-- Fallback walk cycle, driven by distance so feet keep pace.
	local hipX, kneeR, kneeL, bob = 0, 0, 0, 0
	if walker.procedural then
		local stride = 1.6 * math.max(walker.hipHeight, 0.5)
		walker.stride = (walker.stride + speed * dt / stride * math.pi * 2) % (math.pi * 2)
		local amount = math.clamp(speed / 4, 0, 1)
		local s = math.sin(walker.stride)
		hipX = 0.5 * s * amount
		kneeR = -0.7 * math.max(0, -s) * amount
		kneeL = -0.7 * math.max(0, s) * amount
		rsX -= 0.35 * s * amount
		lsX += 0.35 * s * amount
		bob = math.abs(math.cos(walker.stride)) * 0.08 * amount
	end

	local joints = walker.joints
	local function pose(name: string, offset: CFrame)
		local joint = joints[name]
		if joint then
			joint.motor.C0 = joint.base * offset
		end
	end
	pose("Neck", CFrame.Angles(neckPitch, walker.headYaw * 0.7, 0))
	pose("Waist", CFrame.Angles(waistPitch, walker.headYaw * 0.25, 0))
	pose("RightShoulder", CFrame.Angles(rsX, 0, rsZ))
	pose("LeftShoulder", CFrame.Angles(lsX, 0, lsZ))
	pose("RightElbow", CFrame.Angles(reX, 0, 0))
	pose("LeftElbow", CFrame.Angles(leX, 0, 0))
	if walker.procedural then
		pose("Root", CFrame.new(0, bob, 0))
		pose("RightHip", CFrame.Angles(hipX, 0, 0))
		pose("LeftHip", CFrame.Angles(-hipX, 0, 0))
		pose("RightKnee", CFrame.Angles(kneeR, 0, 0))
		pose("LeftKnee", CFrame.Angles(kneeL, 0, 0))
	end

	-- Footsteps for the walkers close by.
	local spec = self._life.data.sounds.footsteps
	local id = if spec.id ~= "" then spec.id else spec.fallback
	local close = (walker.root.Position - cameraPosition).Magnitude < FOOTSTEP_DISTANCE
	if close and speed > 0.8 and id then
		if not walker.steps then
			local sound = Instance.new("Sound")
			sound.Name = "Footsteps"
			sound.SoundId = id
			sound.Looped = true
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 4
			sound.RollOffMaxDistance = FOOTSTEP_DISTANCE + 4
			local equalizer = Instance.new("EqualizerSoundEffect")
			equalizer.HighGain, equalizer.MidGain, equalizer.LowGain = -6, -1, 0
			equalizer.Parent = sound
			CollectionService:AddTag(sound, World.Tags.AmbientSound)
			sound.Parent = walker.root
			walker.steps = sound
		end
		walker.steps.Volume = spec.volume * math.clamp(speed / 5, 0.4, 1) * walker.fade
		walker.steps.PlaybackSpeed = math.clamp(speed / 9, 0.45, 0.85)
		if not walker.steps.IsPlaying then
			walker.steps:Play()
		end
	elseif walker.steps and walker.steps.IsPlaying then
		walker.steps:Stop()
	end
end

function Pedestrians:_updateDog(walker, dt: number)
	local dog = walker.dog
	local path = walker.route.path
	local distance = math.clamp(walker.distance - walker.direction * DOG_BEHIND, 0, path.length)
	local position, tangent = Paths.sample(path, distance)
	local travel = tangent * walker.direction
	local right = Vector3.new(-travel.Z, 0, travel.X)
	local ground = position + right * (walker.lateral - DOG_SIDE)
	local moving = walker.speed > 0.3
	local desired = if moving then yawOf(travel) else yawOf(walker.position - ground)
	dog.yaw = wrap(dog.yaw + math.clamp(wrap(desired - dog.yaw) * math.min(1, dt * 5), -5 * dt, 5 * dt))
	local rootFrame = CFrame.new(ground) * CFrame.Angles(0, dog.yaw, 0)

	dog.phase = (dog.phase + walker.speed * dt / 0.55 * math.pi) % (math.pi * 2)
	local swing = math.sin(dog.phase) * 0.55 * math.clamp(walker.speed / 3, 0, 1)
	local wagSpeed = if moving then 7 else 13
	dog.wag = (dog.wag + dt * wagSpeed) % (math.pi * 2)
	dog.sniff += ((if moving then 0 else 1) - dog.sniff) * math.min(1, dt * 1.5)
	local now = os.clock()
	local headPitch = -dog.sniff * (0.3 + math.sin(now * 3) * 0.08)
	local legSwing = { LegFL = swing, LegBR = swing, LegFR = -swing, LegBL = -swing }
	for i, part in dog.parts do
		local kind = dog.kinds[i]
		local pivot = dog.pivots[i]
		local rotation = CFrame.new()
		if kind == "tail" then
			rotation = CFrame.Angles(0, math.sin(dog.wag) * 0.45, 0)
		elseif kind == "head" then
			rotation = CFrame.Angles(headPitch, 0, 0)
		elseif legSwing[kind] then
			rotation = CFrame.Angles(legSwing[kind], 0, 0)
		end
		dog.cframes[i] = rootFrame * pivot * rotation * dog.offsets[i]
	end
	workspace:BulkMoveTo(dog.parts, dog.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

---------------------------------------------------------------------------
-- Avoidance and spawning
---------------------------------------------------------------------------

function Pedestrians:_avoid(playerPosition: Vector3?)
	for _, walker in self._walkers do
		local avoid, slow = 0, 1
		if walker.state == "walk" then
			local function consider(other: Vector3)
				local relative = Vector3.new(other.X - walker.position.X, 0, other.Z - walker.position.Z)
				local ahead = relative:Dot(walker.travel)
				local side = relative:Dot(walker.right) - 0
				if ahead > 0.3 and ahead < 6 and math.abs(side) < 2 then
					-- Step to the right, unless they're already on that side.
					avoid = if side > 0.4 then -1.3 else 1.3
					if ahead < 2.4 and math.abs(side) < 1.3 then
						slow = math.min(slow, math.clamp((ahead - 1.0) / 1.4, 0, 1))
					end
				end
			end
			if playerPosition then
				consider(playerPosition)
			end
			for _, other in self._walkers do
				if other ~= walker and other ~= walker.buddy and other.fade > 0.3 then
					consider(other.position)
				end
			end
		end
		walker.avoid = avoid
		walker.slow = slow
	end
end

function Pedestrians:_activeWindow(route): (boolean, boolean)
	local windows = route.schedule
	if not windows then
		return true, false
	end
	local minutes = self._life:gameMinutes()
	if not minutes then
		local first = windows[1]
		return true, first.reverse
	end
	for _, window in windows do
		local afterStart = window.from == nil or minutes >= window.from
		local beforeEnd = window.upTo == nil or minutes < window.upTo
		if afterStart and beforeEnd then
			return true, window.reverse
		end
	end
	return false, false
end

function Pedestrians:_spawnOneWay(route, now: number)
	local spec = route.spec
	local limits = self._life.data.limits
	if now < route.nextSpawn then
		return
	end
	route.nextSpawn = now + 1.5
	local active, reverse = self:_activeWindow(route)
	if not active or #route.walkers >= (spec.maxWalkers or 1) or #self._walkers >= limits.walkers then
		return
	end
	local start = if reverse then route.path.length else 0
	local direction = if reverse then -1 else 1
	local startPosition = Paths.sample(route.path, start)
	if not Paths.isHidden(startPosition, limits.spawnClearance) then
		return
	end
	for _, other in route.walkers do
		if math.abs(other.distance - start) < 5 then
			return
		end
	end
	local group = spec.group or { 1, 1 }
	local size = math.min(self._random:NextInteger(group[1], group[2]), (spec.maxWalkers or 1) - #route.walkers, limits.walkers - #self._walkers)
	local first = self:_spawn(route, start, direction, false, nil, if size > 1 then -0.75 else 0)
	if first and size > 1 then
		self:_spawn(route, start, direction, false, first, 0.75)
	end
	route.nextSpawn = now + self._random:NextNumber(spec.spawnEvery[1], spec.spawnEvery[2])
end

function Pedestrians:update(dt: number, cameraPosition: Vector3)
	if not self._ready then
		return
	end
	local now = os.clock()
	if self._enabled then
		for _, route in self._routes do
			if route.spec.mode == "oneway" then
				self:_spawnOneWay(route, now)
			end
		end
	end

	self._sinceAvoid += dt
	if self._sinceAvoid >= AVOID_INTERVAL then
		self._sinceAvoid = 0
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		self:_avoid(root and root.Position)
	end

	local detail = self._life.data.limits.detailDistance
	table.clear(self.positions)
	for _, walker in table.clone(self._walkers) do
		-- Fade in after appearing; fade out when leaving.
		local fadeTarget = if walker.leaving then 0 else 1
		if walker.fade ~= fadeTarget then
			walker.fade = math.clamp(walker.fade + (if fadeTarget > walker.fade then 1 else -1) * dt / FADE_SECONDS, 0, 1)
			for _, part in walker.fadeParts do
				part.LocalTransparencyModifier = 1 - walker.fade
			end
			if walker.leaving and walker.fade <= 0 then
				self:_release(walker)
				continue
			end
		end

		local near = (walker.root.Position - cameraPosition).Magnitude < detail
		walker.sinceUpdate += dt
		if near or walker.sinceUpdate >= FAR_UPDATE then
			local step = walker.sinceUpdate
			walker.sinceUpdate = 0
			self:_move(walker, step, now)
			if walker.dog then
				self:_updateDog(walker, step)
			end
			if near then
				self:_animate(walker, step, now, cameraPosition)
			elseif walker.tracksPlaying then
				self:_stopTracks(walker)
				if walker.steps then
					walker.steps:Stop()
				end
			end
		end
		if walker.fade > 0.5 then
			table.insert(self.positions, walker.position)
		end
	end
end

return Pedestrians
