--[[
	SceneDirector

	Brings NPCs into scenes:
	- Scenario with a `speaker`: while the scenario is open the speaker
	  turns toward the player and talks; its `introLines` play as captions
	  during the lead-in. When the player has chosen (or stepped away) the
	  speaker returns to idle.
	- Sitting in a seat with a ListenTo NPC (e.g. a classroom chair): that
	  NPC talks to the player and its `lectureLines` play as captions while
	  exploring, until the player stands up.
	NPC names and lines come from Data/Npcs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Npcs = require(Shared.Data.Npcs)
local GameController = require(Shared.Game.GameController)

local LECTURE_LINE_SECONDS = 5
local LECTURE_GAP_SECONDS = 1.5

local player = Players.LocalPlayer

local SceneDirector = {}
SceneDirector.__index = SceneDirector

function SceneDirector.new(controller, npcAnimator, captions, notify: (any) -> ())
	return setmetatable({
		_controller = controller,
		_npcs = npcAnimator,
		_captions = captions,
		_notify = notify,
		_scenarioSpeaker = nil :: string?,
		_listeningTo = nil :: string?,
		_seatedHintShown = false,
	}, SceneDirector)
end

local function speakerName(npcId: string): string
	local npc = Npcs[npcId]
	return if npc then npc.name else npcId
end

function SceneDirector:start()
	self._controller.Changed:Connect(function(phase)
		self:_onPhase(phase)
	end)
	local function onCharacter(character: Model)
		self:_stopListening()
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Seated:Connect(function(active, seat)
				local npcId = active and seat and seat:GetAttribute(World.Attributes.ListenTo)
				if type(npcId) == "string" then
					self:_startListening(npcId)
				else
					self:_stopListening()
				end
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function SceneDirector:_onPhase(phase: string)
	if phase == GameController.Phase.Scenario then
		local scenario = self._controller:getView().scenario
		local speaker = scenario and scenario.speaker
		if speaker and not self._scenarioSpeaker then
			self._scenarioSpeaker = speaker
			self._npcs:startDialogue(speaker)
			if scenario.introLines then
				self._captions:playSequence(speakerName(speaker), scenario.introLines, scenario.leadInSeconds or 4, "scenario")
			end
		end
	elseif self._scenarioSpeaker then
		self._npcs:endDialogue(self._scenarioSpeaker)
		self._scenarioSpeaker = nil
		self._captions:stop("scenario")
	end
	if phase == GameController.Phase.CharacterSelect then
		self:_stopListening()
	end
end

function SceneDirector:_startListening(npcId: string)
	if self._listeningTo == npcId then
		return
	end
	self:_stopListening()
	self._listeningTo = npcId
	self._npcs:startDialogue(npcId)
	if not self._seatedHintShown then
		self._seatedHintShown = true
		self._notify({ title = "Seated", message = "Press Space (jump) to stand up." })
	end

	local npc = Npcs[npcId]
	local lines = npc and npc.lectureLines
	if not lines or #lines == 0 then
		return
	end
	task.spawn(function()
		local index = 0
		while self._listeningTo == npcId do
			-- Scenario captions take priority while a dialog is open.
			if self._controller:getPhase() == GameController.Phase.Exploring then
				index = index % #lines + 1
				self._captions:show(npc.name, lines[index], LECTURE_LINE_SECONDS, "lecture")
			end
			task.wait(LECTURE_LINE_SECONDS + LECTURE_GAP_SECONDS)
		end
	end)
end

function SceneDirector:_stopListening()
	if self._listeningTo then
		self._npcs:endDialogue(self._listeningTo)
		self._listeningTo = nil
		self._captions:stop("lecture")
	end
end

return SceneDirector
