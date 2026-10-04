--[[
	Components

	Reusable UI building blocks. Screens compose these instead of building
	Instances by hand, so styling and layout rules live in one place.

	Layout approach: widths use Scale (fractions of the parent), heights grow
	with content via AutomaticSize, and all pixel values (text size, padding)
	go through Components.px so they scale with the window. Children are
	ordered by creation order through LayoutOrder.

	Every builder takes `ctx` = { scale: number, compact: boolean, topInset: number }.
]]

local Meters = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Constants.Meters)
local Theme = require(script.Parent.Theme)

local Colors = Theme.Colors
local Spacing = Theme.Spacing

local Components = {}

export type Context = {
	scale: number,
	compact: boolean,
	topInset: number,
}

function Components.px(ctx: Context, designPixels: number): number
	return math.floor(designPixels * ctx.scale + 0.5)
end
local px = Components.px

local NEXT_ORDER_ATTRIBUTE = "NextLayoutOrder"

local function nextLayoutOrder(parent: Instance): number
	local order = (parent:GetAttribute(NEXT_ORDER_ATTRIBUTE) or 0) + 1
	parent:SetAttribute(NEXT_ORDER_ATTRIBUTE, order)
	return order
end

-- Creates an Instance, applies properties, and parents it last. GuiObjects
-- get an automatic LayoutOrder so list layouts follow creation order.
function Components.create(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
	if parent then
		if instance:IsA("GuiObject") and (props == nil or props.LayoutOrder == nil) then
			instance.LayoutOrder = nextLayoutOrder(parent)
		end
		instance.Parent = parent
	end
	return instance
end
local create = Components.create

function Components.listLayout(parent: Instance, ctx: Context, options: { [string]: any }?)
	options = options or {}
	return create("UIListLayout", {
		FillDirection = options.direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = options.horizontalAlignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = options.verticalAlignment or Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, px(ctx, options.gap or Spacing.Medium)),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = options.wraps or false,
	}, parent)
end

function Components.padding(parent: Instance, ctx: Context, all: number)
	local value = UDim.new(0, px(ctx, all))
	return create("UIPadding", {
		PaddingTop = value,
		PaddingBottom = value,
		PaddingLeft = value,
		PaddingRight = value,
	}, parent)
end

function Components.corner(parent: Instance, ctx: Context, radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, px(ctx, radius or Theme.CornerRadius)) }, parent)
end

-- Transparent vertical container that grows to fit its children.
function Components.stack(parent: Instance, ctx: Context, options: { [string]: any }?)
	options = options or {}
	local frame = create("Frame", {
		Name = options.name or "Stack",
		BackgroundTransparency = 1,
		Size = UDim2.new(options.width or UDim.new(1, 0), UDim.new(0, 0)),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	Components.listLayout(frame, ctx, options)
	return frame
end

-- Rounded, padded card that grows to fit its children.
function Components.panel(parent: Instance, ctx: Context, options: { [string]: any }?)
	options = options or {}
	local frame = create("Frame", {
		Name = options.name or "Panel",
		BackgroundColor3 = options.color or Colors.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(options.width or UDim.new(1, 0), UDim.new(0, 0)),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	Components.corner(frame, ctx)
	create("UIStroke", { Color = Colors.Stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	Components.padding(frame, ctx, options.padding or Spacing.Large)
	Components.listLayout(frame, ctx, { gap = options.gap or Spacing.Medium })
	return frame
end

-- Full-screen scrolling page with a centered, width-limited content column.
-- Returns the content column; screens add their sections to it.
function Components.page(parent: Instance, ctx: Context, name: string)
	local scroller = create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = px(ctx, 8),
		ScrollBarImageColor3 = Colors.Stroke,
	}, parent)
	create("UIPadding", {
		PaddingTop = UDim.new(0, ctx.topInset + px(ctx, Spacing.Page)),
		PaddingBottom = UDim.new(0, px(ctx, Spacing.Page)),
	}, scroller)
	Components.listLayout(scroller, ctx, { horizontalAlignment = Enum.HorizontalAlignment.Center })

	local gutter = px(ctx, Spacing.Page)
	local content = Components.stack(scroller, ctx, {
		name = "Content",
		width = UDim.new(1, -2 * gutter),
		gap = Spacing.Large,
	})
	create("UISizeConstraint", { MaxSize = Vector2.new(px(ctx, Theme.MaxContentWidth), math.huge) }, content)
	return content
end

-- Wrapping text label that grows vertically to fit its text.
-- options: size ("Body" | "Title" | ...), font ("Regular" | "Medium" | "Bold"),
-- color, align (Enum.TextXAlignment), richText, name
function Components.text(parent: Instance, ctx: Context, text: string, options: { [string]: any }?)
	options = options or {}
	return create("TextLabel", {
		Name = options.name or "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(options.width or UDim.new(1, 0), UDim.new(0, 0)),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		RichText = options.richText or false,
		TextWrapped = true,
		TextXAlignment = options.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Fonts[options.font or "Regular"],
		TextSize = px(ctx, Theme.TextSizes[options.size or "Body"]),
		TextColor3 = options.color or Colors.Text,
	}, parent)
end

function Components.bulletList(parent: Instance, ctx: Context, items: { string })
	local list = Components.stack(parent, ctx, { name = "BulletList", gap = Spacing.Small })
	for _, item in items do
		Components.text(list, ctx, "•  " .. item, { color = Colors.TextMuted })
	end
	return list
end

-- Titled group used on character cards ("Strengths", "Burnout triggers", ...).
function Components.labeledList(parent: Instance, ctx: Context, title: string, items: { string })
	local group = Components.stack(parent, ctx, { name = title, gap = Spacing.Small })
	Components.text(group, ctx, title, { size = "Caption", font = "Bold", color = Colors.Accent })
	Components.bulletList(group, ctx, items)
	return group
end

local VARIANTS = {
	primary = { color = Colors.ButtonPrimary, textColor = Colors.ButtonPrimaryText },
	secondary = { color = Colors.ButtonSecondary, textColor = Colors.ButtonSecondaryText },
}

local DISABLED_ATTRIBUTE = "Disabled"

--[[
	Button with optional supporting text underneath the main label.
	options:
		text: string
		subtext: string?
		variant: "primary" | "secondary"
		width: UDim?
		align: Enum.TextXAlignment?
		textSize: string?       Theme.TextSizes key for the label (default "Subheading")
		modal: boolean?         frees the mouse in first person while visible
		onActivated: () -> ()   called only while the button is enabled

	Buttons do not contain game logic; screens pass in a callback that calls
	an action on the GameController.
]]
function Components.button(parent: Instance, ctx: Context, options: { [string]: any })
	local variant = VARIANTS[options.variant or "primary"] or VARIANTS.primary
	local align = options.align or Enum.TextXAlignment.Center

	local button = create("TextButton", {
		Name = options.name or "Button",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = variant.color,
		BorderSizePixel = 0,
		Size = UDim2.new(options.width or UDim.new(1, 0), UDim.new(0, 0)),
		AutomaticSize = Enum.AutomaticSize.Y,
		Modal = options.modal or false,
	}, parent)
	button:SetAttribute("BaseColor", variant.color)
	Components.corner(button, ctx, 8)
	Components.padding(button, ctx, Spacing.Medium)
	Components.listLayout(button, ctx, { gap = 4 })

	Components.text(button, ctx, options.text, {
		name = "Label",
		font = "Bold",
		size = options.textSize or "Subheading",
		color = variant.textColor,
		align = align,
	})
	if options.subtext and options.subtext ~= "" then
		Components.text(button, ctx, options.subtext, {
			name = "Subtext",
			size = "Caption",
			color = variant.textColor:Lerp(variant.color, 0.3),
			align = align,
		})
	end

	button.Activated:Connect(function()
		if button:GetAttribute(DISABLED_ATTRIBUTE) then
			return
		end
		if options.onActivated then
			options.onActivated()
		end
	end)
	return button
end

function Components.setButtonEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute(DISABLED_ATTRIBUTE, not enabled)
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then button:GetAttribute("BaseColor") or Colors.ButtonSecondary
		else Colors.ButtonDisabled
end

function Components.formatDelta(delta: number): string
	if delta > 0 then
		return "+" .. delta
	end
	return tostring(delta)
end
local formatDelta = Components.formatDelta

-- Wrapping row of small "Stress +4" chips for the meters that changed.
-- Returns nil when nothing changed.
function Components.changeChips(parent: Instance, ctx: Context, changes: { any }?)
	local moved = {}
	for _, change in changes or {} do
		if change.delta ~= 0 then
			table.insert(moved, change)
		end
	end
	if #moved == 0 then
		return nil
	end

	local row = create("Frame", {
		Name = "Changes",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	Components.listLayout(row, ctx, { direction = Enum.FillDirection.Horizontal, gap = Spacing.Small, wraps = true })
	for _, change in moved do
		local definition = Meters.get(change.id)
		local chip = create("TextLabel", {
			Name = change.id,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),
			BackgroundColor3 = Colors.PanelAlt,
			Font = Theme.Fonts.Medium,
			TextSize = px(ctx, Theme.TextSizes.Caption),
			TextColor3 = if change.delta > 0 then Colors.ChangeUp else Colors.ChangeDown,
			Text = `{definition and definition.label or change.id} {formatDelta(change.delta)}`,
		}, row)
		Components.corner(chip, ctx, 6)
		create("UIPadding", {
			PaddingTop = UDim.new(0, px(ctx, 4)),
			PaddingBottom = UDim.new(0, px(ctx, 4)),
			PaddingLeft = UDim.new(0, px(ctx, 8)),
			PaddingRight = UDim.new(0, px(ctx, 8)),
		}, chip)
	end
	return row
end

-- Compact panel anchored to the bottom centre of the screen, used for
-- in-world dialogs so the 3D scene stays visible above it.
function Components.dialog(parent: Instance, ctx: Context, name: string)
	local width = if ctx.compact then UDim.new(1, -px(ctx, 24)) else UDim.new(0.72, 0)
	local panel = Components.panel(parent, ctx, { name = name, width = width, gap = Spacing.Medium })
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -px(ctx, 20))
	panel.BackgroundTransparency = 0.04
	create("UISizeConstraint", { MaxSize = Vector2.new(px(ctx, 1000), math.huge) }, panel)
	return panel
end

-- One labelled meter bar. `delta` (optional) shows how much it just changed.
function Components.meterBar(parent: Instance, ctx: Context, definition: Meters.MeterDefinition, value: number, delta: number?)
	local container = Components.stack(parent, ctx, { name = definition.id, gap = 4 })

	local valueText = tostring(value)
	if delta and delta ~= 0 then
		local color = if delta > 0 then Colors.ChangeUp else Colors.ChangeDown
		valueText = `<font color="#{color:ToHex()}">({formatDelta(delta)})</font>  {value}`
	end

	local header = create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, container)
	Components.text(header, ctx, definition.label, {
		name = "Label",
		font = "Medium",
		width = UDim.new(0.6, 0),
	})
	local valueLabel = Components.text(header, ctx, valueText, {
		name = "Value",
		font = "Bold",
		richText = true,
		align = Enum.TextXAlignment.Right,
		width = UDim.new(0.4, 0),
	})
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.fromScale(1, 0)

	local track = create("Frame", {
		Name = "Track",
		BackgroundColor3 = Colors.MeterTrack,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, px(ctx, 10)),
	}, container)
	Components.corner(track, ctx, 5)
	local fill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = if definition.strainWhenHigh then Colors.MeterStrain else Colors.MeterCapacity,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(value / Meters.MAX, 0, 1), 1),
	}, track)
	Components.corner(fill, ctx, 5)

	return container
end

--[[
	Panel listing every meter in display order.
	options:
		title: string
		deltas: { [meterId]: number }?   change to display next to each value
]]
function Components.meterPanel(parent: Instance, ctx: Context, meters: Meters.MeterValues, options: { [string]: any }?)
	options = options or {}
	local panel = Components.panel(parent, ctx, { name = "Meters", width = options.width, gap = Spacing.Medium })
	if options.title then
		Components.text(panel, ctx, options.title, { size = "Subheading", font = "Bold" })
	end
	for _, definition in Meters.List do
		local deltas = options.deltas
		Components.meterBar(panel, ctx, definition, meters[definition.id] or 0, deltas and deltas[definition.id])
	end
	return panel
end

-- Two columns side by side on wide screens, stacked on compact screens.
-- Returns (row, leftColumn, rightColumn).
function Components.columns(parent: Instance, ctx: Context, leftFraction: number)
	local gap = px(ctx, Spacing.Large)
	local row = create("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	create("UIListLayout", {
		FillDirection = if ctx.compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

	local leftWidth = if ctx.compact then UDim.new(1, 0) else UDim.new(leftFraction, -gap / 2)
	local rightWidth = if ctx.compact then UDim.new(1, 0) else UDim.new(1 - leftFraction, -gap / 2)
	local left = Components.stack(row, ctx, { name = "Left", width = leftWidth, gap = Spacing.Large })
	local right = Components.stack(row, ctx, { name = "Right", width = rightWidth, gap = Spacing.Large })
	return row, left, right
end

return Components
