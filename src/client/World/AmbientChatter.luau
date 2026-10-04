--[[
	AmbientChatter

	Background conversation: NPCs with ChatterLines say one of their lines
	in a small speech bubble now and then. It is scheduled centrally so the
	scene feels alive without becoming noise:
	- at most two background bubbles at once, never two from the same
	  group at the same time (a partner answers after the first line ends)
	- a new bubble only appears well apart on screen from existing ones
	- only nearby, on-screen NPCs speak, each with its own cooldown
	- it pauses entirely while any interaction (dialogue, choice, feedback,
	  task) is active or another NPC is talking to the player, and clears
	  its bubbles when one starts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local GameController = require(Shared.Game.GameController)
local NpcRegistry = require(script.Parent.NpcRegistry)
local NpcSpeech = require(script.Parent.NpcSpeech)
local PlayerControl = require(script.Parent.PlayerControl)

local Kind = NpcSpeech.Kind

local MAX_BUBBLES = 2
local HEAR_DISTANCE = 36
local MIN_SCREEN_GAP = 220 -- pixels between bubbles
local SPEAKER_COOLDOWN = 9
local REPLY_RADIUS = 5
local REPLY_CHANCE = 0.6

local AmbientChatter = {}
AmbientChatter.__index = AmbientChatter

function AmbientChatter.new(controller, uiState, speech)
	return setmetatable({
		_controller = controller,
		_uiState = uiState,
		_speech = speech,
		_random = Random.new(),
		_lastSpoke = {} :: { [Model]: number },
		_lastLine = {} :: { [Model]: string },
		-- conversation groups currently mid-exchange
		_busyGroups = {} :: { [Model]: boolean },
	}, AmbientChatter)
end

local function linesOf(model: Model): { string }?
	if model:GetAttribute("IgniteHidden") == true then
		return nil -- e.g. a student who has gone to class
	end
	local raw = model:GetAttribute(World.Attributes.ChatterLines)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	return string.split(raw, "|")
end

function AmbientChatter:start()
	NpcRegistry.start()
	local function clear()
		self._speech:clearAll(Kind.Ambient)
	end
	self._uiState.Changed:Connect(function()
		if not self._uiState:isIdle() then
			clear()
		end
	end)
	self._controller.Changed:Connect(function(phase)
		if phase ~= GameController.Phase.Exploring then
			clear()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(self._random:NextNumber(1.6, 3.4))
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn(`[AmbientChatter] {err}`)
			end
		end
	end)
end

function AmbientChatter:_canSpeak(): boolean
	return self._controller:getPhase() == GameController.Phase.Exploring
		and self._uiState:isIdle()
		-- Someone is talking to the player: keep the background quiet.
		and self._speech:count(nil, Kind.Ambient) == 0
		and Players.LocalPlayer.Character ~= nil
end

function AmbientChatter:_isFarFromBubbles(point: Vector2): boolean
	for _, other in self._speech:screenPositions() do
		if (other - point).Magnitude < MIN_SCREEN_GAP then
			return false
		end
	end
	return true
end

function AmbientChatter:_pickLine(model: Model): string?
	local lines = linesOf(model)
	if not lines then
		return nil
	end
	local line = lines[self._random:NextInteger(1, #lines)]
	if #lines > 1 and line == self._lastLine[model] then
		line = lines[(table.find(lines, line) :: number) % #lines + 1]
	end
	self._lastLine[model] = line
	return line
end

function AmbientChatter:_tick()
	if not self:_canSpeak() or self._speech:count(Kind.Ambient) >= MAX_BUBBLES then
		return
	end
	local position = PlayerControl.getRootPosition()
	if not position then
		return
	end
	local now = os.clock()

	local candidates = {}
	for _, model in NpcRegistry.all() do
		local root = NpcRegistry.getRoot(model)
		if
			root
			and not self._busyGroups[model]
			and linesOf(model)
			and not self._speech:isSpeaking(model)
			and now - (self._lastSpoke[model] or 0) > SPEAKER_COOLDOWN
			and (root.Position - position).Magnitude < HEAR_DISTANCE
		then
			local point, onScreen = NpcSpeech.screenPoint(model)
			if point and onScreen and self:_isFarFromBubbles(point) then
				table.insert(candidates, model)
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local speaker = candidates[self._random:NextInteger(1, #candidates)]
	self:_converse(speaker)
end

-- One line, and sometimes an answer from a partner once it has finished.
function AmbientChatter:_converse(speaker: Model)
	local line = self:_pickLine(speaker)
	if not line then
		return
	end
	local partner = NpcRegistry.nearestTo(speaker, REPLY_RADIUS, function(other)
		return linesOf(other) ~= nil and not self._speech:isSpeaking(other)
	end)
	self._busyGroups[speaker] = true
	if partner then
		self._busyGroups[partner] = true
	end

	task.spawn(function()
		local seconds = math.clamp(NpcSpeech.readingTime(line), 2.4, 4)
		self._lastSpoke[speaker] = os.clock()
		self._speech:say(speaker, line, seconds, Kind.Ambient)
		task.wait(seconds + 0.5)
		if partner and self._random:NextNumber() < REPLY_CHANCE and self:_canSpeak() then
			local reply = self:_pickLine(partner)
			if reply then
				local replySeconds = math.clamp(NpcSpeech.readingTime(reply), 2.4, 4)
				self._lastSpoke[partner] = os.clock()
				self._speech:say(partner, reply, replySeconds, Kind.Ambient)
				task.wait(replySeconds + 0.5)
			end
		end
		self._busyGroups[speaker] = nil
		if partner then
			self._busyGroups[partner] = nil
		end
	end)
end

return AmbientChatter
