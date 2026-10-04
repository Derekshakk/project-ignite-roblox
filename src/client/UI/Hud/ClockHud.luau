--[[
	ClockHud

	Compact time-of-day pill in the top-left corner ("DAY 1 · 8:15 AM"),
	so the player always knows where they are in the school day. When the
	time moves on, the new time eases from the accent colour back to the
	normal text colour once (no blinking).
]]

local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local px = Components.px

local SETTLE = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local ClockHud = {}
ClockHud.__index = ClockHud

function ClockHud.new(parent: Instance, ctx, day: number)
	local frame = Components.create("Frame", {
		Name = "Clock",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, px(ctx, 16), 0, ctx.topInset + px(ctx, 12)),
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, parent)
	Components.corner(frame, ctx, 14)
	Components.create("UIPadding", {
		PaddingTop = UDim.new(0, px(ctx, 8)),
		PaddingBottom = UDim.new(0, px(ctx, 8)),
		PaddingLeft = UDim.new(0, px(ctx, 14)),
		PaddingRight = UDim.new(0, px(ctx, 14)),
	}, frame)
	Components.listLayout(frame, ctx, { gap = 2 })

	local function label(name: string, size: string, font: string, color: Color3): TextLabel
		return Components.create("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = Theme.Fonts[font],
			TextSize = px(ctx, Theme.TextSizes[size]),
			TextColor3 = color,
			Text = "",
		}, frame)
	end
	label("Day", "Caption", "Bold", Colors.Accent).Text = `DAY {day}`
	local time = label("Time", "Subheading", "Bold", Colors.Text)

	return setmetatable({ _frame = frame, _time = time }, ClockHud)
end

function ClockHud:set(text: string?, animate: boolean?)
	local changed = text ~= nil and text ~= self._time.Text
	self._time.Text = text or ""
	self._frame.Visible = text ~= nil
	if changed and animate then
		self._time.TextColor3 = Colors.Accent
		TweenService:Create(self._time, SETTLE, { TextColor3 = Colors.Text }):Play()
	end
end

function ClockHud:destroy()
	self._frame:Destroy()
end

return ClockHud
