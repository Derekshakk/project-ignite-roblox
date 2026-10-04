--[[
	Traffic

	A few cars driving along the lane paths in Data/Ambient. Deliberately
	simple — no traffic AI, just polite drivers on rails:
	- cars cruise at a residential speed, ease into rounded corners, keep a
	  following gap, and accelerate/brake smoothly (the body dips a little
	  under braking and the brake lights come on)
	- they stop for a crosswalk while its signal shows "walk", for anyone
	  in or waiting at an unsignalled crosswalk, and for anyone (the
	  player included) standing in their lane ahead — so a car never drives
	  through a person
	- new cars appear at the off-map start of a route only while that spot
	  is out of sight, fade in, and are recycled (pooled) at the off-map end
	- wheels spin with the distance travelled; engine and road sounds
	  follow speed, with a slight doppler shift as a car passes

	Cars are local to this client, anchored, and never collide or block
	raycasts. All parts of a car are moved together with one BulkMoveTo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Paths = require(script.Parent.Paths)

local COMFORT_DECEL = 7 -- studs/s², planned stops
local HARD_DECEL = 16 -- studs/s², the most a car will brake
local ACCEL = 5
local MIN_GAP = 6 -- bumper to bumper while queued
local STOP_LINE = 1.4 -- studs before a crosswalk
local FADE_SECONDS = 0.8
local FAR_UPDATE = 1 / 6
local SOUND_DISTANCE = 140
local SOUND_SPEED = 260 -- studs/s, for the doppler shift (exaggerated a little)
local STYLE_WEIGHTS = { sedan = 4, hatchback = 3, suv = 3, van = 1 }
local BRAKE_ON = Color3.fromRGB(255, 70, 60)
local BRAKE_OFF = Color3.fromRGB(150, 36, 36)

local Traffic = {}
Traffic.__index = Traffic

function Traffic.new(life)
	return setmetatable({
		_life = life,
		_random = Random.new(),
		_routes = {} :: { any },
		_cars = {} :: { any },
		_pool = {} :: { [string]: { any } },
		_enabled = true,
		_ready = false,
	}, Traffic)
end

function Traffic:start(templates: Instance)
	local data = self._life.data
	self._templates = templates:WaitForChild("Cars", 20)
	if not self._templates then
		warn("[Traffic] No car templates; traffic disabled.")
		return
	end
	for _, spec in data.traffic do
		local path = Paths.build(spec.points, spec.corners)
		local route = {
			spec = spec,
			path = path,
			crossings = {},
			cars = {} :: { any },
			nextSpawn = os.clock() + self._random:NextNumber(1, spec.spawnEvery[1]),
		}
		-- Where this route enters and leaves each crosswalk.
		for id, crossing in data.crossings do
			local entry, exit = nil, nil
			for distance = 0, path.length, 0.5 do
				local position = Paths.sample(path, distance)
				local inside = position.X >= crossing.min.X and position.X <= crossing.max.X and position.Z >= crossing.min.Y and position.Z <= crossing.max.Y
				if inside then
					entry = entry or distance
					exit = distance
				end
			end
			if entry then
				table.insert(route.crossings, { id = id, data = crossing, entry = entry, exit = exit })
			end
		end
		table.insert(self._routes, route)
	end
	self._ready = true
	-- A couple of cars already on the road, wherever they can't be seen
	-- appearing.
	for _, route in self._routes do
		for _ = 1, 2 do
			local distance = self._random:NextNumber(0.1, 0.8) * route.path.length
			local position = Paths.sample(route.path, distance)
			if Paths.isHidden(position, self._life.data.limits.spawnClearance) and self:_clearAt(route, distance, 20) then
				self:_spawn(route, distance, true)
			end
		end
	end
end

function Traffic:setEnabled(enabled: boolean)
	self._enabled = enabled
	if not enabled then
		for _, car in table.clone(self._cars) do
			self:_release(car)
		end
	end
end

---------------------------------------------------------------------------
-- Cars
---------------------------------------------------------------------------

local function pickStyle(random: Random): string
	local total = 0
	for _, weight in STYLE_WEIGHTS do
		total += weight
	end
	local roll = random:NextNumber(0, total)
	for style, weight in STYLE_WEIGHTS do
		roll -= weight
		if roll <= 0 then
			return style
		end
	end
	return "sedan"
end

local function newSound(parent: Instance, spec, name: string): Sound?
	local id = if spec.id ~= "" then spec.id else spec.fallback
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = SOUND_DISTANCE
	CollectionService:AddTag(sound, World.Tags.AmbientSound)
	sound.Parent = parent
	return sound
end

-- Builds the per-car bookkeeping for a fresh clone (template at identity).
function Traffic:_prepare(model: Model, style: string)
	local root = model.PrimaryPart :: BasePart
	local car = {
		model = model,
		style = style,
		root = root,
		parts = {} :: { BasePart },
		offsets = {} :: { CFrame },
		wheelOf = {} :: { number },
		wheels = {} :: { { center: CFrame, radius: number } },
		brakes = {} :: { BasePart },
		paint = {} :: { BasePart },
		cframes = {} :: { CFrame },
	}
	local wheelIndex: { [Instance]: number } = {}
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child.Name == "Wheel" then
			table.insert(car.wheels, {
				center = child:GetAttribute("WheelCenter") or CFrame.new(),
				radius = child:GetAttribute("WheelRadius") or 0.85,
			})
			wheelIndex[child] = #car.wheels
		end
	end
	local minZ, maxZ, maxX = 0, 0, 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local offset = root.CFrame:ToObjectSpace(part.CFrame)
			local wheel = wheelIndex[part.Parent :: Instance] or 0
			if wheel > 0 then
				-- Wheel parts are stored relative to their wheel's centre.
				offset = car.wheels[wheel].center:Inverse() * offset
			end
			table.insert(car.parts, part)
			table.insert(car.offsets, offset)
			table.insert(car.wheelOf, wheel)
			table.insert(car.cframes, part.CFrame)
			if part:GetAttribute("Brake") then
				table.insert(car.brakes, part)
			end
			if part:GetAttribute("Paint") then
				table.insert(car.paint, part)
			end
			if part ~= root then
				local z = part.Position.Z
				minZ, maxZ = math.min(minZ, z - part.Size.Z / 2), math.max(maxZ, z + part.Size.Z / 2)
				maxX = math.max(maxX, math.abs(part.Position.X) + part.Size.X / 2)
			end
		end
	end
	car.halfLength = (maxZ - minZ) / 2
	car.halfWidth = maxX
	car.wheelbase = 0
	for _, wheel in car.wheels do
		car.wheelbase = math.max(car.wheelbase, math.abs(wheel.center.Z) * 2)
	end
	local sounds = self._life.data.sounds
	car.engine = newSound(root, sounds.engine, "Engine")
	car.road = newSound(root, sounds.road, "Road")
	return car
end

function Traffic:_take(style: string)
	local pool = self._pool[style]
	if pool and #pool > 0 then
		return table.remove(pool)
	end
	local template = self._templates:FindFirstChild(style) or self._templates:FindFirstChildWhichIsA("Model")
	if not template then
		return nil
	end
	local model = (template :: Model):Clone()
	model:PivotTo(CFrame.new())
	return self:_prepare(model, style)
end

function Traffic:_clearAt(route, distance: number, gap: number): boolean
	for _, other in route.cars do
		if math.abs(other.distance - distance) < gap + other.halfLength then
			return false
		end
	end
	return true
end

function Traffic:_spawn(route, distance: number, instant: boolean?)
	local car = self:_take(pickStyle(self._random))
	if not car then
		return
	end
	local colors = self._life.data.carColors
	local color = colors[self._random:NextInteger(1, #colors)]
	for _, part in car.paint do
		part.Color = color
	end
	car.route = route
	car.distance = distance
	car.cruise = route.spec.speed * self._random:NextNumber(0.9, 1.1)
	car.speed = if instant then car.cruise else car.cruise * 0.8
	car.accel = 0
	car.pitch = 0
	car.roll = 0
	car.lastYaw = nil
	car.wheelAngle = 0
	car.fade = if instant then 1 else 0
	car.leaving = false
	car.braking = nil
	car.sinceUpdate = 0
	car.doppler = 1
	car.yieldingTo = {} :: { [string]: boolean }
	for _, part in car.parts do
		part.LocalTransparencyModifier = 1 - car.fade
	end
	car.model.Parent = self._life.worldFolder
	table.insert(route.cars, car)
	table.insert(self._cars, car)
	self:_place(car, 0)
end

function Traffic:_release(car)
	local route = car.route
	local index = table.find(route.cars, car)
	if index then
		table.remove(route.cars, index)
	end
	index = table.find(self._cars, car)
	if index then
		table.remove(self._cars, index)
	end
	for _, sound in { car.engine, car.road } do
		if sound then
			sound:Stop()
		end
	end
	car.model.Parent = nil
	self._pool[car.style] = self._pool[car.style] or {}
	table.insert(self._pool[car.style], car)
end

---------------------------------------------------------------------------
-- Driving
---------------------------------------------------------------------------

local function inside(position: Vector3, crossing, alongMargin: number, acrossMargin: number): boolean
	local marginX = if crossing.axis == "x" then alongMargin else acrossMargin
	local marginZ = if crossing.axis == "z" then alongMargin else acrossMargin
	return position.X >= crossing.min.X - marginX
		and position.X <= crossing.max.X + marginX
		and position.Z >= crossing.min.Y - marginZ
		and position.Z <= crossing.max.Y + marginZ
end

--[[
	Why a crosswalk is blocked right now: "person" (someone in the road,
	or waiting at an unsignalled crossing), "signal" (walk light on), or
	nil.
]]
function Traffic:_blocked(crossing): string?
	for _, position in self._life.people do
		if inside(position, crossing, 0, 0.6) then
			return "person"
		end
		if not crossing.signal and inside(position, crossing, 2.6, 0.6) then
			return "person"
		end
	end
	if crossing.signal and self._life.crosswalks:isWalking(crossing.signal) then
		return "signal"
	end
	return nil
end

-- True when no car is about to pass through crosswalk `id` without
-- yielding (pedestrians check this before stepping off the curb).
function Traffic:isSafeToCross(id: string): boolean
	for _, car in self._cars do
		for _, crossing in car.route.crossings do
			if crossing.id == id then
				local front = car.distance + car.halfLength
				local rear = car.distance - car.halfLength
				local onIt = front >= crossing.entry and rear <= crossing.exit + 0.5
				local approaching = front < crossing.entry and front > crossing.entry - 45 and car.speed > 1.5
				if onIt or (approaching and not car.yieldingTo[id]) then
					return false
				end
			end
		end
	end
	return true
end

-- The path distance at which this car's front bumper must stop, if any.
function Traffic:_stopPoint(car): number?
	local route = car.route
	local front = car.distance + car.halfLength
	local stopAt: number? = nil
	table.clear(car.yieldingTo)
	for _, crossing in route.crossings do
		if front < crossing.entry + 0.3 then
			local reason = self:_blocked(crossing.data)
			if reason then
				local line = crossing.entry - STOP_LINE
				local gap = line - front
				local canStop = car.speed * car.speed <= 2 * HARD_DECEL * math.max(gap, 0.05)
				if gap > -0.6 and (canStop or reason == "person") then
					stopAt = math.min(stopAt or math.huge, line)
					car.yieldingTo[crossing.id] = true
				end
			end
		end
	end
	-- Anyone standing in the lane ahead.
	local lookahead = car.speed * car.speed / (2 * COMFORT_DECEL) + 8
	local rootPosition = car.root.Position
	local heading = car.root.CFrame.LookVector
	for _, position in self._life.people do
		local flat = Vector3.new(position.X - rootPosition.X, 0, position.Z - rootPosition.Z)
		local ahead = flat:Dot(heading)
		if ahead > 0 and flat.Magnitude < lookahead + car.halfLength + 4 then
			for distance = front, front + lookahead, 2 do
				local point = Paths.sample(route.path, distance)
				if Vector3.new(point.X - position.X, 0, point.Z - position.Z).Magnitude < car.halfWidth + 1.3 then
					stopAt = math.min(stopAt or math.huge, distance - 2.5)
					break
				end
			end
		end
	end
	return stopAt
end

function Traffic:_targetSpeed(car): number
	local route = car.route
	local spec = route.spec
	local front = car.distance + car.halfLength
	local target = car.cruise
	-- Ease into rounded corners.
	for _, curve in route.path.curves do
		if curve.to > car.distance - car.halfLength then
			local gap = curve.from - front
			if gap <= 0 then
				target = math.min(target, spec.turnSpeed)
			else
				target = math.min(target, math.sqrt(spec.turnSpeed ^ 2 + 2 * COMFORT_DECEL * gap))
			end
		end
	end
	-- Keep a gap to the car ahead.
	for _, other in route.cars do
		if other ~= car and other.distance > car.distance then
			local gap = (other.distance - other.halfLength) - front - MIN_GAP
			target = math.min(target, other.speed + math.sqrt(2 * COMFORT_DECEL * math.max(gap, 0)) * (if gap > 0 then 1 else 0))
		end
	end
	local stopAt = self:_stopPoint(car)
	if stopAt then
		local gap = stopAt - front
		target = math.min(target, if gap <= 0 then 0 else math.sqrt(2 * COMFORT_DECEL * gap))
	end
	return math.max(target, 0)
end

-- Moves the car's parts to its place on the path.
function Traffic:_place(car, dt: number)
	local path = car.route.path
	local half = math.max(car.wheelbase / 2, 1)
	local rear = Paths.sample(path, car.distance - half)
	local front = Paths.sample(path, car.distance + half)
	local heading = Vector3.new(front.X - rear.X, 0, front.Z - rear.Z)
	if heading.Magnitude < 1e-3 then
		local _, direction = Paths.sample(path, car.distance)
		heading = direction
	end
	heading = heading.Unit
	local position = (rear + front) / 2
	local rootFrame = CFrame.lookAt(position, position + heading)

	-- Body motion: nose dips when braking, lifts a touch when pulling
	-- away, and leans slightly out of turns.
	local yaw = math.atan2(-heading.X, -heading.Z)
	if dt > 0 then
		local yawRate = 0
		if car.lastYaw then
			local delta = (yaw - car.lastYaw + math.pi) % (2 * math.pi) - math.pi
			yawRate = delta / dt
		end
		local alpha = math.min(1, dt * 4)
		car.pitch += (math.clamp(car.accel * 0.004, -0.035, 0.02) - car.pitch) * alpha
		car.roll += (math.clamp(yawRate * car.speed * 0.0025, -0.03, 0.03) - car.roll) * alpha
		car.wheelAngle = (car.wheelAngle + car.speed * dt / 0.85) % (math.pi * 2)
	end
	car.lastYaw = yaw
	local body = rootFrame * CFrame.Angles(car.pitch, 0, car.roll)

	local parts, offsets, wheelOf, cframes = car.parts, car.offsets, car.wheelOf, car.cframes
	local spins = {}
	for i, wheel in car.wheels do
		spins[i] = rootFrame * wheel.center * CFrame.Angles(-car.wheelAngle * 0.85 / wheel.radius, 0, 0)
	end
	for i = 1, #parts do
		local wheel = wheelOf[i]
		cframes[i] = if wheel > 0 then spins[wheel] * offsets[i] else body * offsets[i]
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function Traffic:_updateSound(car, cameraPosition: Vector3, heading: Vector3, dt: number)
	local distance = (car.root.Position - cameraPosition).Magnitude
	local audible = distance < SOUND_DISTANCE and car.fade > 0
	local ratio = math.clamp(car.speed / car.cruise, 0, 1.2)
	-- Doppler: pitch rises while approaching, falls once past.
	local toListener = cameraPosition - car.root.Position
	local approach = if toListener.Magnitude > 0.1 then (heading * car.speed):Dot(toListener.Unit) else 0
	local target = 1 / (1 - math.clamp(approach / SOUND_SPEED, -0.3, 0.3))
	car.doppler += (target - car.doppler) * math.min(1, dt * 3)
	local sounds = self._life.data.sounds
	for _, entry in { { car.engine, sounds.engine, 0.35 }, { car.road, sounds.road, 0.05 } } do
		local sound, spec, idle = entry[1], entry[2], entry[3]
		if sound then
			if audible then
				if not sound.IsPlaying then
					sound.TimePosition = self._random:NextNumber(0, 2)
					sound:Play()
				end
				sound.Volume = spec.volume * (idle + (1 - idle) * ratio) * car.fade
				sound.PlaybackSpeed = (spec.speed or 1) * (0.8 + 0.35 * ratio) * car.doppler
			elseif sound.IsPlaying then
				sound:Stop()
			end
		end
	end
end

function Traffic:_updateBrakes(car)
	local braking = car.accel < -1.5 or car.speed < 0.5
	if braking ~= car.braking then
		car.braking = braking
		for _, part in car.brakes do
			part.Color = if braking then BRAKE_ON else BRAKE_OFF
			part.Material = if braking then Enum.Material.Neon else Enum.Material.Glass
		end
	end
end

function Traffic:update(dt: number)
	if not self._ready then
		return
	end
	local now = os.clock()
	local limits = self._life.data.limits
	if self._enabled then
		for _, route in self._routes do
			if now >= route.nextSpawn then
				local start = route.path.points[1]
				if
					#route.cars < route.spec.maxCars
					and #self._cars < limits.cars
					and self:_clearAt(route, 0, 16)
					and Paths.isHidden(start, limits.spawnClearance)
				then
					self:_spawn(route, 0)
					route.nextSpawn = now + self._random:NextNumber(route.spec.spawnEvery[1], route.spec.spawnEvery[2])
				else
					route.nextSpawn = now + 1.5
				end
			end
		end
	end

	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for _, car in table.clone(self._cars) do
		-- Speed: ease toward the target, braking harder only when needed.
		local target = self:_targetSpeed(car)
		local before = car.speed
		if car.speed < target then
			car.speed = math.min(target, car.speed + ACCEL * dt)
		else
			car.speed = math.max(target, car.speed - HARD_DECEL * dt)
		end
		car.accel += ((car.speed - before) / math.max(dt, 1e-3) - car.accel) * math.min(1, dt * 5)
		car.distance += car.speed * dt

		-- Fade in after spawning, out at the end of the route.
		if car.distance + car.halfLength >= car.route.path.length - 1 then
			car.leaving = true
		end
		local fadeTarget = if car.leaving then 0 else 1
		if car.fade ~= fadeTarget then
			car.fade = math.clamp(car.fade + (if fadeTarget > car.fade then 1 else -1) * dt / FADE_SECONDS, 0, 1)
			for _, part in car.parts do
				part.LocalTransparencyModifier = 1 - car.fade
			end
			if car.leaving and car.fade <= 0 then
				self:_release(car)
				continue
			end
		end

		-- Far away: move a few times a second.
		local distance = (car.root.Position - cameraPosition).Magnitude
		car.sinceUpdate += dt
		if distance < limits.detailDistance * 1.6 or car.sinceUpdate >= FAR_UPDATE then
			self:_place(car, car.sinceUpdate)
			car.sinceUpdate = 0
		end
		local heading = car.root.CFrame.LookVector
		self:_updateSound(car, cameraPosition, heading, dt)
		self:_updateBrakes(car)
	end
end

return Traffic
