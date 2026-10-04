--[[
	AudioController

	Environmental audio, all routed through one SoundGroup so it can be
	mixed as a whole:
	- per-area ambience loops (Data/Areas), cross-faded as the player moves
	  between areas
	- 3D ambient sounds placed in the world (tagged IgniteAmbientSound,
	  e.g. crowd chatter in a zone)

	Equipped items with `effects.environmentVolume` / `effects.muffle` (e.g.
	headphones) turn the group down and soften high frequencies, like
	hearing the room through ear cups. Removing them restores the mix.
	"Environment sounds" in Settings mutes the group.

	Volumes are deliberately low. Sound ids are placeholders (empty) until
	real assets are added in Data/Areas and Data/Zones.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Areas = require(Shared.Data.Areas)
local Settings = require(script.Parent.Parent.Settings)

local CROSSFADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local MIX = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MUFFLED = { HighGain = -18, MidGain = -6, LowGain = 0 }
local CLEAR = { HighGain = 0, MidGain = 0, LowGain = 0 }

local AudioController = {}
AudioController.__index = AudioController

function AudioController.new(controller)
	return setmetatable({
		_controller = controller,
		_areaSounds = {} :: { [string]: Sound },
		_currentArea = nil :: string?,
	}, AudioController)
end

function AudioController:start()
	local group = Instance.new("SoundGroup")
	group.Name = "IgniteEnvironment"
	group.Volume = 1
	group.Parent = SoundService
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.HighGain, equalizer.MidGain, equalizer.LowGain = 0, 0, 0
	equalizer.Parent = group
	self._group = group
	self._equalizer = equalizer

	for areaId, area in Areas do
		local ambience = area.ambience
		if ambience and ambience.soundId ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = `Ambience_{areaId}`
			sound.SoundId = ambience.soundId
			sound.Looped = true
			sound.Volume = 0
			sound.SoundGroup = group
			sound.Parent = SoundService
			sound:Play()
			self._areaSounds[areaId] = sound
		end
	end

	local function route(instance: Instance)
		if instance:IsA("Sound") then
			instance.SoundGroup = group
		end
	end
	for _, sound in CollectionService:GetTagged(World.Tags.AmbientSound) do
		route(sound)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.AmbientSound):Connect(route)

	local controller = self._controller
	controller.StateChanged:Connect(function()
		self:_syncArea()
	end)
	controller.InventoryChanged:Connect(function()
		self:_applyMix()
	end)
	Settings.Changed:Connect(function(key)
		if key == "environmentAudio" then
			self:_applyMix()
		end
	end)
	self:_applyMix()
end

function AudioController:_syncArea()
	local area = self._controller:getArea()
	if area == self._currentArea then
		return
	end
	local previous = self._areaSounds[self._currentArea or ""]
	if previous then
		TweenService:Create(previous, CROSSFADE, { Volume = 0 }):Play()
	end
	self._currentArea = area
	local nextSound = area and self._areaSounds[area]
	if nextSound then
		TweenService:Create(nextSound, CROSSFADE, { Volume = Areas[area].ambience.volume }):Play()
	end
end

function AudioController:_applyMix()
	local volume = 1
	local muffle = false
	for _, item in self._controller:getEquippedItems() do
		local effects = item.effects
		if effects then
			volume = math.min(volume, effects.environmentVolume or 1)
			muffle = muffle or effects.muffle == true
		end
	end
	if not Settings.get("environmentAudio") then
		volume = 0
	end
	TweenService:Create(self._group, MIX, { Volume = volume }):Play()
	TweenService:Create(self._equalizer, MIX, if muffle then MUFFLED else CLEAR):Play()
end

return AudioController
