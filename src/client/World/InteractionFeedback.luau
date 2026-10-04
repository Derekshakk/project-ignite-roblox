--[[
	InteractionFeedback

	Subtle, local feedback for interactable objects:
	- a soft outline while an object's prompt is shown (Settings: highlights)
	- when used: a quiet click and a short response chosen by the prompt's
	  Feedback attribute:
	      "lift"   small objects lift slightly and settle back
	      "pulse"  (default) a gentle glow that fades out
	      "none"   no visual response
	- prompts with an "AnimatedDoor" ObjectValue swing that door open briefly
	- a few soft sparkles when an item is collected
	No flashing: every effect is a single fade or ease.
]]

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Settings = require(script.Parent.Parent.Settings)
local Doors = require(script.Parent.Doors)

-- Built-in Roblox sound (ships with every client).
local USE_SOUND_ID = "rbxasset://sounds/volume_slider.ogg"
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 214, 150)
local LIFT = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local InteractionFeedback = {}
InteractionFeedback.__index = InteractionFeedback

function InteractionFeedback.new()
	local sound = Instance.new("Sound")
	sound.Name = "IgniteUse"
	sound.SoundId = USE_SOUND_ID
	sound.Volume = 0.35
	sound.Parent = SoundService

	return setmetatable({
		_sound = sound,
		_highlights = {} :: { [ProximityPrompt]: Highlight },
		_lifting = {} :: { [BasePart]: boolean },
	}, InteractionFeedback)
end

-- The object a prompt belongs to: a pickup's whole model, or the part.
local function targetOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and parent.Parent and parent.Parent:IsA("Model") and parent.Parent:GetAttribute("PickupItemId") then
		return parent.Parent
	end
	return parent
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

-- Called after an interaction succeeds.
function InteractionFeedback:play(prompt: ProximityPrompt)
	SoundService:PlayLocalSound(self._sound)

	local door = prompt:FindFirstChild("AnimatedDoor")
	if door and door:IsA("ObjectValue") and door.Value and door.Value:IsA("BasePart") then
		Doors.pulse(door.Value, 2.5)
	end

	local style = prompt:GetAttribute(World.Attributes.Feedback) or "pulse"
	local target = targetOf(prompt)
	if style == "lift" and target and target:IsA("BasePart") then
		self:_lift(target)
	elseif style == "pulse" and target then
		self:_pulse(target)
	end
end

function InteractionFeedback:_lift(part: BasePart)
	if self._lifting[part] or not part.Anchored then
		return
	end
	self._lifting[part] = true
	local original = part.CFrame
	local tween = TweenService:Create(part, LIFT, { CFrame = original * CFrame.new(0, 0.18, 0) * CFrame.Angles(math.rad(4), 0, 0) })
	tween.Completed:Connect(function()
		part.CFrame = original
		self._lifting[part] = nil
	end)
	tween:Play()
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
