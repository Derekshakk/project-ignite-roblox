--[[
	Transitions

	Gentle screen transitions: a soft fade to dark and back around travel
	(about a third of a second each way, never a sudden cut or flash), and
	a short area title when entering a new area.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local FADE_OUT = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local FADE_IN = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TITLE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TITLE_OUT = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local TITLE_HOLD = 1.6

local Transitions = {}
Transitions.__index = Transitions

function Transitions.new(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IgniteTransitions"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50

	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Theme.Colors.Background
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "AreaTitle"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.28)
	title.Size = UDim2.fromScale(0.6, 0.06)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Bold
	title.TextScaled = true
	title.TextColor3 = Theme.Colors.Text
	title.TextTransparency = 1
	title.Parent = gui
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 34
	constraint.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Background
	stroke.Transparency = 1
	stroke.Thickness = 1.5
	stroke.Parent = title

	gui.Parent = playerGui
	return setmetatable({ _fade = fade, _title = title, _stroke = stroke, _titleToken = 0 }, Transitions)
end

-- Fades to dark; yields until done.
function Transitions:fadeOut()
	local tween = TweenService:Create(self._fade, FADE_OUT, { BackgroundTransparency = 0 })
	tween:Play()
	tween.Completed:Wait()
end

function Transitions:fadeIn()
	TweenService:Create(self._fade, FADE_IN, { BackgroundTransparency = 1 }):Play()
end

function Transitions:showAreaTitle(text: string)
	self._titleToken += 1
	local token = self._titleToken
	self._title.Text = text
	TweenService:Create(self._title, TITLE_IN, { TextTransparency = 0.05 }):Play()
	TweenService:Create(self._stroke, TITLE_IN, { Transparency = 0.5 }):Play()
	task.delay(TITLE_HOLD, function()
		if self._titleToken == token then
			TweenService:Create(self._title, TITLE_OUT, { TextTransparency = 1 }):Play()
			TweenService:Create(self._stroke, TITLE_OUT, { Transparency = 1 }):Play()
		end
	end)
end

return Transitions
