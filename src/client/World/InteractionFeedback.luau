--[[
	InteractionFeedback

	Subtle, local feedback for interactable objects:
	- a soft outline while an object's prompt is shown (Settings: highlights);
	  a prompt inside a model marked InteractModel (or an NPC) outlines the
	  whole model
	- when used: a quiet sound cue and a short physical response chosen by
	  the prompt's Feedback attribute:
	      "lift"     the object lifts slightly and settles back
	      "pulse"    (default) a gentle glow that fades out
	      "open"     swings the prompt's AnimatedCover open (it stays open,
	                 e.g. the planner) and glows
	      "collect"  (pickups) the item rises, turns and fades away
	      "pack"     the item arcs into the PackInto target (the backpack),
	                 which gives a small bump
	      "none"     sound only (e.g. NPCs, who turn toward the player)
	- prompts with an "AnimatedDoor" ObjectValue swing that door open briefly
	No flashing, no camera movement: every effect is a single ease or fade.

	collect/pack animate a snapshot taken *before* the interaction (the real
	object hides as soon as the state changes): call snapshot(prompt) first,
	then play(prompt, ghost).

	Sound cues use sounds that ship with every Roblox client (PLACEHOLDERS:
	swap for Creator Store sounds later). Volumes are deliberately low.
]]

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Settings = require(script.Parent.Parent.Settings)
local Doors = require(script.Parent.Doors)

local Attributes = World.Attributes

local CUES = table.freeze({
	use = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35, speed = 1 },
	collect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.15, speed = 1.15 },
	pack = { id = "rbxasset://sounds/swoosh.wav", volume = 0.12, speed = 1.25 },
	land = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.3, speed = 0.75 },
	step = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.18, speed = 0.85 },
	complete = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.12, speed = 0.9 },
})

local HIGHLIGHT_COLOR = Color3.fromRGB(255, 214, 150)
local LIFT_SECONDS = 0.36
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local COLLECT_SECONDS = 0.55
local PACK_SECONDS = 0.6

local InteractionFeedback = {}
InteractionFeedback.__index = InteractionFeedback

function InteractionFeedback.new()
	local sounds = {}
	for name, cue in CUES do
		local sound = Instance.new("Sound")
		sound.Name = `IgniteCue_{name}`
		sound.SoundId = cue.id
		sound.Volume = cue.volume
		sound.PlaybackSpeed = cue.speed
		sound.Parent = SoundService
		sounds[name] = sound
	end

	return setmetatable({
		_sounds = sounds,
		_highlights = {} :: { [ProximityPrompt]: Highlight },
		_lifting = {} :: { [Instance]: boolean },
	}, InteractionFeedback)
end

-- The object a prompt belongs to: an NPC, a whole model, or the part.
local function targetOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if not parent then
		return nil
	end
	local npc = parent:FindFirstAncestorOfClass("Model")
	if npc and CollectionService:HasTag(npc, World.Tags.Npc) then
		return npc
	end
	local model = parent.Parent
	if model and model:IsA("Model") and (model:GetAttribute("PickupItemId") or model:GetAttribute(Attributes.InteractModel)) then
		return model
	end
	return parent
end

local function styleOf(prompt: ProximityPrompt): string
	local style = prompt:GetAttribute(Attributes.Feedback)
	if type(style) == "string" then
		return style
	end
	if prompt:GetAttribute(Attributes.InteractionType) == World.InteractionTypes.Pickup then
		return "collect"
	end
	return "pulse"
end

-- Runs `step(alpha)` every frame for `seconds`, then `done()`.
local function animate(seconds: number, step: (number) -> (), done: (() -> ())?)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min((os.clock() - started) / seconds, 1)
		step(alpha)
		if alpha >= 1 then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

local function easeOut(x: number): number
	return 1 - (1 - x) * (1 - x)
end

local function easeInOut(x: number): number
	return x * x * (3 - 2 * x)
end

function InteractionFeedback:start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if Settings.get("highlights") and CollectionService:HasTag(prompt, World.Tags.Interactable) then
			self:_showHighlight(prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		self:_hideHighlight(prompt)
	end)
	Settings.Changed:Connect(function(key, value)
		if key == "highlights" and not value then
			for prompt in self._highlights do
				self:_hideHighlight(prompt)
			end
		end
	end)
end

-- Plays a named sound cue (also used by other world modules).
function InteractionFeedback:cue(name: string)
	local sound = self._sounds[name]
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

function InteractionFeedback:_showHighlight(prompt: ProximityPrompt)
	local target = targetOf(prompt)
	if not target or self._highlights[prompt] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "IgniteOutline"
	highlight.Adornee = target
	highlight.FillTransparency = 1
	highlight.OutlineColor = HIGHLIGHT_COLOR
	highlight.OutlineTransparency = 0.45
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target
	self._highlights[prompt] = highlight
end

function InteractionFeedback:_hideHighlight(prompt: ProximityPrompt)
	local highlight = self._highlights[prompt]
	if highlight then
		highlight:Destroy()
		self._highlights[prompt] = nil
	end
end

--[[
	A non-interactive copy of the prompt's object, for animations that
	outlive the original (collect, pack). Returns nil for other styles.
]]
function InteractionFeedback:snapshot(prompt: ProximityPrompt): Model?
	local style = styleOf(prompt)
	if style ~= "collect" and style ~= "pack" then
		return nil
	end
	local target = targetOf(prompt)
	if not target or not (target:IsA("Model") or target:IsA("BasePart")) then
		return nil
	end
	local ok, copy = pcall(function()
		return target:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local ghost: Model
	if copy:IsA("Model") then
		ghost = copy
	else
		ghost = Instance.new("Model")
		copy.Parent = ghost
		ghost.PrimaryPart = copy
	end
	ghost.Name = "IgniteGhost"
	local descendants = ghost:GetDescendants()
	table.insert(descendants, ghost)
	for _, descendant in descendants do
		-- Strip anything interactive or tagged so nothing binds to the copy.
		for _, tag in CollectionService:GetTags(descendant) do
			CollectionService:RemoveTag(descendant, tag)
		end
		if descendant:IsA("ProximityPrompt") or descendant:IsA("ObjectValue") or descendant:IsA("Highlight") or descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return ghost
end

-- Called after an interaction succeeds.
function InteractionFeedback:play(prompt: ProximityPrompt, ghost: Model?)
	local style = styleOf(prompt)
	local target = targetOf(prompt)

	local door = prompt:FindFirstChild("AnimatedDoor")
	if door and door:IsA("ObjectValue") and door.Value and door.Value:IsA("BasePart") then
		Doors.pulse(door.Value, 2.5) -- the door system plays its own sound
	end

	if style == "collect" and ghost then
		self:cue("collect")
		self:_collect(ghost)
	elseif style == "pack" and ghost then
		self:cue("pack")
		self:_pack(prompt, ghost)
	else
		if ghost then
			ghost:Destroy()
		end
		self:cue("use")
		if style == "open" then
			local cover = prompt:FindFirstChild("AnimatedCover")
			if cover and cover:IsA("ObjectValue") and cover.Value and cover.Value:IsA("BasePart") then
				Doors.setOpen(cover.Value, true)
			end
			if target then
				self:_pulse(target)
			end
		elseif style == "lift" and target then
			self:_lift(target)
		elseif style == "pulse" and target then
			self:_pulse(target)
		end
	end
end

-- Lifts a part or model slightly and settles it back.
function InteractionFeedback:_lift(target: Instance)
	if self._lifting[target] then
		return
	end
	local isModel = target:IsA("Model")
	if not isModel and not (target:IsA("BasePart") and target.Anchored) then
		return
	end
	self._lifting[target] = true
	local original = if isModel then (target :: Model):GetPivot() else (target :: BasePart).CFrame
	local function place(cframe: CFrame)
		if isModel then
			(target :: Model):PivotTo(cframe)
		else
			(target :: BasePart).CFrame = cframe
		end
	end
	animate(LIFT_SECONDS, function(alpha)
		local lift = math.sin(alpha * math.pi)
		place(original * CFrame.new(0, 0.18 * lift, 0) * CFrame.Angles(math.rad(4) * lift, 0, 0))
	end, function()
		place(original)
		self._lifting[target] = nil
	end)
end

function InteractionFeedback:_pulse(target: Instance)
	local glow = Instance.new("Highlight")
	glow.Name = "IgnitePulse"
	glow.Adornee = target
	glow.FillColor = HIGHLIGHT_COLOR
	glow.FillTransparency = 0.75
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = target
	local tween = TweenService:Create(glow, PULSE, { FillTransparency = 1 })
	tween.Completed:Connect(function()
		glow:Destroy()
	end)
	tween:Play()
end

local function ghostParts(ghost: Model): { [BasePart]: number }
	local parts = {}
	for _, descendant in ghost:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts[descendant] = descendant.Transparency
		end
	end
	return parts
end

-- The item rises a little, turns and fades away.
function InteractionFeedback:_collect(ghost: Model)
	local start = ghost:GetPivot()
	local parts = ghostParts(ghost)
	ghost.Parent = workspace
	animate(COLLECT_SECONDS, function(alpha)
		local eased = easeOut(alpha)
		ghost:PivotTo(start * CFrame.new(0, 1.1 * eased, 0) * CFrame.Angles(0, math.rad(200) * eased, 0))
		for part, transparency in parts do
			part.Transparency = transparency + (1 - transparency) * alpha * alpha
		end
	end, function()
		self:sparkle(start.Position + Vector3.new(0, 1.1, 0))
		ghost:Destroy()
	end)
end

-- The item arcs into the backpack, which gives a small bump.
function InteractionFeedback:_pack(prompt: ProximityPrompt, ghost: Model)
	local link = prompt:FindFirstChild("PackInto")
	local bag = link and link:IsA("ObjectValue") and link.Value
	local start = ghost:GetPivot()
	local goal = if bag and bag:IsA("BasePart") then bag.Position + Vector3.new(0, 0.5, 0) else start.Position + Vector3.new(0, 1, 0)
	local parts = ghostParts(ghost)
	local ok, startScale = pcall(function()
		return ghost:GetScale()
	end)
	ghost.Parent = workspace
	animate(PACK_SECONDS, function(alpha)
		local eased = easeInOut(alpha)
		local position = start.Position:Lerp(goal, eased) + Vector3.new(0, math.sin(alpha * math.pi) * 1.6, 0)
		ghost:PivotTo(CFrame.new(position) * start.Rotation * CFrame.Angles(0, math.rad(90) * eased, 0))
		if ok then
			pcall(function()
				ghost:ScaleTo(startScale * (1 - 0.55 * eased))
			end)
		end
		if alpha > 0.8 then
			local fade = (alpha - 0.8) / 0.2
			for part, transparency in parts do
				part.Transparency = transparency + (1 - transparency) * fade
			end
		end
	end, function()
		ghost:Destroy()
		self:cue("land")
		if bag and bag:IsA("BasePart") then
			local bagModel = bag.Parent
			self:_lift(if bagModel and bagModel:IsA("Model") then bagModel else bag)
		end
	end)
end

-- A few slow, soft sparkles at a position (item collected).
function InteractionFeedback:sparkle(position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.0)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(HIGHLIGHT_COLOR)
	emitter.LightEmission = 0.3
	emitter.Drag = 3
	emitter.Parent = attachment
	emitter:Emit(10)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

return InteractionFeedback
