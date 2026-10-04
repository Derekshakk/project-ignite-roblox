--[[
	TaskGuide

	Small widget near the bottom of the screen for guided tasks (breathing,
	stretching, waiting for the crowd): a soft circle that fills as the
	step progresses, a one-line instruction, and dots for the rounds done.
	The circle itself can be held (mouse/touch) as well as the key.
	Everything eases slowly; nothing flashes or pulses on its own.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MIN_FILL_SCALE = 0.3

local TaskGuide = {}
TaskGuide.__index = TaskGuide

local function label(parent: Instance, name: string, order: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.TextWrapped = true
	text.Font = font
	text.TextSize = size
	text.TextColor3 = color
	text.Text = ""
	text.Parent = parent
	return text
end

-- onHold(holding) is called when the circle is pressed/released.
function TaskGuide.new(playerGui: PlayerGui, title: string, hint: string, total: number, onHold: (boolean) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "IgniteTaskGuide"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 11

	local group = Instance.new("CanvasGroup")
	group.Name = "Guide"
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.new(0.5, 0, 1, -36)
	group.Size = UDim2.fromOffset(280, 0)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.BackgroundColor3 = Colors.Panel
	group.BackgroundTransparency = 0.12
	group.GroupTransparency = 1
	group.Parent = gui
	local camera = workspace.CurrentCamera
	local scale = Instance.new("UIScale")
	scale.Scale = if camera then math.clamp(camera.ViewportSize.Y / 900, 0.75, 1.3) else 1
	scale.Parent = group
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = group
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	padding.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = group

	label(group, "Title", 1, Theme.Fonts.Bold, 13, Colors.Accent).Text = string.upper(title)

	-- The circle: an outline ring and a fill that scales with the breath.
	local circle = Instance.new("TextButton")
	circle.Name = "Circle"
	circle.LayoutOrder = 2
	circle.Text = ""
	circle.AutoButtonColor = false
	circle.BackgroundTransparency = 1
	circle.Size = UDim2.fromOffset(110, 110)
	circle.Parent = group
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = circle
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Colors.MeterCapacity
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = ring
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Colors.MeterCapacity
	fill.BackgroundTransparency = 0.45
	fill.Parent = circle
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	local fillScale = Instance.new("UIScale")
	fillScale.Scale = MIN_FILL_SCALE
	fillScale.Parent = fill

	local instruction = label(group, "Instruction", 3, Theme.Fonts.Medium, 17, Colors.Text)
	local dots = label(group, "Rounds", 4, Theme.Fonts.Bold, 16, Colors.MeterCapacity)
	label(group, "Hint", 5, Theme.Fonts.Regular, 13, Colors.TextMuted).Text = hint

	circle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			onHold(true)
		end
	end)
	circle.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			onHold(false)
		end
	end)

	gui.Parent = playerGui
	TweenService:Create(group, FADE, { GroupTransparency = 0 }):Play()

	local self = setmetatable({
		_gui = gui,
		_group = group,
		_fillScale = fillScale,
		_stroke = stroke,
		_instruction = instruction,
		_dots = dots,
		_total = total,
	}, TaskGuide)
	self:setRounds(0)
	return self
end

-- 0 = breathed out, 1 = breathed in.
function TaskGuide:setFill(alpha: number)
	self._fillScale.Scale = MIN_FILL_SCALE + (1 - MIN_FILL_SCALE) * math.clamp(alpha, 0, 1)
end

function TaskGuide:setHolding(holding: boolean)
	self._stroke.Transparency = if holding then 0 else 0.3
end

function TaskGuide:setText(text: string)
	self._instruction.Text = text
end

function TaskGuide:setRounds(done: number)
	local marks = {}
	for i = 1, self._total do
		table.insert(marks, if i <= done then "●" else "○")
	end
	self._dots.Text = table.concat(marks, "  ")
end

function TaskGuide:destroy()
	local gui = self._gui
	local tween = TweenService:Create(self._group, FADE, { GroupTransparency = 1 })
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
	tween:Play()
end

return TaskGuide
