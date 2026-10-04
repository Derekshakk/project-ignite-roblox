--[[
	TimeOfDay

	Lets the sky follow the in-game clock (GameController time), locally:
	early morning light when the day starts, mid-morning at school, and
	afternoon light for the walk home. The game's time is mapped into a
	safe daylight range so outdoor scenes never get dark or blown out, and
	changes ease over a few seconds instead of jumping. Indoor rooms are
	lit mainly by their own lights, so they barely change.

	Outside a run (character select, results) the sky returns to the
	server's default.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clock = require(Shared.Game.Clock)
local GameController = require(Shared.Game.GameController)

-- ClockTime = BASE + (hours - 7) * SCALE, clamped to the safe range:
-- 7:05 AM → ~8.6, 8:15 AM → ~9.4, 3:05 PM → ~14.5.
local BASE = 8.5
local SCALE = 0.75
local MIN_CLOCK, MAX_CLOCK = 8.4, 15.5
local EASE = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local TimeOfDay = {}
TimeOfDay.__index = TimeOfDay

function TimeOfDay.new(controller)
	return setmetatable({
		_controller = controller,
		_default = Lighting.ClockTime,
		_tween = nil :: Tween?,
	}, TimeOfDay)
end

function TimeOfDay.clockTimeFor(minutes: number): number
	return math.clamp(BASE + (Clock.toHours(minutes) - 7) * SCALE, MIN_CLOCK, MAX_CLOCK)
end

function TimeOfDay:_easeTo(clockTime: number)
	if self._tween then
		self._tween:Cancel()
	end
	if math.abs(Lighting.ClockTime - clockTime) < 0.01 then
		return
	end
	self._tween = TweenService:Create(Lighting, EASE, { ClockTime = clockTime })
	self._tween:Play()
end

function TimeOfDay:_sync()
	local controller = self._controller
	local phase = controller:getPhase()
	local minutes = controller:getTime()
	if minutes and phase ~= GameController.Phase.CharacterSelect then
		self:_easeTo(TimeOfDay.clockTimeFor(minutes))
	else
		self:_easeTo(self._default)
	end
end

function TimeOfDay:start()
	-- The server sets the default on start; read it once it has replicated.
	task.defer(function()
		self._default = Lighting.ClockTime
	end)
	self._controller.TimeChanged:Connect(function()
		self:_sync()
	end)
	self._controller.Changed:Connect(function()
		self:_sync()
	end)
end

return TimeOfDay
