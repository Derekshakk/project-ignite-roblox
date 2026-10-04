--[[
	ObjectiveTracker

	Small pill at the top centre showing what to do next in the day.
]]

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local px = Components.px

local ObjectiveTracker = {}
ObjectiveTracker.__index = ObjectiveTracker

function ObjectiveTracker.new(parent: Instance, ctx)
	local frame = Components.create("Frame", {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, ctx.topInset + px(ctx, 12)),
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
		PaddingLeft = UDim.new(0, px(ctx, 18)),
		PaddingRight = UDim.new(0, px(ctx, 18)),
	}, frame)
	Components.listLayout(frame, ctx, { gap = 2, horizontalAlignment = Enum.HorizontalAlignment.Center })

	local function label(name: string, size: string, font: string, color: Color3)
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
	label("Caption", "Caption", "Bold", Colors.Accent).Text = "OBJECTIVE"
	local text = label("Text", "Body", "Medium", Colors.Text)

	return setmetatable({ _frame = frame, _text = text }, ObjectiveTracker)
end

function ObjectiveTracker:set(text: string?, visible: boolean)
	self._text.Text = text or ""
	self._frame.Visible = visible and text ~= nil
end

function ObjectiveTracker:destroy()
	self._frame:Destroy()
end

return ObjectiveTracker
