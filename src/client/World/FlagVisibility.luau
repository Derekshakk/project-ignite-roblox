--[[
	FlagVisibility

	Shows or hides world objects (tagged IgniteFlagVisibility) as the story
	moves on:
		HideWhenFlag   hidden once the flag is set (an item packed into the
		               backpack, students heading off once the rush is over)
		ShowWhenFlag   only shown once the flag is set (a note left on the
		               teacher's desk)
	Hidden objects stop colliding, decals (faces) hide too, and the model is
	marked with an "IgniteHidden" attribute so other client systems (e.g.
	background chatter) leave it alone. Prompts are left to the
	InteractionController (whatever is hidden is also unavailable).
	Changes are local to this player and undone on a new run (the flags
	reset with the session).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

local HIDDEN_ATTRIBUTE = "IgniteHidden"
-- People leaving or arriving fade gently; objects (an item being packed,
-- which has its own animation) and the initial state change at once.
local FADE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local FlagVisibility = {}
FlagVisibility.__index = FlagVisibility
FlagVisibility.HIDDEN_ATTRIBUTE = HIDDEN_ATTRIBUTE

function FlagVisibility.new(controller)
	return setmetatable({
		_controller = controller,
		-- original values, recorded the first time an instance is touched
		_original = {} :: { [Instance]: { transparency: number, canCollide: boolean? } },
		-- last applied state per tagged instance
		_hidden = {} :: { [Instance]: boolean },
	}, FlagVisibility)
end

function FlagVisibility.isHidden(instance: Instance): boolean
	return instance:GetAttribute(HIDDEN_ATTRIBUTE) == true
end

function FlagVisibility:start()
	local function refresh()
		self:refresh()
	end
	self._controller.StateChanged:Connect(refresh)
	self._controller.Changed:Connect(refresh)
	CollectionService:GetInstanceAddedSignal(World.Tags.FlagVisibility):Connect(function(instance)
		-- NPC rigs finish loading a moment after they're tagged.
		task.defer(refresh)
		task.delay(1, refresh)
		self:_apply(instance)
	end)
	refresh()
end

function FlagVisibility:_shouldHide(instance: Instance): boolean
	local hideFlag = instance:GetAttribute(World.Attributes.HideWhenFlag)
	local showFlag = instance:GetAttribute(World.Attributes.ShowWhenFlag)
	if type(hideFlag) == "string" and self._controller:getFlag(hideFlag) then
		return true
	end
	if type(showFlag) == "string" and not self._controller:getFlag(showFlag) then
		return true
	end
	return false
end

function FlagVisibility:_apply(instance: Instance)
	local hidden = self:_shouldHide(instance)
	local previous = self._hidden[instance]
	local changed = previous ~= hidden
	local fade = previous ~= nil and changed and CollectionService:HasTag(instance, World.Tags.Npc)
	self._hidden[instance] = hidden
	instance:SetAttribute(HIDDEN_ATTRIBUTE, hidden)
	local descendants = instance:GetDescendants()
	table.insert(descendants, instance)
	for _, item in descendants do
		if item:IsA("BasePart") or item:IsA("Decal") then
			local original = self._original[item]
			if original and not changed then
				continue -- already in this state (don't interrupt a fade)
			end
			if not original then
				original = {
					transparency = item.Transparency,
					canCollide = if item:IsA("BasePart") then item.CanCollide else nil,
				}
				self._original[item] = original
			end
			local goal = if hidden then 1 else original.transparency
			if fade then
				TweenService:Create(item, FADE, { Transparency = goal }):Play()
			else
				item.Transparency = goal
			end
			if item:IsA("BasePart") and original.canCollide ~= nil then
				item.CanCollide = if hidden then false else original.canCollide
			end
		end
	end
end

function FlagVisibility:refresh()
	for _, instance in CollectionService:GetTagged(World.Tags.FlagVisibility) do
		self:_apply(instance)
	end
end

return FlagVisibility
