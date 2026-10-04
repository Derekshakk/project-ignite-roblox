--[[
	Npc

	Placeholder students and teachers. Each NPC is a standard R15 rig built
	from a HumanoidDescription (so it looks like a Roblox character), with a
	simple block figure as a fallback if the rig can't be created. Only the
	root part is anchored, so the rig stays in place but its joints can be
	animated (idle movement and talking are driven by the client's
	NpcAnimator). There is no pathfinding or AI.

	Variety comes from a deterministic seed: skin tone, shirt/pants colours,
	long or short sleeves, slight body-scale differences, a hairstyle (short,
	long, bun, ponytail, cap, or none) in a natural hair colour, a small
	turn, and optionally a backpack. Hair is a few stretched spheres welded
	to the head (no catalog assets), so it follows head animation.

	Background neighbours can have a looping `activity` (watering,
	sweeping, gardening, sitting…) played by the client's NpcAnimator, and
	hold a prop (HeldProps). The rig's leg proportions are measured and
	stored (HipJointHeight, ThighLength) so sitting and crouching poses put
	feet and seats in the right place for any body scale.

	Npc.build also makes the unparented rigs the client clones as
	pedestrians (AmbientTemplates).

	Background chatter lines are stored on the model (ChatterLines); the
	client shows them one speaker at a time as speech bubbles, so bubbles
	never pile up on top of each other.

	Rigs are created in their own threads so loading them never delays the
	rest of the world (or the player's spawn).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

local Builder = require(script.Parent.Builder)
local HeldProps = require(script.Parent.HeldProps)
local Props = require(script.Parent.Props)

local rgb = Color3.fromRGB

local SKIN_TONES = {
	rgb(255, 218, 186),
	rgb(234, 184, 146),
	rgb(205, 150, 108),
	rgb(168, 112, 78),
	rgb(124, 82, 56),
	rgb(92, 62, 44),
}

-- Muted, varied clothing; nothing pure white so it doesn't glare.
local SHIRT_COLORS = {
	rgb(74, 108, 160),
	rgb(168, 76, 76),
	rgb(82, 140, 104),
	rgb(204, 166, 74),
	rgb(124, 92, 156),
	rgb(214, 208, 196),
	rgb(56, 58, 66),
	rgb(196, 120, 80),
	rgb(90, 150, 160),
	rgb(150, 160, 120),
	rgb(200, 132, 150),
}

local PANTS_COLORS = {
	rgb(46, 56, 84),
	rgb(66, 66, 72),
	rgb(104, 86, 66),
	rgb(30, 30, 36),
	rgb(84, 100, 120),
	rgb(120, 110, 90),
}

local BACKPACK_COLORS = {
	rgb(60, 80, 120),
	rgb(140, 60, 60),
	rgb(60, 110, 80),
	rgb(50, 50, 56),
	rgb(180, 130, 60),
}

local HAIR_COLORS = {
	rgb(38, 30, 26),
	rgb(66, 46, 34),
	rgb(104, 72, 46),
	rgb(146, 92, 52),
	rgb(196, 160, 104),
	rgb(28, 26, 30),
}
local GREY_HAIR = rgb(170, 168, 164)
local CAP_COLORS = { rgb(60, 80, 130), rgb(150, 50, 50), rgb(60, 110, 80), rgb(46, 46, 52) }
local STUDENT_HAIR = { "short", "long", "bun", "ponytail", "cap", "short", "long" }
local ADULT_HAIR = { "short", "short", "long", "bun", "none", "cap" }
-- Approximate size of the default R15 head (studs). Hair is sized from
-- this; tune here if it sits too high or low on a different head.
local HEAD_SIZE = 1.25

local Npc = {}

-- Turn off to give every NPC the plain default head.
Npc.HAIR_ENABLED = true

local function pick<T>(list: { T }, seed: number): T
	return list[(seed % #list) + 1]
end

local function createRig(look): Model?
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local armColor = if look.longSleeves then look.shirt else look.skin
		description.HeadColor = look.skin
		description.LeftArmColor = armColor
		description.RightArmColor = armColor
		description.TorsoColor = look.shirt
		description.LeftLegColor = look.pants
		description.RightLegColor = look.pants
		description.HeightScale = look.heightScale
		description.WidthScale = look.widthScale
		description.DepthScale = look.widthScale
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn(`[Npc] Falling back to block figures: {result}`)
		return nil
	end
	local model = result :: Model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	-- NPCs are animated by the client; the stock Animate script never runs
	-- outside a player's character, so drop it.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	-- Root part centre sits HipHeight + half its height above the floor.
	model:SetAttribute("StandingHeight", humanoid.HipHeight + root.Size.Y / 2)
	return model
end

-- Fallback: a simple standing figure built around its torso.
local function createBlockFigure(look): Model
	local model = Instance.new("Model")
	local armColor = if look.longSleeves then look.shirt else look.skin
	local torso = Builder.part(model, "Torso", CFrame.new(0, 0, 0), Vector3.new(2, 2, 1), look.shirt)
	Builder.part(model, "Head", CFrame.new(0, 1.6, 0), Vector3.new(1.2, 1.2, 1.2), look.skin, { Shape = Enum.PartType.Ball })
	Builder.part(model, "LeftLeg", CFrame.new(-0.5, -2, 0), Vector3.new(0.95, 2, 1), look.pants)
	Builder.part(model, "RightLeg", CFrame.new(0.5, -2, 0), Vector3.new(0.95, 2, 1), look.pants)
	Builder.part(model, "LeftArm", CFrame.new(-1.5, 0, 0), Vector3.new(0.9, 2, 1), armColor)
	Builder.part(model, "RightArm", CFrame.new(1.5, 0, 0), Vector3.new(0.9, 2, 1), armColor)
	model.PrimaryPart = torso
	model:SetAttribute("StandingHeight", 3)
	return model
end

-- Backpack worn on the back of the upper torso.
local function addBackpack(model: Model, color: Color3)
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local backpack = Props.backpack(model, torso.CFrame * CFrame.new(0, -1.0, torso.Size.Z / 2 + 0.35) * CFrame.Angles(0, math.pi, 0), color)
	-- Welded so it moves with the torso when the NPC is animated.
	for _, part in backpack:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function weldTo(anchor: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

-- Stylised hair (or a cap) welded to the head. The face is on the head's
-- front (-Z), so everything sits on top and toward the back.
local function addHair(model: Model, look)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head or look.hair == "none" or not Npc.HAIR_ENABLED then
		return
	end
	local h = HEAD_SIZE
	local function piece(name: string, offset: CFrame, size: Vector3, color: Color3): BasePart
		local part = Builder.ellipsoid(model, name, (head :: BasePart).CFrame * offset, size, color, { Material = Enum.Material.Fabric })
		weldTo(head :: BasePart, part)
		return part
	end
	if look.hair == "cap" then
		piece("Cap", CFrame.new(0, h * 0.27, h * 0.05), Vector3.new(h * 1.08, h * 0.56, h * 1.1), look.capColor)
		local brim = Builder.part(model, "CapBrim", head.CFrame * CFrame.new(0, h * 0.13, -h * 0.58) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(h * 0.78, 0.07, h * 0.5), look.capColor)
		weldTo(head, brim)
		piece("Hair", CFrame.new(0, -h * 0.02, h * 0.32), Vector3.new(h * 0.96, h * 0.42, h * 0.5), look.hairColor)
		return
	end
	piece("Hair", CFrame.new(0, h * 0.27, h * 0.07), Vector3.new(h * 1.06, h * 0.62, h * 1.1), look.hairColor)
	if look.hair == "long" then
		piece("HairBack", CFrame.new(0, -h * 0.15, h * 0.33), Vector3.new(h * 0.98, h * 1.2, h * 0.5), look.hairColor)
	elseif look.hair == "bun" then
		piece("Bun", CFrame.new(0, h * 0.52, h * 0.36), Vector3.new(h * 0.48, h * 0.44, h * 0.48), look.hairColor)
	elseif look.hair == "ponytail" then
		piece("Ponytail", CFrame.new(0, -h * 0.05, h * 0.6) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(h * 0.32, h * 0.8, h * 0.32), look.hairColor)
	end
end

-- Records the rig's hip height above `floorY` and thigh length, for
-- sitting and crouching poses on the client.
local function measureLegs(model: Model, floorY: number)
	local upperLeg = model:FindFirstChild("RightUpperLeg")
	local lowerLeg = model:FindFirstChild("RightLowerLeg")
	local hip = upperLeg and upperLeg:FindFirstChild("RightHip")
	local knee = lowerLeg and lowerLeg:FindFirstChild("RightKnee")
	if not (hip and hip:IsA("Motor6D") and knee and knee:IsA("Motor6D") and hip.Part0 and knee.Part0) then
		return
	end
	local hipPosition = ((hip.Part0 :: BasePart).CFrame * hip.C0).Position
	local kneePosition = ((knee.Part0 :: BasePart).CFrame * knee.C0).Position
	model:SetAttribute(World.Attributes.HipJointHeight, hipPosition.Y - floorY)
	model:SetAttribute(World.Attributes.ThighLength, (kneePosition - hipPosition).Magnitude)
end

-- The look (colours, scale, hair) for a seed. Options as in Npc.spawn.
function Npc.look(seed: number, options: { [string]: any }?)
	local opts = options or {}
	local r = Props.hash(seed + 0.5)
	local adult = opts.adult == true
	local hairColor = pick(HAIR_COLORS, seed * 11 + 5)
	if adult and Props.hash(seed + 3.5) < 0.3 then
		hairColor = GREY_HAIR:Lerp(hairColor, 0.2)
	end
	return {
		skin = pick(SKIN_TONES, seed * 5 + 3),
		shirt = opts.shirt or pick(SHIRT_COLORS, seed * 3 + 1),
		pants = opts.pants or pick(PANTS_COLORS, seed * 7 + 2),
		longSleeves = r > 0.5,
		heightScale = if adult then 1.0 + Props.hash(seed + 4.5) * 0.1 else 0.9 + r * 0.12,
		widthScale = 0.9 + Props.hash(seed + 1.5) * 0.15,
		hair = opts.hair or pick(if adult then ADULT_HAIR else STUDENT_HAIR, seed * 13 + 7),
		hairColor = hairColor,
		capColor = pick(CAP_COLORS, seed),
	}
end

--[[
	Builds an NPC figure (yields while the rig is created), standing with
	its feet at y = 0 and facing -Z, unparented. Only the root part is
	anchored (block-figure fallbacks are fully anchored). Options: seed,
	adult, shirt, pants, hair, backpack, hold, holdHand (see Npc.spawn).
	Returns the model and whether it is a real (animatable) rig.
]]
function Npc.build(name: string, seed: number, options: { [string]: any }?): (Model, boolean)
	local opts = options or {}
	local look = Npc.look(seed, opts)
	local rig = createRig(look)
	local model = rig or createBlockFigure(look)
	model.Name = name
	local primary = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Rigs: anchor only the root so joints can animate.
			-- Block figures have no joints, so every part is anchored.
			descendant.Anchored = (rig == nil) or descendant == primary
		end
	end
	-- Give the player something solid to step around.
	primary.CanCollide = true

	local standingHeight = model:GetAttribute("StandingHeight") or 3
	model:PivotTo(CFrame.new(0, standingHeight, 0))
	if rig then
		addHair(model, look)
		measureLegs(model, 0)
		if opts.hold then
			local hand = model:FindFirstChild((opts.holdHand or "Right") .. "Hand")
			if hand and hand:IsA("BasePart") then
				HeldProps.attach(hand, opts.hold)
			end
		end
	end
	local wantsBackpack = if opts.backpack ~= nil then opts.backpack else (not opts.adult and Props.hash(seed + 0.5) < 0.45)
	if wantsBackpack then
		addBackpack(model, pick(BACKPACK_COLORS, seed))
	end
	model:SetAttribute("AnimationSeed", seed)
	return model, rig ~= nil
end

--[[
	Spawns an NPC standing on the floor at `floorCFrame`, facing its
	LookVector. Options:
		seed: number?       varies appearance
		shirt: Color3?      overrides the shirt colour
		chatter: string | { string }?
		                    background lines, shown now and then by the
		                    client as a speech bubble
		backpack: boolean?  wear a backpack (default: depends on seed)
		adult: boolean?     taller, no backpack
		npcId: string?      name used by scenes (Data/Npcs), e.g. "teacher"
		talkative: boolean? gestures and chats now and then while idle
		                    (default: true when `chatter` is set)
		turnRange: number?  random turn in degrees either side (default 12)
		prompt: { interactionType: string, interactionId: string,
		          props: { [string]: any }? }?
		                    a ProximityPrompt on the NPC (e.g. talk to them)
		hideWhenFlag: string?
		                    the client hides this NPC once the flag is set
		                    (e.g. students leaving once the rush is over)
		hair: string?       "short" | "long" | "bun" | "ponytail" | "cap" | "none"
		activity: string?   looping background activity (NpcAnimator):
		                    "water", "sweep", "garden", "sit", "sit_mug",
		                    "sit_phone", "phone"
		hold: string?       prop in a hand (HeldProps): "watering_can",
		                    "broom", "trowel", "mug", "phone"
		holdHand: string?   "Right" (default) or "Left"
		seatHeight: number? seated activities: seat top above the floor
]]
function Npc.spawn(parent: Instance, name: string, floorCFrame: CFrame, options: { [string]: any }?)
	local opts = options or {}
	local seed = opts.seed or #parent:GetChildren()
	-- A small turn so groups don't look rigidly aligned.
	local turnRange = opts.turnRange or 12
	local turn = CFrame.Angles(0, math.rad((Props.hash(seed + 2.5) - 0.5) * 2 * turnRange), 0)

	task.spawn(function()
		local model = Npc.build(name, seed, opts)
		local standingHeight = model:GetAttribute("StandingHeight") or 3
		model:PivotTo(floorCFrame * turn * CFrame.new(0, standingHeight, 0))
		local primary = model.PrimaryPart :: BasePart
		local chatter = opts.chatter
		if type(chatter) == "string" then
			chatter = { chatter }
		end
		if type(chatter) == "table" and #chatter > 0 then
			model:SetAttribute(World.Attributes.ChatterLines, table.concat(chatter, "|"))
		end
		if opts.npcId then
			model:SetAttribute(World.Attributes.NpcId, opts.npcId)
		end
		if opts.activity then
			model:SetAttribute(World.Attributes.Activity, opts.activity)
		end
		if opts.seatHeight then
			model:SetAttribute(World.Attributes.SeatHeight, opts.seatHeight)
		end
		local prompt = opts.prompt
		if prompt then
			local created = Builder.prompt(primary, prompt.interactionType, prompt.interactionId, prompt.props)
			-- The NPC turning toward the player is the feedback.
			created:SetAttribute(World.Attributes.Feedback, "none")
			created.RequiresLineOfSight = false
		end
		local talkative = if opts.talkative ~= nil then opts.talkative else opts.chatter ~= nil
		model:SetAttribute(World.Attributes.Talkative, talkative)
		if opts.hideWhenFlag then
			model:SetAttribute(World.Attributes.HideWhenFlag, opts.hideWhenFlag)
			CollectionService:AddTag(model, World.Tags.FlagVisibility)
		end
		CollectionService:AddTag(model, World.Tags.Npc)
		model.Parent = parent
	end)
end

return Npc
