--[[
	App

	Owns the ScreenGui. Two layers:
	- HUD layer: compact meter panel, clock, objective tracker and toasts, shown
	  while the character is in the world. Updated in place from controller
	  signals; never covers the centre of the screen.
	- Overlay layer: whatever the current phase and UIState stage need on
	  top of the world — nothing while exploring, a small "Next" hint while
	  an NPC is speaking, a bottom dialog for scenario choices and feedback,
	  and full-screen pages only for character select and end-of-day
	  results. The choice panel only appears once UIState reaches Choice
	  (after the speaker has finished and their bubble is gone), so spoken
	  lines and the panel never share the screen. Rendering is keyed, so
	  repeated signals can't stack duplicate panels.
	- Settings layer: the Settings button and panel.

	Screens receive `actions`, a small table of functions that forward to the
	controller. That is the only way UI code can change game state.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameController = require(ReplicatedStorage:WaitForChild("Shared").Game.GameController)
local Theme = require(script.Parent.Theme)
local MeterHud = require(script.Parent.Hud.MeterHud)
local ObjectiveTracker = require(script.Parent.Hud.ObjectiveTracker)
local ClockHud = require(script.Parent.Hud.ClockHud)
local Toasts = require(script.Parent.Hud.Toasts)
local SettingsPanel = require(script.Parent.Hud.SettingsPanel)

local Phase = GameController.Phase
local Screens = script.Parent.Screens

local OVERLAYS = {
	CharacterSelect = require(Screens.CharacterSelect),
	Speaking = require(Screens.SpeechHint),
	Scenario = require(Screens.ScenarioDialog),
	Feedback = require(Screens.FeedbackDialog),
	Results = require(Screens.Results),
}

-- Phases where the character is in the world and the HUD is shown.
local HUD_PHASES = {
	[Phase.Exploring] = true,
	[Phase.Scenario] = true,
	[Phase.Feedback] = true,
}

local BACKDROP_TRANSPARENCY = 0.2

local App = {}
App.__index = App

local function layer(parent: Instance, name: string, zIndex: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = zIndex
	frame.Parent = parent
	return frame
end

function App.new(controller, playerGui: PlayerGui, uiState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ProjectIgniteUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10

	local self = setmetatable({
		_controller = controller,
		_uiState = uiState,
		_screenGui = screenGui,
		_hudLayer = layer(screenGui, "Hud", 1),
		_overlayLayer = layer(screenGui, "Overlay", 2),
		_settingsLayer = layer(screenGui, "Settings", 3),
		_settingsPanel = nil,
		-- which overlay is shown, e.g. "Scenario#4" (name + phase serial)
		_overlayKey = nil :: string?,
		-- counts phase changes, so reopening the same kind of panel later
		-- (a second feedback panel) always renders fresh
		_phaseSerial = 0,
		_lastPhase = nil :: string?,
		_hud = nil,
		_objective = nil,
		_clock = nil,
		_toasts = nil,
		_overlay = nil,
		_ctx = nil,
		_connections = {},
	}, App)
	screenGui.Parent = playerGui

	self._actions = table.freeze({
		selectCharacter = function(characterId: string)
			controller:selectCharacter(characterId)
		end,
		submitChoice = function(choiceId: string)
			controller:submitChoice(choiceId)
		end,
		cancelScenario = function()
			controller:cancelScenario()
		end,
		continue = function()
			controller:continue()
		end,
		restart = function()
			controller:restart()
		end,
		advanceDialogue = function()
			uiState:requestAdvance()
		end,
	})

	return self
end

function App:_buildContext()
	local size = self._overlayLayer.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		local camera = workspace.CurrentCamera
		size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end
	return table.freeze({
		scale = Theme.getScale(size),
		compact = size.X < Theme.CompactWidth,
		topInset = (GuiService:GetGuiInset()).Y,
	})
end

---------------------------------------------------------------------------
-- HUD layer
---------------------------------------------------------------------------

function App:_destroyHud()
	for _, key in { "_hud", "_objective", "_clock", "_toasts" } do
		if self[key] then
			self[key]:destroy()
			self[key] = nil
		end
	end
end

function App:_buildHud(view)
	self:_destroyHud()
	self._toasts = Toasts.new(self._hudLayer, self._ctx)
	if HUD_PHASES[view.phase] then
		self._hud = MeterHud.new(self._hudLayer, self._ctx, view.character, view.meters)
		self._objective = ObjectiveTracker.new(self._hudLayer, self._ctx)
		self._clock = ClockHud.new(self._hudLayer, self._ctx, view.day)
		self._clock:set(view.timeText, false)
		self:_syncIndicators()
	end
	self:_syncObjective()
end

function App:_syncIndicators()
	if not self._hud then
		return
	end
	local labels = {}
	for _, item in self._controller:getEquippedItems() do
		if item.hudLabel then
			table.insert(labels, item.hudLabel)
		end
	end
	self._hud:setIndicators(labels)
end

-- Rebuild only when the HUD should appear/disappear or the character changed.
function App:_syncHud(view)
	local wantsHud = HUD_PHASES[view.phase] == true
	local hasHud = self._hud ~= nil
	if wantsHud ~= hasHud or (hasHud and self._hud.characterId ~= view.character.id) then
		self:_buildHud(view)
	else
		self:_syncObjective()
	end
end

function App:_syncObjective()
	if self._objective then
		local text = self._controller:getObjectiveText()
		self._objective:set(text, self._controller:getPhase() == Phase.Exploring)
	end
end

---------------------------------------------------------------------------
-- Overlay layer
---------------------------------------------------------------------------

-- Which overlay the current phase and interaction stage call for.
function App:_overlayName(phase: string): string?
	local stage = self._uiState:getStage()
	local Stage = self._uiState.Stage
	if phase == Phase.CharacterSelect then
		return "CharacterSelect"
	elseif phase == Phase.Results then
		return "Results"
	elseif phase == Phase.Scenario then
		-- Choices wait until the speaker has finished. (Any other stage
		-- falls back to the choice panel so the player is never stuck.)
		return if stage == Stage.Speaking then "Speaking" else "Scenario"
	elseif phase == Phase.Feedback then
		return "Feedback"
	end
	return nil -- exploring: nothing covers the world
end

-- Shows the overlay for the current state. Does nothing if it's already
-- showing (unless `force`, e.g. after a layout change).
function App:_renderOverlay(view, force: boolean?)
	if view.phase ~= self._lastPhase then
		self._lastPhase = view.phase
		self._phaseSerial += 1
	end
	local name = self:_overlayName(view.phase)
	local key = if name then `{name}#{self._phaseSerial}` else nil
	if key == self._overlayKey and not force then
		return
	end
	self._overlayKey = key
	if self._overlay then
		self._overlay:Destroy()
		self._overlay = nil
	end
	local screen = name and OVERLAYS[name]
	if not screen then
		return
	end

	local host = self._overlayLayer
	if screen.fullscreen then
		-- Dim the world behind menus; Active so clicks don't fall through.
		host = Instance.new("Frame")
		host.Name = "Backdrop"
		host.BackgroundColor3 = Theme.Colors.Background
		host.BackgroundTransparency = BACKDROP_TRANSPARENCY
		host.BorderSizePixel = 0
		host.Size = UDim2.fromScale(1, 1)
		host.Active = true
		host.Parent = self._overlayLayer
	end
	local rendered = screen.render(host, self._ctx, view, self._actions)
	self._overlay = if screen.fullscreen then host else rendered
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

-- Full rebuild (first render and when the window size changes the layout).
function App:render()
	self._ctx = self:_buildContext()
	local view = self._controller:getView()
	self:_buildHud(view)
	self:_renderOverlay(view, true)
	if self._settingsPanel then
		self._settingsPanel:destroy()
	end
	self._settingsPanel = SettingsPanel.new(self._settingsLayer, self._ctx)
end

-- Shows a toast from outside the controller (world hints, etc.).
function App:notify(notification)
	if self._toasts then
		self._toasts:push(notification)
	end
end

function App:_onPhaseChanged()
	local view = self._controller:getView()
	self:_syncHud(view)
	self:_renderOverlay(view)
end

function App:start()
	local controller = self._controller
	local function connect(signal, handler)
		table.insert(self._connections, signal:Connect(handler))
	end

	connect(controller.Changed, function()
		self:_onPhaseChanged()
	end)
	connect(self._uiState.Changed, function()
		self:_renderOverlay(controller:getView())
	end)
	connect(controller.MetersChanged, function(changes)
		if self._hud then
			self._hud:update(controller:getMeters(), changes)
		end
	end)
	connect(controller.TimeChanged, function()
		if self._clock then
			self._clock:set(controller:getTimeText(), true)
		end
	end)
	connect(controller.StateChanged, function()
		self:_syncObjective()
	end)
	connect(controller.InventoryChanged, function()
		self:_syncIndicators()
	end)
	connect(controller.Notified, function(notification)
		if self._toasts then
			self._toasts:push(notification)
		end
	end)

	-- Only re-render when the size change actually affects scale or layout.
	connect(self._overlayLayer:GetPropertyChangedSignal("AbsoluteSize"), function()
		local nextCtx = self:_buildContext()
		local current = self._ctx
		if not current or nextCtx.scale ~= current.scale or nextCtx.compact ~= current.compact then
			self:render()
		end
	end)

	self:render()
end

function App:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_destroyHud()
	self._screenGui:Destroy()
end

return App
