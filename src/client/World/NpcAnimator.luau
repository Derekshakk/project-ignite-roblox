--[[
	NpcAnimator

	Reusable, lightweight animation for every NPC tagged IgniteNpc (any R15
	rig). Works without custom animation assets:

	- Base layer: Roblox's default R15 idle animation, if it loads (it's a
	  Roblox-owned animation usable in any experience). If it can't load,
	  the procedural layer still runs on its own.
	- Procedural layer on the joints (Motor6D C0, so it stacks on top of any
	  animation): breathing, occasional head turns, and a talking state with
	  head nods and a hand gesture.

	States:
		idle      breathing + glances
		chatting  talkative NPCs talk to each other now and then
		dialogue  startDialogue(npcId) — turns head/torso toward the player
		          and talks until endDialogue(npcId)

	Only NPCs near the camera are updated, at ~30 Hz, to keep it cheap.
	Block-figure fallback NPCs have no joints and stay still.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

-- PLACEHOLDER: Roblox's default R15 idle. Replace with a custom idle later.
local IDLE_ANIMATION_ID = "rbxassetid://507766666"

local UPDATE_INTERVAL = 1 / 30
local MAX_DISTANCE = 90
local JOINT_NAMES = { "Neck", "Waist", "RightShoulder", "LeftShoulder", "RightElbow" }
local MAX_YAW = math.rad(65)
local MAX_PITCH = math.rad(20)

local NpcAnimator = {}
NpcAnimator.__index = NpcAnimator

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

function NpcAnimator.new()
	return setmetatable({
		_rigs = {} :: { [Model]: any },
		_dialogue = {} :: { [string]: number },
		_since = 0,
	}, NpcAnimator)
end

function NpcAnimator:start()
	local function add(instance: Instance)
		if instance:IsA("Model") then
			task.spawn(function()
				self:_add(instance)
			end)
		end
	end
	for _, model in CollectionService:GetTagged(World.Tags.Npc) do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.Npc):Connect(add)
	CollectionService:GetInstanceRemovedSignal(World.Tags.Npc):Connect(function(instance)
		self._rigs[instance :: any] = nil
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

-- Starts/stops a conversation with the player. Calls are counted, so
-- overlapping scenes (e.g. listening + a scenario) end cleanly.
function NpcAnimator:startDialogue(npcId: string)
	self._dialogue[npcId] = (self._dialogue[npcId] or 0) + 1
end

function NpcAnimator:endDialogue(npcId: string)
	local count = (self._dialogue[npcId] or 0) - 1
	self._dialogue[npcId] = if count > 0 then count else nil
end

function NpcAnimator:isInDialogue(npcId: string?): boolean
	return npcId ~= nil and self._dialogue[npcId] ~= nil
end

function NpcAnimator:_add(model: Model, attempt: number?)
	if self._rigs[model] or not model.Parent then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
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
	local random = Random.new(seed)
	local now = os.clock()
	local rig = {
		model = model,
		root = root,
		joints = joints,
		npcId = model:GetAttribute(World.Attributes.NpcId),
		talkative = model:GetAttribute(World.Attributes.Talkative) == true,
		random = random,
		phase = random:NextNumber(0, math.pi * 2),
		talkBlend = 0,
		yaw = 0,
		pitch = 0,
		targetYaw = 0,
		targetPitch = 0,
		nextGlance = now + random:NextNumber(1, 5),
		chatUntil = 0,
		nextChat = now + random:NextNumber(1, 6),
	}
	self._rigs[model] = rig

	-- Base idle animation (optional).
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local ok, track = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = IDLE_ANIMATION_ID
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Idle
			track:Play(0.5, 1, random:NextNumber(0.85, 1.1))
		end
	end
end

local function playerTarget(): Vector3?
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return head and head.Position
end

function NpcAnimator:_update(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	local now = os.clock()
	for model, rig in self._rigs do
		if not model.Parent or not rig.root.Parent then
			self._rigs[model] = nil
			continue
		end
		local inDialogue = self:isInDialogue(rig.npcId)
		local near = cameraPosition == nil or (rig.root.Position - cameraPosition).Magnitude < MAX_DISTANCE
		if near or inDialogue then
			self:_animate(rig, now, dt, inDialogue)
		end
	end
end

function NpcAnimator:_animate(rig, now: number, dt: number, inDialogue: boolean)
	local random = rig.random

	-- Talkative NPCs chat now and then; dialogue always talks.
	if rig.talkative and not inDialogue and now >= rig.nextChat then
		rig.chatUntil = now + random:NextNumber(2.5, 4.5)
		rig.nextChat = rig.chatUntil + random:NextNumber(4, 9)
	end
	local talking = inDialogue or now < rig.chatUntil
	rig.talkBlend = lerp(rig.talkBlend, if talking then 1 else 0, dt * 3)

	-- Where to look.
	local target = if inDialogue then playerTarget() else nil
	if target then
		local relative = rig.root.CFrame:PointToObjectSpace(target)
		local horizontal = math.sqrt(relative.X * relative.X + relative.Z * relative.Z)
		rig.targetYaw = math.clamp(math.atan2(-relative.X, -relative.Z), -MAX_YAW, MAX_YAW)
		rig.targetPitch = math.clamp(math.atan2(relative.Y - 1.5, math.max(horizontal, 0.1)), -MAX_PITCH, MAX_PITCH)
	elseif now >= rig.nextGlance then
		rig.targetYaw = random:NextNumber(-0.45, 0.45)
		rig.targetPitch = random:NextNumber(-0.08, 0.06)
		rig.nextGlance = now + random:NextNumber(2.5, 6)
	end
	local turnSpeed = if inDialogue then 4 else 2
	rig.yaw = lerp(rig.yaw, rig.targetYaw, dt * turnSpeed)
	rig.pitch = lerp(rig.pitch, rig.targetPitch, dt * turnSpeed)

	local phase = rig.phase
	local talk = rig.talkBlend
	local breathe = math.sin(now * 1.7 + phase) * 0.025
	local nod = talk * math.sin(now * 7 + phase) * 0.07
	local gesture = talk * (0.35 + math.sin(now * 2.6 + phase) * 0.25)
	local sway = math.sin(now * 0.9 + phase) * 0.03

	local joints = rig.joints
	joints.Waist.motor.C0 = joints.Waist.base * CFrame.Angles(breathe * 0.5, rig.yaw * 0.35, 0)
	joints.Neck.motor.C0 = joints.Neck.base * CFrame.Angles(rig.pitch + nod + breathe * 0.3, rig.yaw * 0.65, 0)
	if joints.RightShoulder then
		joints.RightShoulder.motor.C0 = joints.RightShoulder.base * CFrame.Angles(gesture + sway, 0, -talk * 0.12)
	end
	if joints.RightElbow then
		joints.RightElbow.motor.C0 = joints.RightElbow.base * CFrame.Angles(talk * (0.5 + math.sin(now * 3.1 + phase) * 0.2), 0, 0)
	end
	if joints.LeftShoulder then
		joints.LeftShoulder.motor.C0 = joints.LeftShoulder.base * CFrame.Angles(-sway + talk * 0.1 * math.sin(now * 2 + phase), 0, 0)
	end
end

return NpcAnimator
