--[[
	Crosswalks

	Pedestrian signals at street crossings (tagged IgniteCrosswalkSignal,
	built by OutdoorProps.crossingSignal). Each crosswalk id cycles slowly
	between "wait" (orange hand) and "walk" (white figure); pressing a walk
	button shortens the current wait. Light changes are a single switch
	every several seconds: no blinking countdown, nothing flashes.

	There's no penalty for crossing on "wait": the signal is there for the
	small, familiar moment of waiting at a busy road. Background traffic
	(World/Ambient) stops while it shows "walk", and always stops for
	anyone in the road; passers-by wait for "walk" (isWalking).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

local WAIT_SECONDS = 14
local WALK_SECONDS = 9
local BUTTON_WAIT_SECONDS = 3
local CHECK_INTERVAL = 0.2

local LIT_WAIT = Color3.fromRGB(255, 140, 56)
local DIM_WAIT = Color3.fromRGB(80, 60, 44)
local LIT_WALK = Color3.fromRGB(232, 240, 236)
local DIM_WALK = Color3.fromRGB(60, 64, 66)
-- Bundled with the Roblox client (PLACEHOLDER: a real walk-signal sound).
local WALK_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local Crosswalks = {}
Crosswalks.__index = Crosswalks

function Crosswalks.new()
	return setmetatable({
		-- id → { walking, changeAt, heads = { Model } }
		_crossings = {} :: { [string]: any },
	}, Crosswalks)
end

local function setLamp(part: Instance?, lit: boolean, litColor: Color3, dimColor: Color3)
	if part and part:IsA("BasePart") then
		part.Color = if lit then litColor else dimColor
		part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

function Crosswalks:_crossing(id: string)
	local crossing = self._crossings[id]
	if not crossing then
		-- Stagger crossings so they don't all change together.
		crossing = { walking = false, changeAt = os.clock() + WAIT_SECONDS * (0.4 + #id % 5 * 0.1), heads = {} }
		self._crossings[id] = crossing
	end
	return crossing
end

function Crosswalks:_show(crossing)
	for _, head in crossing.heads do
		if head.Parent then
			setLamp(head:FindFirstChild("Wait"), not crossing.walking, LIT_WAIT, DIM_WAIT)
			setLamp(head:FindFirstChild("Walk"), crossing.walking, LIT_WALK, DIM_WALK)
		end
	end
end

function Crosswalks:start()
	local function add(instance: Instance)
		local id = instance:GetAttribute(World.Attributes.CrosswalkId)
		if type(id) == "string" then
			local crossing = self:_crossing(id)
			table.insert(crossing.heads, instance)
			self:_show(crossing)
		end
	end
	for _, instance in CollectionService:GetTagged(World.Tags.CrosswalkSignal) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.CrosswalkSignal):Connect(add)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local now = os.clock()
			for _, crossing in self._crossings do
				if now >= crossing.changeAt then
					crossing.walking = not crossing.walking
					crossing.changeAt = now + (if crossing.walking then WALK_SECONDS else WAIT_SECONDS)
					self:_show(crossing)
					if crossing.walking then
						self:_chirp(crossing)
					end
				end
			end
		end
	end)
end

function Crosswalks:_chirp(crossing)
	local head = crossing.heads[1]
	local lamp = head and head:FindFirstChild("Walk")
	if not lamp then
		return
	end
	local sound = lamp:FindFirstChild("IgniteWalkSound") :: Sound?
	if not sound then
		local created = Instance.new("Sound")
		created.Name = "IgniteWalkSound"
		created.SoundId = WALK_SOUND
		created.Volume = 0.12
		created.PlaybackSpeed = 1.3
		created.RollOffMaxDistance = 40
		created.Parent = lamp
		sound = created
	end
	(sound :: Sound):Play()
end

-- Whether crosswalk `id` currently shows "walk".
function Crosswalks:isWalking(id: string): boolean
	local crossing = self._crossings[id]
	return crossing ~= nil and crossing.walking
end

-- A walk button was pressed: the wait ends a little sooner.
function Crosswalks:request(id: string)
	local crossing = self:_crossing(id)
	if not crossing.walking then
		crossing.changeAt = math.min(crossing.changeAt, os.clock() + BUTTON_WAIT_SECONDS)
	end
end

return Crosswalks
