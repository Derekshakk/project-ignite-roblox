--[[
	EnvironmentEffects

	Local, restrained feedback for zones: a slow colour-grade shift (no
	flashing, no blur) and a walking-speed change in crowded spaces. Values
	come from each zone's `ambience` and `walkSpeedMultiplier` data.
]]

local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local PlayerControl = require(script.Parent.PlayerControl)

local TRANSITION = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local NEUTRAL = table.freeze({
	Saturation = 0,
	Contrast = 0,
	Brightness = 0,
	TintColor = Color3.new(1, 1, 1),
})

local EnvironmentEffects = {}
EnvironmentEffects.__index = EnvironmentEffects

function EnvironmentEffects.new()
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "IgniteZoneAmbience"
	colorCorrection.Parent = Lighting

	return setmetatable({
		_colorCorrection = colorCorrection,
		_tween = nil,
		_walkSpeedMultiplier = 1,
	}, EnvironmentEffects)
end

--[[
	Applies the combined look of the zones the player is in. `zones` is a
	list of resolved zone data (see GameController:getResolvedZone). An empty
	list returns everything to neutral.
]]
function EnvironmentEffects:apply(zones: { any })
	local target = table.clone(NEUTRAL)
	local walkSpeedMultiplier = 1

	for _, zone in zones do
		local ambience = zone.ambience
		if ambience then
			target.Saturation += ambience.saturation or 0
			target.Contrast += ambience.contrast or 0
			target.Brightness += ambience.brightness or 0
			if ambience.tint then
				target.TintColor = ambience.tint
			end
		end
		if zone.walkSpeedMultiplier then
			walkSpeedMultiplier = math.min(walkSpeedMultiplier, zone.walkSpeedMultiplier)
		end
	end

	if self._tween then
		self._tween:Cancel()
	end
	self._tween = TweenService:Create(self._colorCorrection, TRANSITION, target)
	self._tween:Play()

	self._walkSpeedMultiplier = walkSpeedMultiplier
	self:applyWalkSpeed()
end

-- Also called when the character respawns.
function EnvironmentEffects:applyWalkSpeed()
	local humanoid = PlayerControl.getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed * self._walkSpeedMultiplier
	end
end

function EnvironmentEffects:reset()
	self:apply({})
end

return EnvironmentEffects
