--[[
	MeterHud

	Compact, always-visible status panel in the top-right corner. Primary
	meters (Constants/Meters `primary`) are always shown; the rest sit behind
	a "More" toggle. Below the meters, small indicators show active items
	(e.g. "Headphones on"). Values update in place when meters change: bars ease to
	their new length and a small delta ("+4") fades in and out next to the
	value, with a soft row highlight. No flashing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Meters = require(ReplicatedStorage:WaitForChild("Shared").Constants.Meters)
local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local Spacing = Theme.Spacing
local px = Components.px

local BAR_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Fade out after a short hold (the 6th argument is the delay).
local DELTA_FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 2.5)
local HIGHLIGHT_FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local MeterHud = {}
MeterHud.__index = MeterHud

local function buildRow(parent: Instance, ctx, definition)
	local row = Components.stack(parent, ctx, { name = definition.id, gap = 3 })
	row.BackgroundColor3 = Colors.PanelAlt
	Components.corner(row, ctx, 6)

	local header = Components.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, row)
	Components.text(header, ctx, definition.label, { name = "Label", size = "Caption", font = "Medium", width = UDim.new(0.6, 0) })
	local deltaLabel = Components.text(header, ctx, "", {
		name = "Delta",
		size = "Caption",
		font = "Bold",
		align = Enum.TextXAlignment.Right,
		width = UDim.new(0.2, 0),
	})
	deltaLabel.Position = UDim2.fromScale(0.6, 0)
	deltaLabel.TextTransparency = 1
	local valueLabel = Components.text(header, ctx, "", {
		name = "Value",
		size = "Caption",
		font = "Bold",
		align = Enum.TextXAlignment.Right,
		width = UDim.new(0.2, 0),
	})
	valueLabel.Position = UDim2.fromScale(0.8, 0)

	local track = Components.create("Frame", {
		Name = "Track",
		BackgroundColor3 = Colors.MeterTrack,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, px(ctx, 6)),
	}, row)
	Components.corner(track, ctx, 3)
	local fill = Components.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = if definition.strainWhenHigh then Colors.MeterStrain else Colors.MeterCapacity,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, track)
	Components.corner(fill, ctx, 3)

	return { row = row, fill = fill, valueLabel = valueLabel, deltaLabel = deltaLabel }
end

function MeterHud.new(parent: Instance, ctx, character, meters)
	local self = setmetatable({
		characterId = character.id,
		_rows = {},
		_expanded = false,
	}, MeterHud)

	local panel = Components.panel(parent, ctx, {
		name = "MeterHud",
		width = UDim.new(0.2, 0),
		padding = Spacing.Medium,
		gap = Spacing.Small,
	})
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -px(ctx, 16), 0, ctx.topInset + px(ctx, 16))
	panel.BackgroundTransparency = 0.12
	Components.create("UISizeConstraint", {
		MinSize = Vector2.new(px(ctx, 220), 0),
		MaxSize = Vector2.new(px(ctx, 290), math.huge),
	}, panel)
	self._panel = panel

	-- Header: character name + expand toggle.
	local header = Components.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, panel)
	Components.text(header, ctx, character.name, { size = "Subheading", font = "Bold", width = UDim.new(0.55, 0) })
	self._toggle = Components.button(header, ctx, {
		name = "Toggle",
		text = "More",
		variant = "secondary",
		textSize = "Caption",
		width = UDim.new(0.42, 0),
		onActivated = function()
			self:setExpanded(not self._expanded)
		end,
	})
	self._toggle.AnchorPoint = Vector2.new(1, 0)
	self._toggle.Position = UDim2.fromScale(1, 0)
	self._toggleLabel = self._toggle:FindFirstChild("Label") :: TextLabel

	for _, definition in Meters.List do
		if definition.primary then
			self._rows[definition.id] = buildRow(panel, ctx, definition)
		end
	end
	self._secondary = Components.stack(panel, ctx, { name = "Secondary", gap = Spacing.Small })
	self._secondary.Visible = false
	for _, definition in Meters.List do
		if not definition.primary then
			self._rows[definition.id] = buildRow(self._secondary, ctx, definition)
		end
	end

	self._indicators = Components.create("Frame", {
		Name = "Indicators",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, panel)
	Components.listLayout(self._indicators, ctx, {
		direction = Enum.FillDirection.Horizontal,
		gap = Spacing.Small,
		wraps = true,
	})
	self._ctx = ctx

	self:update(meters, nil, true)
	return self
end

-- Small pills for active item effects, e.g. { "Headphones on" }.
function MeterHud:setIndicators(labels: { string })
	for _, child in self._indicators:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local ctx = self._ctx
	for _, text in labels do
		local pill = Components.create("TextLabel", {
			Name = "Indicator",
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),
			BackgroundColor3 = Colors.MeterCapacity:Lerp(Colors.Panel, 0.55),
			Font = Theme.Fonts.Bold,
			TextSize = px(ctx, Theme.TextSizes.Caption),
			TextColor3 = Colors.Text,
			Text = text,
		}, self._indicators)
		Components.corner(pill, ctx, 8)
		Components.create("UIPadding", {
			PaddingTop = UDim.new(0, px(ctx, 3)),
			PaddingBottom = UDim.new(0, px(ctx, 3)),
			PaddingLeft = UDim.new(0, px(ctx, 8)),
			PaddingRight = UDim.new(0, px(ctx, 8)),
		}, pill)
	end
	self._indicators.Visible = #labels > 0
end

function MeterHud:setExpanded(expanded: boolean)
	self._expanded = expanded
	self._secondary.Visible = expanded
	self._toggleLabel.Text = if expanded then "Less" else "More"
end

--[[
	Updates values. `changes` (optional) is a list of MeterChange records;
	changed meters get a fading delta and highlight. `instant` skips easing.
]]
function MeterHud:update(meters, changes, instant: boolean?)
	if not meters then
		return
	end
	for id, row in self._rows do
		local value = meters[id] or 0
		row.valueLabel.Text = tostring(value)
		local size = UDim2.fromScale(math.clamp(value / Meters.MAX, 0, 1), 1)
		if instant then
			row.fill.Size = size
		else
			TweenService:Create(row.fill, BAR_TWEEN, { Size = size }):Play()
		end
	end

	for _, change in changes or {} do
		local row = self._rows[change.id]
		if row and change.delta ~= 0 then
			row.deltaLabel.Text = Components.formatDelta(change.delta)
			row.deltaLabel.TextColor3 = if change.delta > 0 then Colors.ChangeUp else Colors.ChangeDown
			row.deltaLabel.TextTransparency = 0
			TweenService:Create(row.deltaLabel, DELTA_FADE, { TextTransparency = 1 }):Play()

			row.row.BackgroundTransparency = 0.35
			TweenService:Create(row.row, HIGHLIGHT_FADE, { BackgroundTransparency = 1 }):Play()
		end
	end
end

function MeterHud:destroy()
	self._panel:Destroy()
end

return MeterHud
