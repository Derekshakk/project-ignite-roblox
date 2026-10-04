--[[
	NpcSpeech

	Speech bubbles over NPCs' heads, plus a small name label for named NPCs
	(Data/Npcs). While a bubble is up, the NPC plays its talking animation
	(NpcAnimator.setTalking); it stops when the bubble goes away.

	Each NPC has at most one bubble; saying something new replaces the old
	line. Bubbles have a kind, so a scene can clear its own lines without
	touching others:
		scene    a scenario intro (the director decides when it ends)
		reply    a short line after a choice, or a greeting
		lecture  the teacher talking while the player sits
		ambient  background chatter (AmbientChatter)
	Scene and reply bubbles draw on top of the world so they stay readable;
	lecture and ambient bubbles can be hidden behind walls and fade out
	with distance.

	Bubbles fade and scale in gently; nothing flashes. Text is dark on a
	light card for contrast in any lighting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Npcs = require(ReplicatedStorage:WaitForChild("Shared").Data.Npcs)
local NpcRegistry = require(script.Parent.NpcRegistry)

local Kind = table.freeze({
	Scene = "scene",
	Reply = "reply",
	Lecture = "lecture",
	Ambient = "ambient",
})

local STYLES = table.freeze({
	[Kind.Scene] = { alwaysOnTop = true, maxDistance = 80, textSize = 17 },
	[Kind.Reply] = { alwaysOnTop = true, maxDistance = 60, textSize = 16 },
	[Kind.Lecture] = { alwaysOnTop = false, maxDistance = 50, textSize = 16 },
	[Kind.Ambient] = { alwaysOnTop = false, maxDistance = 40, textSize = 14 },
})

local BUBBLE_COLOR = Color3.fromRGB(246, 244, 238)
local TEXT_COLOR = Color3.fromRGB(38, 40, 52)
local NAME_COLOR = Color3.fromRGB(196, 104, 28)
local STROKE_COLOR = Color3.fromRGB(120, 116, 108)
local MAX_TEXT_WIDTH = 250
local SHOW = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local NpcSpeech = {}
NpcSpeech.__index = NpcSpeech
NpcSpeech.Kind = Kind

-- Seconds a line stays up: enough to read comfortably, never rushed.
function NpcSpeech.readingTime(text: string): number
	local words = 0
	for _ in string.gmatch(text, "%S+") do
		words += 1
	end
	return math.clamp(1.4 + words * 0.3, 2.5, 7)
end

local function displayName(model: Model): string?
	local npcId = NpcRegistry.getNpcId(model)
	local data = npcId and Npcs[npcId]
	return data and data.name
end

-- Where an NPC's head is on screen, and whether it's visible.
function NpcSpeech.screenPoint(model: Model): (Vector2?, boolean)
	local camera = workspace.CurrentCamera
	local position = NpcRegistry.getHeadPosition(model)
	if not camera or not position then
		return nil, false
	end
	local point, onScreen = camera:WorldToViewportPoint(position + Vector3.new(0, 1.5, 0))
	return Vector2.new(point.X, point.Y), onScreen and point.Z > 0
end

function NpcSpeech.new(animator, playerGui: PlayerGui)
	return setmetatable({
		_animator = animator,
		_playerGui = playerGui,
		_bubbles = {} :: { [Model]: any },
		_nameTags = {} :: { [Model]: BillboardGui },
	}, NpcSpeech)
end

function NpcSpeech:start()
	NpcRegistry.start()
	for _, model in NpcRegistry.all() do
		self:_addNameTag(model)
	end
	NpcRegistry.Added:Connect(function(model)
		self:_addNameTag(model)
	end)
	NpcRegistry.Removed:Connect(function(model)
		self:_remove(model)
	end)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function billboard(name: string, head: BasePart, size: Vector2): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	-- Shift up by half the height so the bottom edge sits at the offset point.
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.LightInfluence = 0
	gui.ClipsDescendants = false
	return gui
end

function NpcSpeech:_addNameTag(model: Model)
	local name = displayName(model)
	if not name or self._nameTags[model] then
		return
	end
	task.spawn(function()
		local head = model:WaitForChild("Head", 10)
		if not head or not head:IsA("BasePart") or self._nameTags[model] then
			return
		end
		local gui = billboard("IgniteNameTag", head, Vector2.new(180, 26))
		gui.StudsOffsetWorldSpace = Vector3.new(0, 1.0, 0)
		gui.MaxDistance = 26
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.fromScale(0.5, 1)
		label.Size = UDim2.fromOffset(0, 0)
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.BackgroundColor3 = Color3.fromRGB(30, 33, 46)
		label.BackgroundTransparency = 0.35
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(236, 238, 245)
		label.Text = name
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
		padding.Parent = label
		gui.Parent = self._playerGui
		self._nameTags[model] = gui
		local bubble = self._bubbles[model]
		gui.Enabled = not (bubble and bubble.visible)
	end)
end

function NpcSpeech:_getBubble(model: Model)
	local existing = self._bubbles[model]
	if existing then
		return existing
	end
	local head = NpcRegistry.getHead(model) or NpcRegistry.getRoot(model)
	if not head then
		return nil
	end

	local gui = billboard("IgniteSpeech", head, Vector2.new(MAX_TEXT_WIDTH + 40, 170))
	gui.StudsOffsetWorldSpace = Vector3.new(0, if head.Name == "Head" then 1.1 else 2.6, 0)
	gui.Enabled = false

	local container = Instance.new("Frame")
	container.Name = "Bubble"
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.fromScale(0.5, 1)
	container.Size = UDim2.fromOffset(0, 0)
	container.AutomaticSize = Enum.AutomaticSize.XY
	container.BackgroundTransparency = 1
	container.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = container
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, -9)
	layout.Parent = container

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.LayoutOrder = 1
	body.ZIndex = 2
	body.Size = UDim2.fromOffset(0, 0)
	body.AutomaticSize = Enum.AutomaticSize.XY
	body.BackgroundColor3 = BUBBLE_COLOR
	body.Parent = container
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = body
	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = body
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 7), UDim.new(0, 8)
	padding.Parent = body
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 2)
	bodyLayout.Parent = body

	local function label(name: string, order: number, font: Enum.Font, color: Color3): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.LayoutOrder = order
		text.ZIndex = 3
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromOffset(0, 0)
		text.AutomaticSize = Enum.AutomaticSize.XY
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = ""
		text.Font = font
		text.TextColor3 = color
		text.Parent = body
		local constraint = Instance.new("UISizeConstraint")
		constraint.MaxSize = Vector2.new(MAX_TEXT_WIDTH, math.huge)
		constraint.Parent = text
		return text
	end
	local nameLabel = label("Name", 1, Enum.Font.GothamBold, NAME_COLOR)
	nameLabel.TextSize = 12
	local textLabel = label("Line", 2, Enum.Font.GothamMedium, TEXT_COLOR)

	-- Tail: a rotated square tucked under the card.
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.LayoutOrder = 2
	tail.ZIndex = 1
	tail.Size = UDim2.fromOffset(14, 14)
	tail.Rotation = 45
	tail.BackgroundColor3 = BUBBLE_COLOR
	tail.BorderSizePixel = 0
	tail.Parent = container

	gui.Parent = self._playerGui
	local bubble = {
		gui = gui,
		container = container,
		scale = scale,
		body = body,
		stroke = stroke,
		nameLabel = nameLabel,
		textLabel = textLabel,
		tail = tail,
		token = 0,
		kind = nil :: string?,
		visible = false,
	}
	self._bubbles[model] = bubble
	return bubble
end

local function fade(bubble, visible: boolean)
	local info = if visible then SHOW else HIDE
	local function tween(instance: Instance, goal: { [string]: any })
		TweenService:Create(instance, info, goal):Play()
	end
	local t = if visible then 0 else 1
	tween(bubble.body, { BackgroundTransparency = if visible then 0.04 else 1 })
	tween(bubble.stroke, { Transparency = if visible then 0.65 else 1 })
	tween(bubble.tail, { BackgroundTransparency = if visible then 0.04 else 1 })
	tween(bubble.nameLabel, { TextTransparency = t })
	tween(bubble.textLabel, { TextTransparency = t })
	tween(bubble.scale, { Scale = if visible then 1 else 0.94 })
end

---------------------------------------------------------------------------
-- Speaking
---------------------------------------------------------------------------

--[[
	Shows `text` over the NPC. With `seconds` the bubble hides itself after
	that long; without, it stays until clear()/clearAll() (scenes control
	their own timing). Returns false if the NPC isn't loaded.
]]
function NpcSpeech:say(npc: string | Model, text: string, seconds: number?, kind: string?): boolean
	local model = NpcRegistry.get(npc)
	local bubble = model and self:_getBubble(model)
	if not model or not bubble then
		return false
	end
	kind = kind or Kind.Ambient
	local style = STYLES[kind] or STYLES[Kind.Ambient]
	bubble.token += 1
	local token = bubble.token
	bubble.kind = kind

	local name = displayName(model)
	bubble.nameLabel.Text = if name then string.upper(name) else ""
	bubble.nameLabel.Visible = name ~= nil
	bubble.textLabel.Text = text
	bubble.textLabel.TextSize = style.textSize
	bubble.gui.AlwaysOnTop = style.alwaysOnTop
	bubble.gui.MaxDistance = style.maxDistance

	if not bubble.visible then
		-- Start from hidden so the fade-in always plays from the same place.
		bubble.visible = true
		bubble.scale.Scale = 0.94
		bubble.body.BackgroundTransparency = 1
		bubble.stroke.Transparency = 1
		bubble.tail.BackgroundTransparency = 1
		bubble.nameLabel.TextTransparency = 1
		bubble.textLabel.TextTransparency = 1
		bubble.gui.Enabled = true
	end
	fade(bubble, true)
	local tag = self._nameTags[model]
	if tag then
		tag.Enabled = false
	end
	self._animator:setTalking(model, true)

	if seconds then
		task.delay(seconds, function()
			if bubble.token == token then
				self:_hide(model, bubble)
			end
		end)
	end
	return true
end

function NpcSpeech:_hide(model: Model, bubble)
	bubble.token += 1
	local token = bubble.token
	if not bubble.visible then
		return
	end
	bubble.visible = false
	bubble.kind = nil
	self._animator:setTalking(model, false)
	fade(bubble, false)
	task.delay(HIDE.Time + 0.05, function()
		if bubble.token == token then
			bubble.gui.Enabled = false
			local tag = self._nameTags[model]
			if tag then
				tag.Enabled = true
			end
		end
	end)
end

-- Hides one NPC's bubble (only if it's of `kind`, when given).
function NpcSpeech:clear(npc: string | Model, kind: string?)
	local model = NpcRegistry.get(npc)
	local bubble = model and self._bubbles[model]
	if model and bubble and (kind == nil or bubble.kind == kind) then
		self:_hide(model, bubble)
	end
end

-- Hides every bubble (only those of `kind`, when given).
function NpcSpeech:clearAll(kind: string?)
	for model, bubble in self._bubbles do
		if bubble.visible and (kind == nil or bubble.kind == kind) then
			self:_hide(model, bubble)
		end
	end
end

function NpcSpeech:isSpeaking(npc: string | Model): boolean
	local model = NpcRegistry.get(npc)
	local bubble = model and self._bubbles[model]
	return bubble ~= nil and bubble.visible
end

-- Number of visible bubbles of `kind` (or of every kind except `except`).
function NpcSpeech:count(kind: string?, except: string?): number
	local total = 0
	for _, bubble in self._bubbles do
		if bubble.visible and (kind == nil or bubble.kind == kind) and (except == nil or bubble.kind ~= except) then
			total += 1
		end
	end
	return total
end

-- Screen positions of the visible bubbles (to keep new ones apart).
function NpcSpeech:screenPositions(): { Vector2 }
	local points = {}
	for model, bubble in self._bubbles do
		if bubble.visible then
			local point = NpcSpeech.screenPoint(model)
			if point then
				table.insert(points, point)
			end
		end
	end
	return points
end

function NpcSpeech:_remove(model: Model)
	local bubble = self._bubbles[model]
	if bubble then
		bubble.token += 1
		bubble.gui:Destroy()
		self._bubbles[model] = nil
	end
	local tag = self._nameTags[model]
	if tag then
		tag:Destroy()
		self._nameTags[model] = nil
	end
	self._animator:setTalking(model, false)
end

return NpcSpeech
