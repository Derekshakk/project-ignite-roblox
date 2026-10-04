--[[
	ObjectiveMarker

	A small diamond floating over the current objective's target, so the
	player can find their way without a map. The target comes from the day
	plan (`marker`, per area) as "InteractionType:InteractionId" and is
	resolved to the matching interaction prompt in the world. It hides when
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
local BASE_OFFSET = 2.6
local ACCENT = Color3.fromRGB(255, 170, 70)

local ObjectiveMarker = {}
ObjectiveMarker.__index = ObjectiveMarker

function ObjectiveMarker.new(controller)
	return setmetatable({
		_controller = controller,
		_target = nil :: BasePart?,
	}, ObjectiveMarker)
end

local function findTarget(marker: string?): BasePart?
	if not marker then
		return nil
	end
	local interactionType, interactionId = string.match(marker, "^([^:]+):(.+)$")
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
	billboard.MaxDistance = 250
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

	RunService.Heartbeat:Connect(function()
		local target = self._target
		if not target or not billboard.Adornee then
			return
		end
		local bob = if Settings.get("cameraMotion") then math.sin(os.clock() * 1.6) * 0.15 else 0
		billboard.StudsOffset = Vector3.new(0, BASE_OFFSET + bob, 0)
		local position = PlayerControl.getRootPosition()
		billboard.Enabled = self._visible and not (position and (position - target.Position).Magnitude < HIDE_WITHIN)
	end)
	refresh()
end

function ObjectiveMarker:_refresh()
	local controller = self._controller
	local active = controller:getPhase() == GameController.Phase.Exploring and Settings.get("objectiveMarker")
	self._target = if active then findTarget(controller:getObjectiveMarker()) else nil
	self._visible = self._target ~= nil
	self._billboard.Adornee = self._target
	self._billboard.Enabled = self._visible
end

return ObjectiveMarker
