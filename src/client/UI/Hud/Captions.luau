--[[
	Captions

	Subtitles near the bottom of the screen. Spoken lines normally appear in
	speech bubbles over the NPC (World/NpcSpeech); SceneDirector also shows
	a line here when its speaker is off-screen, and clears it as soon as
	the line ends or the scene moves on (so it can never sit on top of the
	choice panel). Lines fade in and out; nothing flashes. Each caption has
	a `source` so one scene can stop its own captions without clearing
	another's. Hidden when Settings "Captions" is off.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local Settings = require(script.Parent.Parent.Parent.Settings)

local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local Captions = {}
Captions.__index = Captions

function Captions.new(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IgniteCaptions"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.IgnoreGuiInset = true

	local group = Instance.new("CanvasGroup")
	group.Name = "Caption"
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.fromScale(0.5, 0.86)
	group.Size = UDim2.fromScale(0.6, 0)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.BackgroundColor3 = Theme.Colors.Background
	group.BackgroundTransparency = 0.2
	group.GroupTransparency = 1
	-- Hidden for real while no line is shown (not only faded out), so an
	-- empty caption bar can never appear on screen.
	group.Visible = false
	group.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(820, math.huge)
	constraint.Parent = group
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = group
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
	padding.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = group

	local function label(name: string, order: number, font: Enum.Font, color: Color3)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.LayoutOrder = order
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 0)
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Font = font
		text.Text = ""
		text.TextColor3 = color
		text.Parent = group
		return text
	end
	local speaker = label("Speaker", 1, Theme.Fonts.Bold, Theme.Colors.Accent)
	local line = label("Line", 2, Theme.Fonts.Medium, Theme.Colors.Text)

	gui.Parent = playerGui
	return setmetatable({
		_group = group,
		_speaker = speaker,
		_line = line,
		_token = 0,
		_source = nil :: string?,
	}, Captions)
end

local function textSize(): (number, number)
	local camera = workspace.CurrentCamera
	local scale = if camera then math.clamp(camera.ViewportSize.Y / 900, 0.75, 1.4) else 1
	return math.floor(15 * scale), math.floor(19 * scale)
end

-- Shows one line for `seconds`.
function Captions:show(speakerName: string, text: string, seconds: number, source: string?)
	if not Settings.get("captions") then
		return
	end
	self._token += 1
	local token = self._token
	self._source = source
	local small, large = textSize()
	self._speaker.TextSize = small
	self._line.TextSize = large
	self._speaker.Text = string.upper(speakerName)
	self._line.Text = text
	self._group.Visible = true
	TweenService:Create(self._group, FADE, { GroupTransparency = 0 }):Play()
	task.delay(seconds, function()
		if self._token == token then
			self:_hide()
		end
	end)
end

-- Stops captions (only those from `source`, if given).
function Captions:stop(source: string?)
	if source and self._source ~= source then
		return
	end
	self._token += 1
	self:_hide()
end

function Captions:_hide()
	self._source = nil
	local token = self._token
	local tween = TweenService:Create(self._group, FADE, { GroupTransparency = 1 })
	tween.Completed:Connect(function()
		-- Only if no new line started while fading out.
		if self._token == token then
			self._group.Visible = false
			self._speaker.Text = ""
			self._line.Text = ""
		end
	end)
	tween:Play()
end

return Captions
