--[[
	Toasts

	Short, non-blocking notifications below the objective (e.g. "The hallway
	is packed and loud…"). They fade in, stay for a few seconds and fade out.
	At most a few are shown at once.
]]

local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local Spacing = Theme.Spacing
local px = Components.px

local MAX_VISIBLE = 3
local DISPLAY_SECONDS = 6
local FADE = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local Toasts = {}
Toasts.__index = Toasts

function Toasts.new(parent: Instance, ctx)
	local container = Components.stack(parent, ctx, {
		name = "Toasts",
		width = if ctx.compact then UDim.new(0.9, 0) else UDim.new(0.36, 0),
		gap = Spacing.Small,
		horizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, ctx.topInset + px(ctx, 84))
	Components.create("UISizeConstraint", { MaxSize = Vector2.new(px(ctx, 520), math.huge) }, container)

	return setmetatable({ _ctx = ctx, _container = container, _items = {} }, Toasts)
end

function Toasts:_remove(item: CanvasGroup)
	local index = table.find(self._items, item)
	if not index then
		return
	end
	table.remove(self._items, index)
	local tween = TweenService:Create(item, FADE, { GroupTransparency = 1 })
	tween.Completed:Connect(function()
		item:Destroy()
	end)
	tween:Play()
end

-- notification: { title: string?, message: string, changes: { MeterChange }? }
function Toasts:push(notification)
	local ctx = self._ctx
	local item = Components.create("CanvasGroup", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		GroupTransparency = 1,
	}, self._container)
	local panel = Components.panel(item, ctx, { name = "Panel", padding = Spacing.Medium, gap = Spacing.Small })
	panel.BackgroundTransparency = 0.1
	if notification.title then
		Components.text(panel, ctx, string.upper(notification.title), { size = "Caption", font = "Bold", color = Colors.Accent })
	end
	Components.text(panel, ctx, notification.message, { size = "Body" })
	Components.changeChips(panel, ctx, notification.changes)

	table.insert(self._items, item)
	TweenService:Create(item, FADE, { GroupTransparency = 0 }):Play()
	while #self._items > MAX_VISIBLE do
		self:_remove(self._items[1])
	end
	task.delay(DISPLAY_SECONDS, function()
		if item.Parent then
			self:_remove(item)
		end
	end)
end

function Toasts:destroy()
	self._container:Destroy()
	table.clear(self._items)
end

return Toasts
