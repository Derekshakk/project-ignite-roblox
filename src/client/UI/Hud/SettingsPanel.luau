--[[
	SettingsPanel

	A small "Settings (P)" button in the bottom-left corner and a compact
	panel of on/off toggles for optional effects (see client/Settings).
	P also opens it, so it works in first person when the mouse is locked;
	panel buttons are Modal so the mouse is freed while it's open.
]]

local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)
local Settings = require(script.Parent.Parent.Parent.Settings)

local Colors = Theme.Colors
local Spacing = Theme.Spacing
local px = Components.px

local TOGGLE_KEY = Enum.KeyCode.P

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

function SettingsPanel.new(parent: Instance, ctx)
	local self = setmetatable({ _open = false, _buttons = {} }, SettingsPanel)

	local openButton = Components.button(parent, ctx, {
		name = "SettingsButton",
		text = "Settings (P)",
		variant = "secondary",
		textSize = "Caption",
		width = UDim.new(0, px(ctx, 130)),
		onActivated = function()
			self:setOpen(not self._open)
		end,
	})
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.new(0, px(ctx, 16), 1, -px(ctx, 16))
	openButton.BackgroundTransparency = 0.15
	self._openButton = openButton

	local panel = Components.panel(parent, ctx, { name = "SettingsPanel", width = UDim.new(0, px(ctx, 300)), gap = Spacing.Small })
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, px(ctx, 16), 1, -px(ctx, 70))
	panel.Visible = false
	self._panel = panel
	Components.text(panel, ctx, "Settings", { size = "Subheading", font = "Bold" })
	Components.text(panel, ctx, "Turn optional effects on or off.", { size = "Caption", color = Colors.TextMuted })

	for _, definition in Settings.Definitions do
		local button = Components.button(panel, ctx, {
			name = definition.key,
			text = "",
			subtext = definition.description,
			variant = "secondary",
			textSize = "Body",
			align = Enum.TextXAlignment.Left,
			modal = true,
			onActivated = function()
				Settings.toggle(definition.key)
			end,
		})
		self._buttons[definition.key] = { button = button, label = definition.label }
	end
	Components.button(panel, ctx, {
		name = "Close",
		text = "Close",
		variant = "primary",
		textSize = "Caption",
		modal = true,
		onActivated = function()
			self:setOpen(false)
		end,
	})

	self._connections = {
		Settings.Changed:Connect(function()
			self:_refresh()
		end),
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == TOGGLE_KEY then
				self:setOpen(not self._open)
			end
		end),
	}
	self:_refresh()
	return self
end

function SettingsPanel:setOpen(open: boolean)
	self._open = open
	self._panel.Visible = open
end

function SettingsPanel:_refresh()
	for key, entry in self._buttons do
		local label = entry.button:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = `{entry.label}: {if Settings.get(key) then "On" else "Off"}`
		end
	end
end

function SettingsPanel:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._openButton:Destroy()
	self._panel:Destroy()
end

return SettingsPanel
