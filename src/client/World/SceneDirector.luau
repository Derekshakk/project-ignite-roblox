--[[
	SceneDirector

	Runs every NPC conversation through UIState so dialogue, choices and
	feedback never overlap:

	Scenario with a speaker (e.g. the teacher's group project, Sam):
		1. Speaking  the NPC turns toward the player, then says its
		             `introLines` one at a time in a speech bubble (the
		             player can skip ahead with E / Enter / the Next button)
		2. Choice    the bubble is cleared *before* the choice panel opens;
		             with `crowdReaction = "chat"`, nearby NPCs turn to each
		             other and talk (no bubbles)
		3. Feedback  the speaker reacts (`npcReaction`, e.g. a nod)
		4. Idle      the speaker turns back to idle and may say a short
		             reply (`npcLine`) now that the panels are closed
	Line timing is owned here (no independent caption timers), and every
	step checks its UIState token, so a cancelled or finished scene can't
	leave a line on screen or reopen anything.

	Also:
	- Activity feedback panels (no speaker) hold a Feedback session.
	- Sitting in a seat with ListenTo: that NPC faces the player and gives
	  lecture lines while nothing else is happening, until they stand up.
	- Named NPCs with a `greeting` (Data/Npcs) wave and say hello once when
	  the player first comes near, while their scenario is still available.
	- Activities with an `npcReaction` make that NPC look over, react and
	  reply (e.g. the teacher after a question note is left on her desk).
	- Death, respawn, restart or results cancel everything: bubbles,
	  captions, NPC attention, and any open scenario or feedback panel.
	- Captions show the line at the bottom of the screen only when the
	  speaker is off-screen (Settings: Captions).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Npcs = require(Shared.Data.Npcs)
local Scenarios = require(Shared.Data.Scenarios)
local GameController = require(Shared.Game.GameController)
local NpcRegistry = require(script.Parent.NpcRegistry)
local NpcSpeech = require(script.Parent.NpcSpeech)
local PlayerControl = require(script.Parent.PlayerControl)

local Phase = GameController.Phase
local Kind = NpcSpeech.Kind

-- Time for the speaker to turn toward the player before the first line.
local TURN_SECONDS = 0.7
-- A skip is ignored right after a line appears (avoids double skips).
local MIN_LINE_SECONDS = 0.35
local BUBBLE_FADE_SECONDS = 0.22
local LECTURE_FIRST_DELAY = 1.5
local LECTURE_LINE_SECONDS = 5
local LECTURE_GAP_SECONDS = 1.5
local REPLY_DELAY = 0.4
local GREETING_CHECK_SECONDS = 0.25
local CROWD_RADIUS = 26
local CROWD_CHAT_SECONDS = 14
-- Beyond this the scene is abandoned (e.g. the player was moved away).
local MAX_SPEAKER_DISTANCE = 45
local ADVANCE_ACTION = "IgniteAdvanceDialogue"

local player = Players.LocalPlayer

local SceneDirector = {}
SceneDirector.__index = SceneDirector

function SceneDirector.new(controller, uiState, npcAnimator, speech, captions, notify: (any) -> ())
	return setmetatable({
		_controller = controller,
		_uiState = uiState,
		_npcs = npcAnimator,
		_speech = speech,
		_captions = captions,
		_notify = notify,
		-- { token, speaker?, scenario?, choice? }
		_session = nil :: any,
		_advance = false,
		_listeningTo = nil :: string?,
		_listenToken = 0,
		_seatedHintShown = false,
		_greeted = {} :: { [string]: boolean },
		_characterConnections = {} :: { RBXScriptConnection },
	}, SceneDirector)
end

local function speakerName(npcId: string): string
	local npc = Npcs[npcId]
	return if npc then npc.name else npcId
end

local function lineOf(entry: any): (string, string?)
	if type(entry) == "table" then
		return entry.text, entry.reaction
	end
	return entry, nil
end

function SceneDirector:start()
	NpcRegistry.start()
	self._controller.Changed:Connect(function(phase)
		self:_onPhase(phase)
	end)
	self._controller.ActivityPerformed:Connect(function(_, resolved)
		self:_onActivity(resolved)
	end)
	self._uiState.AdvanceRequested:Connect(function()
		self._advance = true
	end)
	self._uiState.Changed:Connect(function(stage)
		self:_onStage(stage)
	end)

	local function onCharacter(character: Model)
		for _, connection in self._characterConnections do
			connection:Disconnect()
		end
		table.clear(self._characterConnections)
		self:_cancelAll("respawn")
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		table.insert(self._characterConnections, humanoid.Seated:Connect(function(active, seat)
			local npcId = active and seat and seat:GetAttribute(World.Attributes.ListenTo)
			if type(npcId) == "string" then
				self:_startListening(npcId)
			else
				self:_stopListening()
			end
		end))
		table.insert(self._characterConnections, humanoid.Died:Connect(function()
			self:_cancelAll("respawn")
		end))
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	local sinceGreetingCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceGreetingCheck += dt
		if sinceGreetingCheck >= GREETING_CHECK_SECONDS then
			sinceGreetingCheck = 0
			self:_checkGreetings()
		end
	end)
end

---------------------------------------------------------------------------
-- Phases and stages
---------------------------------------------------------------------------

function SceneDirector:_onPhase(phase: string)
	if phase == Phase.Scenario then
		self:_beginScenario(self._controller:getView().scenario)
	elseif phase == Phase.Feedback then
		self:_beginFeedback(self._controller:getView().result)
	elseif phase == Phase.Exploring then
		self:_endSession()
	else
		-- Character select or results: nothing from the day should linger.
		self:_cancelAll(phase)
		if phase == Phase.CharacterSelect then
			table.clear(self._greeted)
		end
	end
end

function SceneDirector:_onStage(stage: string)
	local Stage = self._uiState.Stage
	if stage == Stage.Speaking then
		ContextActionService:BindActionAtPriority(ADVANCE_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				self._uiState:requestAdvance()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction(ADVANCE_ACTION)
	end
	if stage ~= Stage.Speaking then
		-- Whatever was being said is over once the panels take over.
		self._speech:clearAll(Kind.Scene)
		self._captions:stop()
	end
	local session = self._session
	if stage == Stage.Choice and session and session.scenario and session.scenario.crowdReaction == "chat" then
		local model = NpcRegistry.get(session.speaker)
		local root = model and NpcRegistry.getRoot(model)
		if root then
			self._npcs:reactNear(root.Position, CROWD_RADIUS, "chat", { seconds = CROWD_CHAT_SECONDS }, model)
		end
	end
end

-- Clears every line on screen (a new scene is taking over).
function SceneDirector:_clearSpeech()
	self._speech:clearAll()
	self._captions:stop()
end

function SceneDirector:_beginScenario(scenario)
	if not scenario then
		return
	end
	self:_clearSpeech()
	local Stage = self._uiState.Stage
	local previous = self._session
	if previous and previous.speaker then
		self._npcs:endDialogue(previous.speaker)
	end
	if not self._uiState:isIdle() then
		self._uiState:cancel("superseded")
	end
	local speaker = scenario.speaker
	local hasIntro = speaker ~= nil and scenario.introLines ~= nil and #scenario.introLines > 0
	-- Set before begin(): stage listeners read the session.
	local session = { token = nil :: number?, speaker = speaker, scenario = scenario }
	self._session = session
	local token = self._uiState:begin("scenario", if hasIntro then Stage.Speaking else Stage.Choice, {
		scenarioId = scenario.id,
		speaker = speaker,
	})
	session.token = token
	if speaker then
		self._npcs:startDialogue(speaker)
	end
	if hasIntro then
		task.spawn(function()
			local ok, err = pcall(self._playIntro, self, scenario, token)
			if not ok then
				-- Never leave the player waiting on a broken intro.
				warn(`[SceneDirector] {err}`)
				self._uiState:set(token, Stage.Choice)
			end
		end)
	end
end

-- Waits `seconds`, or less if the player skips. False if the scene ended.
function SceneDirector:_wait(seconds: number, token: number, skippable: boolean, speaker: string?): boolean
	local started = os.clock()
	while os.clock() - started < seconds do
		if not self._uiState:isCurrent(token) then
			return false
		end
		if speaker and self:_isTooFar(speaker) then
			self:_abandonScenario()
			return false
		end
		if skippable and self._advance and os.clock() - started >= MIN_LINE_SECONDS then
			break
		end
		task.wait()
	end
	self._advance = false
	return self._uiState:isCurrent(token)
end

function SceneDirector:_isTooFar(npcId: string): boolean
	local model = NpcRegistry.get(npcId)
	local root = model and NpcRegistry.getRoot(model)
	local position = PlayerControl.getRootPosition()
	return root ~= nil and position ~= nil and (root.Position - position).Magnitude > MAX_SPEAKER_DISTANCE
end

function SceneDirector:_abandonScenario()
	if self._controller:getPhase() == Phase.Scenario then
		self._controller:cancelScenario()
	end
end

function SceneDirector:_playIntro(scenario, token: number)
	local speaker = scenario.speaker
	local lines = scenario.introLines
	local minimumPerLine = (scenario.leadInSeconds or 0) / #lines
	self._advance = false
	if not self:_wait(TURN_SECONDS, token, false, speaker) then
		return
	end
	for _, entry in lines do
		local text, reaction = lineOf(entry)
		if reaction then
			self._npcs:react(speaker, reaction, { target = "player" })
		end
		local seconds = math.max(NpcSpeech.readingTime(text), minimumPerLine)
		self._speech:say(speaker, text, nil, Kind.Scene)
		self:_captionIfOffscreen(speaker, text, seconds)
		if not self:_wait(seconds, token, true, speaker) then
			return
		end
	end
	-- Let the bubble finish fading before the choice panel appears.
	self._speech:clear(speaker, Kind.Scene)
	self._captions:stop()
	if self:_wait(BUBBLE_FADE_SECONDS, token, false) then
		self._uiState:set(token, self._uiState.Stage.Choice)
	end
end

function SceneDirector:_captionIfOffscreen(npcId: string, text: string, seconds: number)
	local model = NpcRegistry.get(npcId)
	local onScreen = false
	if model then
		local _, visible = NpcSpeech.screenPoint(model)
		onScreen = visible
	end
	if not onScreen then
		self._captions:show(speakerName(npcId), text, seconds, "scene")
	end
end

function SceneDirector:_beginFeedback(result)
	self:_clearSpeech()
	local Stage = self._uiState.Stage
	local session = self._session
	if session and self._uiState:isCurrent(session.token) then
		-- The scenario continues into its feedback panel.
		self._uiState:set(session.token, Stage.Feedback)
		local scenario = result and result.scenarioId and Scenarios.get(result.scenarioId)
		local choice = scenario and result.choiceId and Scenarios.getChoice(scenario, result.choiceId)
		session.choice = choice
		if choice and choice.npcReaction and session.speaker then
			self._npcs:react(session.speaker, choice.npcReaction, { target = "player" })
		end
		return
	end
	-- Activity feedback (no scene before it).
	if not self._uiState:isIdle() then
		self._uiState:cancel("superseded")
	end
	local token = self._uiState:begin("feedback", Stage.Feedback, { activityId = result and result.activityId })
	self._session = { token = token }
end

-- Back to exploring: close the session and let the speaker relax.
function SceneDirector:_endSession()
	local session = self._session
	self._session = nil
	self:_clearSpeech()
	if not session then
		return
	end
	self._uiState:finish(session.token)
	local speaker = session.speaker
	if not speaker then
		return
	end
	self._npcs:endDialogue(speaker)
	local line = session.choice and session.choice.npcLine
	if line then
		task.delay(REPLY_DELAY, function()
			-- Only if nothing else has started in the meantime.
			if self._uiState:isIdle() and self._controller:getPhase() == Phase.Exploring then
				self._npcs:react(speaker, "lookAt", { target = "player", seconds = 3 })
				self._speech:say(speaker, line, NpcSpeech.readingTime(line), Kind.Reply)
			end
		end)
	end
end

--[[
	Ends everything immediately (death, respawn, restart, results). On
	death/respawn it also closes an open scenario or feedback panel so the
	new character doesn't spawn into a stale dialog.
]]
function SceneDirector:_cancelAll(reason: string)
	self:_stopListening()
	local session = self._session
	self._session = nil
	if session and session.speaker then
		self._npcs:endDialogue(session.speaker)
	end
	self._uiState:cancel(reason)
	self:_clearSpeech()
	if reason == "respawn" then
		self._npcs:resetDialogue()
		local phase = self._controller:getPhase()
		if phase == Phase.Scenario then
			self._controller:cancelScenario()
		elseif phase == Phase.Feedback then
			self._controller:continue()
		end
	end
end

function SceneDirector:_onActivity(resolved)
	local reaction = resolved and resolved.npcReaction
	local npcId = reaction and reaction.npc
	if not npcId then
		return
	end
	self._npcs:react(npcId, "lookAt", { target = "player", seconds = 4 })
	if reaction.reaction then
		self._npcs:react(npcId, reaction.reaction, { target = "player" })
	end
	local line = reaction.line
	if line then
		task.delay(REPLY_DELAY, function()
			if self._uiState:isIdle() and self._controller:getPhase() == Phase.Exploring then
				self._speech:say(npcId, line, NpcSpeech.readingTime(line), Kind.Reply)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Greetings
---------------------------------------------------------------------------

function SceneDirector:_checkGreetings()
	if self._controller:getPhase() ~= Phase.Exploring or not self._uiState:isIdle() then
		return
	end
	local position = PlayerControl.getRootPosition()
	if not position then
		return
	end
	for npcId, data in Npcs do
		if not data.greeting or self._greeted[npcId] then
			continue
		end
		local model = NpcRegistry.get(npcId)
		local root = model and NpcRegistry.getRoot(model)
		if not model or not root or (root.Position - position).Magnitude > (data.greetDistance or 15) then
			continue
		end
		if data.greetFor and not self._controller:getInteraction(World.InteractionTypes.Scenario, data.greetFor).available then
			continue
		end
		if self._speech:isSpeaking(model) then
			continue
		end
		self._greeted[npcId] = true
		self._npcs:react(npcId, "lookAt", { target = "player", seconds = 4 })
		self._npcs:react(npcId, data.greetReaction or "wave", { target = "player" })
		self._speech:say(npcId, data.greeting, NpcSpeech.readingTime(data.greeting), Kind.Reply)
	end
end

---------------------------------------------------------------------------
-- Listening from a seat
---------------------------------------------------------------------------

function SceneDirector:_startListening(npcId: string)
	if self._listeningTo == npcId then
		return
	end
	self:_stopListening()
	self._listeningTo = npcId
	self._listenToken += 1
	local token = self._listenToken
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
		-- A short pause first: sitting down may start a scenario, and its
		-- intro should never be preceded by a stray lecture line.
		task.wait(LECTURE_FIRST_DELAY)
		local index = 0
		while self._listenToken == token do
			local quiet = self._controller:getPhase() == Phase.Exploring
				and self._uiState:isIdle()
				and not self._speech:isSpeaking(npcId)
			if quiet then
				index = index % #lines + 1
				self._speech:say(npcId, lines[index], LECTURE_LINE_SECONDS, Kind.Lecture)
			end
			task.wait(LECTURE_LINE_SECONDS + LECTURE_GAP_SECONDS)
		end
	end)
end

function SceneDirector:_stopListening()
	local npcId = self._listeningTo
	if not npcId then
		return
	end
	self._listeningTo = nil
	self._listenToken += 1
	self._npcs:endDialogue(npcId)
	self._speech:clear(npcId, Kind.Lecture)
end

return SceneDirector
