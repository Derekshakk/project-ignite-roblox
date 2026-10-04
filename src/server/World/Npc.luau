--[[
	Npc

	Placeholder students and teachers. Each NPC is a standard R15 rig built
	from a HumanoidDescription (so it looks like a Roblox character), with a
	simple block figure as a fallback if the rig can't be created. Only the
	root part is anchored, so the rig stays in place but its joints can be
	animated (idle movement and talking are driven by the client's
	NpcAnimator). There is no pathfinding or AI.

	Variety comes from a deterministic seed: skin tone, shirt/pants colours,
	long or short sleeves, slight body-scale differences, a small turn, and
	optionally a backpack.

	Rigs are created in their own threads so loading them never delays the
	rest of the world (or the player's spawn).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

local Builder = require(script.Parent.Builder)
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

local Npc = {}

local function pick(list: { Color3 }, seed: number): Color3
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

-- Small, low-contrast speech bubble to suggest background chatter.
local function addChatter(model: Model, text: string)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Chatter"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 40
	billboard.LightInfluence = 0
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = rgb(236, 234, 228)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = rgb(70, 70, 80)
	label.Text = text
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
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

--[[
	Spawns an NPC standing on the floor at `floorCFrame`, facing its
	LookVector. Options:
		seed: number?       varies appearance
		shirt: Color3?      overrides the shirt colour
		chatter: string?    small speech bubble
		backpack: boolean?  wear a backpack (default: depends on seed)
		adult: boolean?     taller, no backpack
		npcId: string?      name used by scenes (Data/Npcs), e.g. "teacher"
		talkative: boolean? gestures and chats now and then while idle
		                    (default: true when `chatter` is set)
]]
function Npc.spawn(parent: Instance, name: string, floorCFrame: CFrame, options: { [string]: any }?)
	options = options or {}
	local seed = options.seed or #parent:GetChildren()
	local r = Props.hash(seed + 0.5)
	local look = {
		skin = pick(SKIN_TONES, seed * 5 + 3),
		shirt = options.shirt or pick(SHIRT_COLORS, seed * 3 + 1),
		pants = pick(PANTS_COLORS, seed * 7 + 2),
		longSleeves = r > 0.5,
		heightScale = if options.adult then 1.05 else 0.9 + r * 0.12,
		widthScale = 0.9 + Props.hash(seed + 1.5) * 0.15,
	}
	local wantsBackpack = if options.backpack ~= nil then options.backpack else (not options.adult and r < 0.45)
	-- A small turn (±12°) so groups don't look rigidly aligned.
	local turn = CFrame.Angles(0, math.rad((Props.hash(seed + 2.5) - 0.5) * 24), 0)

	task.spawn(function()
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
		model:PivotTo(floorCFrame * turn * CFrame.new(0, standingHeight, 0))
		if wantsBackpack then
			addBackpack(model, pick(BACKPACK_COLORS, seed))
		end
		if options.chatter then
			addChatter(model, options.chatter)
		end
		if options.npcId then
			model:SetAttribute(World.Attributes.NpcId, options.npcId)
		end
		local talkative = if options.talkative ~= nil then options.talkative else options.chatter ~= nil
		model:SetAttribute(World.Attributes.Talkative, talkative)
		model:SetAttribute("AnimationSeed", seed)
		CollectionService:AddTag(model, World.Tags.Npc)
		model.Parent = parent
	end)
end

return Npc
