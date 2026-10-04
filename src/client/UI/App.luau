--[[
	App

	Owns the ScreenGui. Two layers:
	- HUD layer: compact meter panel, objective tracker and toasts, shown
	  while the character is in the world. Updated in place from controller
	  signals; never covers the centre of the screen.
	- Overlay layer: whatever the current phase needs on top of the world —
	  nothing while exploring, a bottom dialog for scenarios and feedback,
	  and full-screen pages only for character select and end-of-day results.
	  Scenarios with a spoken intro (`leadInSeconds`) show their dialog after
	  the speaker has finished, so the scene plays out first.
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
local Toasts = require(script.Parent.Hud.Toasts)
local SettingsPanel = require(script.Parent.Hud.SettingsPanel)

local Phase = GameController.Phase
local Screens = script.Parent.Screens

local OVERLAY_BY_PHASE = {
	[Phase.CharacterSelect] = require(Screens.CharacterSelect),
	[Phase.Scenario] = require(Screens.ScenarioDialog),
	[Phase.Feedback] = require(Screens.FeedbackDialog),
	[Phase.Results] = require(Screens.Results),
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

function App.new(controller, playerGui: PlayerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ProjectIgniteUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10

	local self = setmetatable({
		_controller = controller,
		_screenGui = screenGui,
		_hudLayer = layer(screenGui, "Hud", 1),
		_overlayLayer = layer(screenGui, "Overlay", 2),
		_settingsLayer = layer(screenGui, "Settings", 3),
		_settingsPanel = nil,
		-- scenario id whose lead-in has already played in this opening
		_introPlayed = nil :: string?,
		_overlayToken = 0,
		_hud = nil,
		_objective = nil,
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
	for _, key in { "_hud", "_objective", "_toasts" } do
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

function App:_renderOverlay(view)
	self._overlayToken += 1
	if self._overlay then
		self._overlay:Destroy()
		self._overlay = nil
	end
	if view.phase ~= Phase.Scenario then
		self._introPlayed = nil
	end
	local screen = OVERLAY_BY_PHASE[view.phase]
	if not screen then
		return -- exploring: nothing covers the world
	end

	-- Let a spoken intro play before the choices appear (once per opening).
	local scenario = view.scenario
	if view.phase == Phase.Scenario and scenario and scenario.leadInSeconds and self._introPlayed ~= scenario.id then
		self._introPlayed = scenario.id
		local token = self._overlayToken
		task.delay(scenario.leadInSeconds, function()
			if self._overlayToken == token and self._controller:getPhase() == Phase.Scenario then
				self:_renderOverlay(self._controller:getView())
			end
		end)
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
	self:_renderOverlay(view)
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
	connect(controller.MetersChanged, function(changes)
		if self._hud then
			self._hud:update(controller:getMeters(), changes)
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
