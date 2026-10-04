--[[
	NpcAnimator

	Reusable, lightweight animation for every NPC tagged IgniteNpc (any R15
	rig). Works without custom animation assets:

	- Base layer: Roblox's default R15 idle animation, if it loads (it's a
	  Roblox-owned animation usable in any experience). Each NPC starts it
	  at a random point and speed so nobody moves in sync.
	- Procedural layer on the joints (Motor6D C0, so it stacks on top of any
	  animation): breathing, weight shifts, head turns, talking gestures and
	  reactions. Every NPC has its own seed, phase and tempo.
	- Body turning: the (anchored) root part is rotated around its starting
	  facing, so an NPC can turn to face the player and back again.

	Background neighbours can have an Activity (attribute, set by
	Npc.spawn) layered on top: "water" (watering can, pouring in spells),
	"sweep" (broom strokes with pauses), "garden" (crouching to dig, then
	standing to stretch), "sit" / "sit_mug" (now and then a sip) /
	"sit_phone", and "phone" (standing). Each cycles between a working and
	a resting phase on its own timer, so nobody moves in sync. The arm work
	fades out while the NPC is greeting or talking to the player; seated
	NPCs stay seated. Sitting and crouching use the rig's measured leg
	proportions (HipJointHeight, ThighLength) so seats and feet line up.

	Behaviour, from highest priority:
		attention   startDialogue(npc) .. endDialogue(npc): body and head
		            turn toward the player (counted, so overlapping scenes
		            end cleanly)
		reaction    react(npc, kind, options): "nod", "wave", "point",
		            "shrug", "lookAt" (head toward a target for a while) or
		            "chat" (turn to the nearest neighbour and talk for a while)
		talking     setTalking(npc, true/false), driven by speech bubbles;
		            talkative NPCs also chat silently with neighbours
		listening   NPCs look toward whoever is talking near them (across
		            the room when someone is addressing the player)
		idle        breathing, glances, weight shifts, and now and then a
		            turn toward a neighbour

	`npc` is an NpcId (e.g. "teacher") or the NPC model.
	Only NPCs near the camera are updated, at ~30 Hz, to keep it cheap.
	Block-figure fallback NPCs have no joints and stay still.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local NpcRegistry = require(script.Parent.NpcRegistry)

-- Roblox-owned default R15 animations (the same ones the default Animate
-- script uses). PLACEHOLDERS: swap in custom animations later. If one
-- fails to load, the procedural layer covers it.
local IDLE_ANIMATION_ID = "rbxassetid://507766666"
local WAVE_ANIMATION_ID = "rbxassetid://507770239"

local UPDATE_INTERVAL = 1 / 30
local MAX_DISTANCE = 90
local JOINT_NAMES = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"LeftShoulder",
	"RightElbow",
	"LeftElbow",
	"RightWrist",
	"LeftWrist",
	"RightHip",
	"LeftHip",
	"RightKnee",
	"LeftKnee",
}
local SEATED = { sit = true, sit_mug = true, sit_phone = true }
-- Seconds in each phase of an activity's loop: "work" and "rest" (for
-- sit_mug, rest is a sip; for the phones, a glance up).
local CYCLES = {
	water = { work = { 5, 7 }, rest = { 3, 5 } },
	sweep = { work = { 7, 11 }, rest = { 2, 3 } },
	garden = { work = { 10, 16 }, rest = { 3, 5 } },
	sit = { work = { 8, 14 }, rest = { 2, 3 } },
	sit_mug = { work = { 8, 14 }, rest = { 2.2, 2.8 } },
	sit_phone = { work = { 6, 12 }, rest = { 1.5, 2.5 } },
	phone = { work = { 6, 12 }, rest = { 1.5, 2.5 } },
}
-- Crouch for gardening: hip and knee bend (radians).
local CROUCH_HIP, CROUCH_KNEE = 0.6, 1.1
local SIT_BEND = 1.45
local THIGH_HALF_THICKNESS = 0.42
local MAX_HEAD_YAW = math.rad(65)
local MAX_PITCH = math.rad(20)
-- How far the whole body may turn away from its starting facing.
local MAX_BODY_TURN = math.rad(150)
local IDLE_BODY_TURN = math.rad(35)
local BODY_TURN_SPEED = 2.5
local NEIGHBOUR_RADIUS = 9
-- How far a voice draws listeners' attention: someone addressing the
-- player (a teacher) is heard across the room; a chat stays in its group.
local ADDRESS_RADIUS = 22
local CHAT_RADIUS = 6

local REACTION_SECONDS = table.freeze({
	nod = 1.2,
	shrug = 1.4,
	wave = 2.2,
	point = 1.8,
	lookAt = 2.5,
	chat = 10,
})

local NpcAnimator = {}
NpcAnimator.__index = NpcAnimator

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 → 1 → 0 over `duration`, with eased edges.
local function envelope(elapsed: number, duration: number, fadeIn: number, fadeOut: number): number
	if elapsed < 0 or elapsed > duration then
		return 0
	end
	return math.min(smooth01(elapsed / fadeIn), smooth01((duration - elapsed) / fadeOut))
end

-- Yaw that turns `frame` toward `point` on the horizontal plane.
local function yawTo(frame: CFrame, point: Vector3): number
	local relative = frame:PointToObjectSpace(point)
	return math.atan2(-relative.X, -relative.Z)
end

local function playerHeadPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return head and head.Position
end

-- A look target can be "player", a model, or a position.
local function resolvePoint(target: any): Vector3?
	if target == "player" then
		return playerHeadPosition()
	elseif typeof(target) == "Vector3" then
		return target
	elseif typeof(target) == "Instance" and target:IsA("Model") and target.Parent then
		return NpcRegistry.getHeadPosition(target)
	end
	return nil
end

function NpcAnimator.new()
	return setmetatable({
		_rigs = {} :: { [Model]: any },
		-- attention/talking are keyed by whatever the caller used (NpcId or
		-- model), so calls made before an NPC has loaded still apply.
		_attention = {} :: { [any]: number },
		_talking = {} :: { [any]: boolean },
		_since = 0,
	}, NpcAnimator)
end

function NpcAnimator:start()
	NpcRegistry.start()
	local function add(model: Model)
		task.spawn(function()
			self:_add(model)
		end)
	end
	for _, model in NpcRegistry.all() do
		add(model)
	end
	NpcRegistry.Added:Connect(add)
	NpcRegistry.Removed:Connect(function(model)
		self._rigs[model] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self._since += deltaTime
		if self._since >= UPDATE_INTERVAL then
			local dt = self._since
			self._since = 0
			self:_update(dt)
		end
	end)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- Turns toward the player until endDialogue. Calls are counted.
function NpcAnimator:startDialogue(npc: string | Model)
	self._attention[npc] = (self._attention[npc] or 0) + 1
end

function NpcAnimator:endDialogue(npc: string | Model)
	local count = (self._attention[npc] or 0) - 1
	self._attention[npc] = if count > 0 then count else nil
end

function NpcAnimator:isInDialogue(npc: string | Model): boolean
	return self._attention[npc] ~= nil
end

-- Talking animation on/off (speech bubbles call this).
function NpcAnimator:setTalking(npc: string | Model, talking: boolean)
	self._talking[npc] = if talking then true else nil
end

-- Clears every conversation (death/respawn/new run). NPCs ease back to idle.
function NpcAnimator:resetDialogue()
	table.clear(self._attention)
	table.clear(self._talking)
	for _, rig in self._rigs do
		self:_stopReaction(rig)
		rig.chatUntil = 0
	end
end

--[[
	Plays a short reaction. options:
		target: "player" | Model | Vector3 | nil   where to look/point
		seconds: number?                          duration override
	Returns false if the NPC isn't loaded (or can't animate).
]]
function NpcAnimator:react(npc: string | Model, kind: string, options: { [string]: any }?): boolean
	local model = NpcRegistry.get(npc)
	local rig = model and self._rigs[model]
	local duration = REACTION_SECONDS[kind]
	if not rig or not duration then
		return false
	end
	options = options or {}
	duration = options.seconds or duration
	local now = os.clock()

	if kind == "lookAt" then
		rig.lookTarget = options.target
		rig.lookUntil = now + duration
		return true
	elseif kind == "chat" then
		rig.chatWith = NpcRegistry.nearestTo(rig.model, NEIGHBOUR_RADIUS)
		rig.chatUntil = now + duration
		-- Stagger who starts talking first.
		rig.chatTalking = rig.random:NextNumber() < 0.5
		rig.nextChatToggle = now + rig.random:NextNumber(0.2, 1.4)
		return true
	end

	self:_stopReaction(rig)
	local reaction = { kind = kind, start = now, duration = duration, target = options.target, track = nil }
	if kind == "wave" and rig.waveTrack and rig.waveTrack.Length > 0 then
		reaction.track = rig.waveTrack
		rig.waveTrack:Play(0.25)
	end
	rig.reaction = reaction
	return true
end

-- Plays a reaction on every NPC within `radius` studs of `position`.
function NpcAnimator:reactNear(position: Vector3, radius: number, kind: string, options: { [string]: any }?, exclude: Model?)
	for model, rig in self._rigs do
		if model ~= exclude and (rig.root.Position - position).Magnitude <= radius then
			self:react(model, kind, options)
		end
	end
end

---------------------------------------------------------------------------
-- Rigs
---------------------------------------------------------------------------

function NpcAnimator:_add(model: Model, attempt: number?)
	if self._rigs[model] or not model.Parent then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = NpcRegistry.getRoot(model)
	if not humanoid or not root then
		return -- block figure: nothing to animate
	end

	local joints = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and table.find(JOINT_NAMES, descendant.Name) then
			joints[descendant.Name] = { motor = descendant, base = descendant.C0 }
		end
	end
	if not joints.Neck or not joints.Waist then
		-- Parts may still be streaming in; try again a few times.
		if (attempt or 1) < 5 then
			task.delay(1, function()
				self:_add(model, (attempt or 1) + 1)
			end)
		end
		return
	end

	local seed = model:GetAttribute("AnimationSeed") or 1
	local random = Random.new(seed * 7919 + 13)
	local now = os.clock()
	local rig = {
		model = model,
		root = root,
		joints = joints,
		npcId = NpcRegistry.getNpcId(model),
		talkative = model:GetAttribute(World.Attributes.Talkative) == true,
		random = random,
		phase = random:NextNumber(0, math.pi * 2),
		tempo = random:NextNumber(0.85, 1.15),
		home = root.CFrame,
		bodyYaw = 0,
		appliedBodyYaw = 0,
		idleTurn = 0,
		nextIdleTurn = now + random:NextNumber(6, 18),
		yaw = 0,
		pitch = 0,
		targetYaw = 0,
		targetPitch = 0,
		hadLook = false,
		nextGlance = now + random:NextNumber(1, 5),
		shift = 0,
		shiftTarget = 0,
		nextShift = now + random:NextNumber(1, 6),
		talkBlend = 0,
		wasTalking = false,
		gestureHand = 1,
		silentUntil = 0,
		nextSilentChat = now + random:NextNumber(1, 8),
		chatWith = nil :: Model?,
		chatUntil = 0,
		chatTalking = false,
		nextChatToggle = 0,
		lookTarget = nil :: any,
		lookUntil = 0,
		partner = nil :: Model?,
		partnerCheckedAt = 0,
		reaction = nil :: any,
		waveTrack = nil :: AnimationTrack?,
		nextNod = now + random:NextNumber(2, 6),
		lastBodyYaw = 0,
		stepBlend = 0,
		activity = nil :: string?,
	}
	local activity = model:GetAttribute(World.Attributes.Activity)
	if type(activity) == "string" and CYCLES[activity] then
		local hipHeight = model:GetAttribute(World.Attributes.HipJointHeight)
		local thigh = model:GetAttribute(World.Attributes.ThighLength)
		local seatHeight = model:GetAttribute(World.Attributes.SeatHeight)
		rig.activity = activity
		rig.seated = SEATED[activity] == true
		rig.taskBlend = 0
		rig.workBlend = 1
		rig.working = true
		rig.phaseUntil = now + random:NextNumber(1, CYCLES[activity].work[2])
		rig.seatDrop = 0
		rig.crouchDrop = 0.3
		if type(hipHeight) == "number" then
			if type(seatHeight) == "number" then
				rig.seatDrop = math.clamp(hipHeight - (seatHeight + THIGH_HALF_THICKNESS), -0.6, 1.5)
			end
			if type(thigh) == "number" then
				-- Keep the feet on the floor: lower the hips by however much
				-- the bent legs are shorter than straight ones.
				local shin = math.max(hipHeight - thigh, 0.1)
				local bent = thigh * math.cos(CROUCH_HIP) + shin * math.cos(CROUCH_HIP - CROUCH_KNEE)
				rig.crouchDrop = math.clamp(hipHeight - bent, 0, 1)
			end
		end
		local water = model:FindFirstChild("Water", true)
		rig.emitter = if water and water:IsA("ParticleEmitter") then water else nil
	end
	self._rigs[model] = rig

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local function load(id: string): AnimationTrack?
			local ok, track = pcall(function()
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				return animator:LoadAnimation(animation)
			end)
			return if ok then track else nil
		end
		local idle = load(IDLE_ANIMATION_ID)
		if idle then
			idle.Looped = true
			idle.Priority = Enum.AnimationPriority.Idle
			idle:Play(0.5, 1, random:NextNumber(0.85, 1.1))
			-- Start each NPC at a different point in the loop.
			task.delay(0.6, function()
				if idle.Length > 0 then
					idle.TimePosition = random:NextNumber(0, idle.Length)
				end
			end)
		end
		local wave = load(WAVE_ANIMATION_ID)
		if wave then
			wave.Looped = false
			wave.Priority = Enum.AnimationPriority.Action
			rig.waveTrack = wave
		end
	end
end

function NpcAnimator:_stopReaction(rig)
	local reaction = rig.reaction
	if reaction and reaction.track then
		reaction.track:Stop(0.35)
	end
	rig.reaction = nil
end

function NpcAnimator:_hasAttention(rig): boolean
	return self._attention[rig.model] ~= nil or (rig.npcId ~= nil and self._attention[rig.npcId] ~= nil)
end

function NpcAnimator:_isTalkingExternally(rig): boolean
	return self._talking[rig.model] == true or (rig.npcId ~= nil and self._talking[rig.npcId] == true)
end

function NpcAnimator:_update(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	local now = os.clock()
	local playerHead = playerHeadPosition()

	-- Who is talking right now (listeners turn toward them).
	local speakers = {}
	for model, rig in self._rigs do
		if model.Parent and rig.talkBlend > 0.35 then
			table.insert(speakers, rig)
		end
	end

	for model, rig in self._rigs do
		if not model.Parent or not rig.root.Parent then
			self._rigs[model] = nil
			continue
		end
		local attention = self:_hasAttention(rig)
		local near = cameraPosition == nil or (rig.root.Position - cameraPosition).Magnitude < MAX_DISTANCE
		if near or attention then
			self:_animate(rig, now, dt, attention, playerHead, speakers)
		end
	end
end

-- The nearest talking NPC whose voice reaches `rig`.
function NpcAnimator:_nearestSpeaker(rig, speakers): Model?
	local best, bestDistance = nil, math.huge
	for _, speaker in speakers do
		if speaker ~= rig then
			local radius = if self:_hasAttention(speaker) then ADDRESS_RADIUS else CHAT_RADIUS
			local distance = (speaker.root.Position - rig.root.Position).Magnitude
			if distance < radius and distance < bestDistance then
				best, bestDistance = speaker.model, distance
			end
		end
	end
	return best
end

function NpcAnimator:_partnerOf(rig, now: number): Model?
	if (rig.partner == nil or not rig.partner.Parent) and now - rig.partnerCheckedAt > 2 then
		rig.partnerCheckedAt = now
		rig.partner = NpcRegistry.nearestTo(rig.model, CHAT_RADIUS)
	end
	return rig.partner
end

function NpcAnimator:_animate(rig, now: number, dt: number, attention: boolean, playerHead: Vector3?, speakers)
	local random = rig.random

	-- Talking: from speech bubbles, the "chat" reaction, or silent chatter.
	local autoTalk = false
	if now < rig.chatUntil then
		if now >= rig.nextChatToggle then
			rig.chatTalking = not rig.chatTalking
			rig.nextChatToggle = now + (if rig.chatTalking then random:NextNumber(1.2, 2.8) else random:NextNumber(0.8, 2))
		end
		autoTalk = rig.chatTalking
	elseif rig.talkative and not attention then
		if now >= rig.nextSilentChat then
			-- Take turns: wait while the partner is mid-sentence.
			local partner = self:_partnerOf(rig, now)
			local partnerRig = partner and self._rigs[partner]
			if partnerRig and partnerRig.talkBlend > 0.3 then
				rig.nextSilentChat = now + random:NextNumber(0.8, 2)
			else
				rig.silentUntil = now + random:NextNumber(2.5, 4.5)
				rig.nextSilentChat = rig.silentUntil + random:NextNumber(3, 7)
			end
		end
		autoTalk = now < rig.silentUntil
	end
	local talking = self:_isTalkingExternally(rig) or autoTalk
	if talking and not rig.wasTalking then
		rig.gestureHand = random:NextInteger(1, 3)
	end
	rig.wasTalking = talking
	rig.talkBlend = lerp(rig.talkBlend, if talking then 1 else 0, dt * 3)

	-- Now and then, idle NPCs turn toward a neighbour for a while.
	if now >= rig.nextIdleTurn then
		rig.nextIdleTurn = now + random:NextNumber(9, 20)
		if rig.idleTurn ~= 0 then
			rig.idleTurn = 0
		elseif not rig.activity and random:NextNumber() < 0.45 then
			local neighbour = NpcRegistry.nearestTo(rig.model, NEIGHBOUR_RADIUS)
			local point = neighbour and NpcRegistry.getHeadPosition(neighbour)
			if point then
				rig.idleTurn = math.clamp(yawTo(rig.home, point), -IDLE_BODY_TURN, IDLE_BODY_TURN)
				rig.lookTarget = neighbour
				rig.lookUntil = now + random:NextNumber(3, 6)
			end
		end
	end

	-- What to look at, and how far the body turns.
	local lookPoint: Vector3? = nil
	local bodyTarget = rig.idleTurn
	if attention and playerHead then
		lookPoint = playerHead
		local maxTurn = if rig.seated then 0.5 else MAX_BODY_TURN
		bodyTarget = math.clamp(yawTo(rig.home, playerHead), -maxTurn, maxTurn)
	elseif now < rig.chatUntil and rig.chatWith and rig.chatWith.Parent then
		lookPoint = NpcRegistry.getHeadPosition(rig.chatWith)
		if lookPoint then
			bodyTarget = math.clamp(yawTo(rig.home, lookPoint), -IDLE_BODY_TURN * 1.5, IDLE_BODY_TURN * 1.5)
		end
	elseif now < rig.lookUntil then
		lookPoint = resolvePoint(rig.lookTarget)
	else
		local speaker = self:_nearestSpeaker(rig, speakers)
		if speaker then
			lookPoint = NpcRegistry.getHeadPosition(speaker)
			-- Listeners nod along now and then.
			if not talking and rig.reaction == nil and now >= rig.nextNod then
				rig.nextNod = now + random:NextNumber(3.5, 7)
				if random:NextNumber() < 0.6 then
					self:react(rig.model, "nod")
				end
			end
		elseif talking then
			local partner = self:_partnerOf(rig, now)
			lookPoint = partner and NpcRegistry.getHeadPosition(partner)
		end
	end
	local reaction = rig.reaction
	if reaction and reaction.target then
		lookPoint = resolvePoint(reaction.target) or lookPoint
	end

	-- Body turn (root part), eased; faster when someone is being addressed.
	local turnSpeed = if attention then BODY_TURN_SPEED else BODY_TURN_SPEED * 0.5
	rig.bodyYaw = lerp(rig.bodyYaw, bodyTarget, dt * turnSpeed)
	if math.abs(rig.bodyYaw - rig.appliedBodyYaw) > 0.0005 then
		rig.appliedBodyYaw = rig.bodyYaw
		rig.root.CFrame = rig.home * CFrame.Angles(0, rig.bodyYaw, 0)
	end

	-- Head and upper body.
	if lookPoint then
		local relative = rig.root.CFrame:PointToObjectSpace(lookPoint)
		local horizontal = math.sqrt(relative.X * relative.X + relative.Z * relative.Z)
		rig.targetYaw = math.clamp(math.atan2(-relative.X, -relative.Z), -MAX_HEAD_YAW, MAX_HEAD_YAW)
		rig.targetPitch = math.clamp(math.atan2(relative.Y - 1.5, math.max(horizontal, 0.1)), -MAX_PITCH, MAX_PITCH)
		rig.hadLook = true
	elseif rig.hadLook then
		-- Attention just ended: drift back to looking ahead.
		rig.hadLook = false
		rig.targetYaw, rig.targetPitch = 0, 0
		rig.nextGlance = now + random:NextNumber(2, 4)
	elseif now >= rig.nextGlance then
		rig.targetYaw = random:NextNumber(-0.45, 0.45)
		rig.targetPitch = random:NextNumber(-0.08, 0.06)
		rig.nextGlance = now + random:NextNumber(2.5, 6)
	end
	local headSpeed = if lookPoint then 4 else 2
	rig.yaw = lerp(rig.yaw, rig.targetYaw, dt * headSpeed)
	rig.pitch = lerp(rig.pitch, rig.targetPitch, dt * headSpeed)

	-- Slow weight shifts.
	if now >= rig.nextShift then
		rig.shiftTarget = random:NextNumber(-1, 1)
		rig.nextShift = now + random:NextNumber(4, 9)
	end
	rig.shift = lerp(rig.shift, rig.shiftTarget, dt * 0.8)

	-- Compose the pose.
	local phase = rig.phase
	local t = now * rig.tempo
	local talk = rig.talkBlend
	local breathe = math.sin(t * 1.7 + phase) * 0.025
	local sway = math.sin(t * 0.9 + phase) * 0.03

	local neckPitch = rig.pitch + breathe * 0.3 + talk * math.sin(t * 7 + phase) * 0.06
	local neckRoll = 0
	local waistPitch = breathe * 0.5
	local waistYaw = rig.yaw * 0.35
	local shrugY = 0
	local rsX, rsZ, lsX, lsZ = sway, 0, -sway, 0
	local reX, leX = 0, 0
	local rightArm = 1 -- weight of the procedural right arm

	-- Talking gestures: right hand, both hands, or left hand.
	local hand = rig.gestureHand
	if hand ~= 3 then
		rsX += talk * (0.35 + math.sin(t * 2.6 + phase) * 0.22)
		reX += talk * (0.55 + math.sin(t * 3.1 + phase) * 0.2)
		rsZ -= talk * 0.1
	end
	if hand ~= 1 then
		local offset = if hand == 2 then 1.3 else 0
		lsX += talk * (0.3 + math.sin(t * 2.4 + phase + offset) * 0.2)
		leX += talk * (0.5 + math.sin(t * 2.9 + phase + offset) * 0.2)
		lsZ += talk * 0.1
	end

	-- Reactions.
	if reaction then
		local elapsed = now - reaction.start
		if elapsed > reaction.duration then
			self:_stopReaction(rig)
		else
			local u = elapsed / reaction.duration
			local env = envelope(elapsed, reaction.duration, 0.25, 0.35)
			local kind = reaction.kind
			if kind == "nod" then
				neckPitch -= 0.17 * (1 - math.cos(u * math.pi * 4)) / 2
			elseif kind == "shrug" then
				shrugY = 0.16 * env
				rsZ += 0.3 * env
				lsZ -= 0.3 * env
				reX += 0.6 * env
				leX += 0.6 * env
				neckRoll = 0.1 * env
			elseif kind == "wave" then
				if reaction.track then
					rightArm = 1 - env -- the wave animation drives the arm
				else
					rsZ += (2.5 + 0.25 * math.sin(elapsed * 9)) * env
					rsX += 0.2 * env
					reX += 0.35 * env
				end
				neckRoll = 0.06 * env
			elseif kind == "point" then
				rsX += 1.45 * env
				reX *= 1 - env
				waistYaw += math.clamp(rig.targetYaw, -0.6, 0.6) * 0.5 * env
			end
		end
	end

	-- Background activity.
	local hip, knee, rootDrop, rWrist = 0, 0, 0, 0
	local activity = rig.activity
	if activity then
		local cycle = CYCLES[activity]
		if now >= rig.phaseUntil then
			rig.working = not rig.working
			local range = if rig.working then cycle.work else cycle.rest
			rig.phaseUntil = now + random:NextNumber(range[1], range[2])
		end
		rig.workBlend = lerp(rig.workBlend, if rig.working then 1 else 0, dt * 1.6)
		local engaged = not attention and reaction == nil and not self:_isTalkingExternally(rig)
		rig.taskBlend = lerp(rig.taskBlend, if engaged then 1 else 0, dt * 2)
		local task = rig.taskBlend
		local work = rig.workBlend * task
		local rest = (1 - rig.workBlend) * task
		if rig.seated then
			hip += SIT_BEND
			knee -= SIT_BEND
			rootDrop += rig.seatDrop
			-- Hands resting on the lap.
			rsX += 0.5 * task
			reX += 0.55 * task
			lsX += 0.5 * task
			leX += 0.55 * task
			if activity == "sit_mug" then
				lsX += 0.35 * rest
				leX += 1.3 * rest
				neckPitch += 0.12 * rest
			elseif activity == "sit_phone" then
				rsX += 0.25 * task
				reX += 0.45 * task
				rsZ -= 0.25 * task
				lsX += 0.25 * task
				leX += 0.45 * task
				lsZ += 0.25 * task
				neckPitch -= 0.4 * work
			end
		elseif activity == "water" then
			rsX += 0.15 * task + 0.3 * work
			reX += 0.15 * work
			rWrist -= 1.3 * work
			waistPitch -= 0.1 * work
			waistYaw += 0.25 * math.sin(t * 0.45 + phase) * work
			neckPitch -= 0.25 * work
		elseif activity == "sweep" then
			local stroke = math.sin(t * 2.6 + phase) * work
			rsX += 0.45 * task
			reX += 0.35 * task
			rsZ += -0.15 * task + 0.12 * stroke
			lsX += 0.75 * task
			leX += 0.45 * task
			lsZ += 0.35 * task + 0.1 * stroke
			waistPitch -= 0.12 * task
			waistYaw += 0.3 * stroke
			neckPitch -= 0.2 * work
		elseif activity == "garden" then
			hip += CROUCH_HIP * work
			knee -= CROUCH_KNEE * work
			rootDrop += rig.crouchDrop * work
			waistPitch += -0.55 * work + 0.08 * rest
			neckPitch -= 0.15 * work
			rsX += (0.9 + 0.12 * math.sin(t * 3.2 + phase)) * work
			reX += 0.3 * work
			lsX += (0.7 + 0.1 * math.sin(t * 2.7 + phase + 1)) * work
			leX += 0.25 * work
		elseif activity == "phone" then
			rsX += 0.6 * task
			reX += 1.3 * task
			rsZ -= 0.2 * task
			lsX += 0.3 * task
			leX += 0.6 * task
			neckPitch -= 0.35 * work
		end
		local emitter = rig.emitter
		if emitter then
			local pouring = work > 0.7
			if emitter.Enabled ~= pouring then
				emitter.Enabled = pouring
			end
		end
	end

	-- Small steps in place while the body turns, so feet don't glide.
	local turnRate = math.abs(rig.bodyYaw - rig.lastBodyYaw) / math.max(dt, 1e-3)
	rig.lastBodyYaw = rig.bodyYaw
	local canStep = not rig.seated and rootDrop < 0.05
	rig.stepBlend = lerp(rig.stepBlend, if canStep then math.clamp(turnRate * 1.5, 0, 1) else 0, dt * 6)
	local stepRight = 0.35 * math.max(0, math.sin(t * 9 + phase)) * rig.stepBlend
	local stepLeft = 0.35 * math.max(0, math.sin(t * 9 + phase + math.pi)) * rig.stepBlend

	local joints = rig.joints
	local function pose(name: string, offset: CFrame)
		local joint = joints[name]
		if joint then
			joint.motor.C0 = joint.base * offset
		end
	end
	pose("Root", CFrame.new(rig.shift * 0.05, -rootDrop, 0) * CFrame.Angles(0, 0, rig.shift * 0.025))
	pose("RightHip", CFrame.Angles(hip + stepRight, 0, 0))
	pose("LeftHip", CFrame.Angles(hip + stepLeft, 0, 0))
	pose("RightKnee", CFrame.Angles(knee - stepRight * 1.7, 0, 0))
	pose("LeftKnee", CFrame.Angles(knee - stepLeft * 1.7, 0, 0))
	pose("RightWrist", CFrame.Angles(rWrist, 0, 0))
	pose("Waist", CFrame.Angles(waistPitch, waistYaw, -rig.shift * 0.02))
	pose("Neck", CFrame.Angles(neckPitch, rig.yaw * 0.65, neckRoll))
	pose("RightShoulder", CFrame.new(0, shrugY, 0) * CFrame.Angles(rsX * rightArm, 0, rsZ * rightArm))
	pose("LeftShoulder", CFrame.new(0, shrugY, 0) * CFrame.Angles(lsX, 0, lsZ))
	pose("RightElbow", CFrame.Angles(reX * rightArm, 0, 0))
	pose("LeftElbow", CFrame.Angles(leX, 0, 0))
end

return NpcAnimator
