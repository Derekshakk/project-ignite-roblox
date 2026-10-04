--[[
	AmbientAudio

	Quiet outdoor sound beds (birds, light wind) that fade in while the
	player is outside and out again indoors, plus a soft murmur at groups
	of chatting background neighbours. Everything is tagged as an ambient
	sound, so it goes through the environment sound group: headphones
	muffle it and "Environment sounds" in Settings mutes it.

	Ids come from Data/Ambient `sounds` (empty placeholders until Creator
	Store assets are added; the wind uses a bundled stand-in).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local NpcRegistry = require(script.Parent.Parent.NpcRegistry)

local FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local OUTDOOR_AREAS = { neighborhood = true }

local AmbientAudio = {}
AmbientAudio.__index = AmbientAudio

function AmbientAudio.new(life)
	return setmetatable({ _life = life, _beds = {} :: { [string]: Sound }, _outside = nil :: boolean? }, AmbientAudio)
end

local function soundId(spec): string?
	local id = if spec.id ~= "" then spec.id else spec.fallback
	return if id and id ~= "" then id else nil
end

function AmbientAudio:start()
	local sounds = self._life.data.sounds
	for _, name in { "birds", "wind" } do
		local spec = sounds[name]
		local id = soundId(spec)
		if id then
			local sound = Instance.new("Sound")
			sound.Name = `IgniteAmbient_{name}`
			sound.SoundId = id
			sound.Looped = true
			sound.Volume = 0
			sound.PlaybackSpeed = spec.speed or 1
			CollectionService:AddTag(sound, World.Tags.AmbientSound)
			sound.Parent = SoundService
			self._beds[name] = sound
		end
	end

	-- Murmur at chatting neighbours (talkative NPCs without lines or a name).
	local murmur = sounds.murmur
	local murmurId = soundId(murmur)
	if murmurId then
		local function add(model: Model)
			local root = NpcRegistry.getRoot(model)
			if
				root
				and model:GetAttribute(World.Attributes.Talkative) == true
				and model:GetAttribute(World.Attributes.ChatterLines) == nil
				and model:GetAttribute(World.Attributes.NpcId) == nil
				and not root:FindFirstChild("Murmur")
			then
				local sound = Instance.new("Sound")
				sound.Name = "Murmur"
				sound.SoundId = murmurId
				sound.Looped = true
				sound.Volume = murmur.volume
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = 4
				sound.RollOffMaxDistance = 30
				CollectionService:AddTag(sound, World.Tags.AmbientSound)
				sound.Parent = root
				sound:Play()
			end
		end
		for _, model in NpcRegistry.all() do
			add(model)
		end
		NpcRegistry.Added:Connect(add)
	end
	self:update()
end

-- Fades the outdoor beds when the player's area changes.
function AmbientAudio:update()
	local outside = OUTDOOR_AREAS[self._life.controller:getArea() or ""] == true
	if outside == self._outside then
		return
	end
	self._outside = outside
	local sounds = self._life.data.sounds
	for name, sound in self._beds do
		if outside and not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, FADE, { Volume = if outside then sounds[name].volume else 0 }):Play()
	end
end

return AmbientAudio
