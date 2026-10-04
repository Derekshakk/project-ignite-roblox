--[[
	ObjectiveMarker

	A small diamond floating over the current objective's target, so the
	player can find their way without a map. The target comes from the day
	plan (`marker`, per area) as "InteractionType:InteractionId" and is
	resolved to the matching interaction prompt in the world, or as
	"Waypoint:<id>" for a route point. A marker can also be a route (a list
	of targets): the diamond moves to the next point once the player
	reaches the current one, or has clearly passed it (e.g. by taking the
	park instead of the street). One marker at a time, never a trail of
	arrows. It hides when
	the player is right next to the target, during menus and dialogs, and
	when "Objective marker" is off. It bobs gently unless "Camera motion"
	is off.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local GameController = require(Shared.Game.GameController)
local Settings = require(script.Parent.Parent.Settings)
local PlayerControl = require(script.Parent.PlayerControl)

local HIDE_WITHIN = 7
-- A route point counts as reached within this distance.
local REACH_DISTANCE = 14
local BASE_OFFSET = 2.6
local ACCENT = Color3.fromRGB(255, 170, 70)

local ObjectiveMarker = {}
ObjectiveMarker.__index = ObjectiveMarker

function ObjectiveMarker.new(controller)
	return setmetatable({
		_controller = controller,
		_target = nil :: BasePart?,
		-- current route (list of targets), its key and progress
		_route = nil :: { string }?,
		_routeKey = nil :: string?,
		_routeIndex = 1,
	}, ObjectiveMarker)
end

local function findTarget(marker: string?): BasePart?
	if not marker then
		return nil
	end
	local interactionType, interactionId = string.match(marker, "^([^:]+):(.+)$")
	if interactionType == "Waypoint" then
		for _, part in CollectionService:GetTagged(World.Tags.Waypoint) do
			if part:IsA("BasePart") and part:GetAttribute(World.Attributes.WaypointId) == interactionId then
				return part
			end
		end
		return nil
	end
	for _, prompt in CollectionService:GetTagged(World.Tags.Interactable) do
		if
			prompt:GetAttribute(World.Attributes.InteractionType) == interactionType
			and prompt:GetAttribute(World.Attributes.InteractionId) == interactionId
			and prompt.Parent
			and prompt.Parent:IsA("BasePart")
		then
			return prompt.Parent :: BasePart
		end
	end
	return nil
end

function ObjectiveMarker:start()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "IgniteObjectiveMarker"
	billboard.Size = UDim2.fromOffset(30, 30)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 450
	billboard.StudsOffset = Vector3.new(0, BASE_OFFSET, 0)
	billboard.ResetOnSpawn = false
	billboard.Enabled = false

	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromOffset(14, 14)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = ACCENT
	diamond.BackgroundTransparency = 0.1
	diamond.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 32, 24)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = diamond

	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._billboard = billboard

	local function refresh()
		self:_refresh()
	end
	self._controller.StateChanged:Connect(refresh)
	self._controller.Changed:Connect(refresh)
	Settings.Changed:Connect(refresh)
	CollectionService:GetInstanceAddedSignal(World.Tags.Interactable):Connect(refresh)
	CollectionService:GetInstanceAddedSignal(World.Tags.Waypoint):Connect(refresh)

	RunService.Heartbeat:Connect(function()
		local target = self._target
		if not target or not billboard.Adornee then
			return
		end
		local bob = if Settings.get("cameraMotion") then math.sin(os.clock() * 1.6) * 0.15 else 0
		billboard.StudsOffset = Vector3.new(0, BASE_OFFSET + bob, 0)
		local position = PlayerControl.getRootPosition()
		if position and self._route and self:_advanceRoute(position) then
			return
		end
		billboard.Enabled = self._visible and not (position and (position - target.Position).Magnitude < HIDE_WITHIN)
	end)
	refresh()
end

-- Moves along the route when the current point is reached or passed.
-- Returns true if the target changed.
function ObjectiveMarker:_advanceRoute(position: Vector3): boolean
	local route = self._route :: { string }
	local target = self._target
	if not target or self._routeIndex >= #route then
		return false
	end
	local nextTarget = findTarget(route[self._routeIndex + 1])
	local reached = (position - target.Position).Magnitude < REACH_DISTANCE
	-- Closer to the next point than this one is: the player has gone past
	-- it another way.
	local passed = nextTarget ~= nil and (position - nextTarget.Position).Magnitude < (target.Position - nextTarget.Position).Magnitude
	if reached or passed then
		self._routeIndex += 1
		self:_refresh()
		return true
	end
	return false
end

function ObjectiveMarker:_refresh()
	local controller = self._controller
	local active = controller:getPhase() == GameController.Phase.Exploring and Settings.get("objectiveMarker")
	local marker = if active then controller:getObjectiveMarker() else nil
	if type(marker) == "table" then
		local key = table.concat(marker, ",")
		if key ~= self._routeKey then
			-- A new route (new objective or area): start from the beginning.
			self._routeKey = key
			self._routeIndex = 1
		end
		self._route = marker
		marker = marker[self._routeIndex]
	else
		self._route = nil
		if marker ~= nil then
			-- (Hidden during dialogs: keep the route progress for later.)
			self._routeKey = nil
		end
	end
	self._target = findTarget(marker)
	self._visible = self._target ~= nil
	self._billboard.Adornee = self._target
	self._billboard.Enabled = self._visible
end

return ObjectiveMarker
