--[[
	UIState

	The single source of truth for which major interaction is on screen.
	Only one session can be active at a time, and it moves through stages:

		Idle      nothing active; prompts work, ambient chatter can play
		Speaking  an NPC is talking to the player (speech bubble), before
		          any choice appears
		Choice    the scenario choice panel is open
		Feedback  the "What happened" panel is open
		Task      a short guided action (e.g. slow breathing on a bench)

	How it is used:
	- A module starts a session with begin(owner, stage, info) and gets a
	  token. begin fails while another session is active, so two
	  interactions can never open at once.
	- Only the holder of the current token can change the stage or finish
	  the session. Delayed callbacks from an old session (a line timer, a
	  task.delay) check isCurrent(token) and stop, so stale dialogue can't
	  reappear after the player has moved on.
	- cancel(reason) ends whatever is active (death, respawn, restart) and
	  fires Cancelled so every owner cleans up its own UI.

	Listeners: App renders panels from the stage, InteractionController
	disables every prompt unless the stage is Idle, NPC speech and ambient
	chatter clear themselves on stage changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local Stage = table.freeze({
	Idle = "Idle",
	Speaking = "Speaking",
	Choice = "Choice",
	Feedback = "Feedback",
	Task = "Task",
})

local UIState = {}
UIState.__index = UIState
UIState.Stage = Stage

function UIState.new()
	return setmetatable({
		-- Changed(stage, previousStage, info)
		Changed = Signal.new(),
		-- Cancelled(owner, reason, info)
		Cancelled = Signal.new(),
		-- The player asked to skip to the next spoken line.
		AdvanceRequested = Signal.new(),

		_stage = Stage.Idle,
		_token = 0,
		_owner = nil :: string?,
		_info = nil :: { [string]: any }?,
	}, UIState)
end

function UIState:getStage(): string
	return self._stage
end

function UIState:isIdle(): boolean
	return self._stage == Stage.Idle
end

function UIState:getOwner(): string?
	return self._owner
end

function UIState:getInfo(): { [string]: any }?
	return self._info
end

function UIState:isCurrent(token: number?): boolean
	return token ~= nil and token == self._token and self._stage ~= Stage.Idle
end

function UIState:_setStage(stage: string, info: { [string]: any }?)
	local previous = self._stage
	self._stage = stage
	if info ~= nil then
		self._info = info
	end
	if previous ~= stage then
		self.Changed:Fire(stage, previous, self._info)
	end
end

-- Starts a session. Returns its token, or nil if something else is active.
function UIState:begin(owner: string, stage: string, info: { [string]: any }?): number?
	if self._stage ~= Stage.Idle or stage == Stage.Idle then
		return nil
	end
	self._token += 1
	self._owner = owner
	self._info = info or {}
	self:_setStage(stage)
	return self._token
end

-- Moves the current session to another stage. Ignored for stale tokens.
function UIState:set(token: number, stage: string, info: { [string]: any }?): boolean
	if not self:isCurrent(token) or stage == Stage.Idle then
		return false
	end
	self:_setStage(stage, info)
	return true
end

-- Ends the current session normally. Ignored for stale tokens.
function UIState:finish(token: number?): boolean
	if not self:isCurrent(token) then
		return false
	end
	self._token += 1
	self._owner = nil
	self._info = nil
	self:_setStage(Stage.Idle)
	return true
end

-- Ends whatever is active, for any reason ("respawn", "restart", ...).
function UIState:cancel(reason: string)
	if self._stage == Stage.Idle then
		return
	end
	local owner, info = self._owner, self._info
	self._token += 1
	self._owner = nil
	self._info = nil
	self:_setStage(Stage.Idle)
	self.Cancelled:Fire(owner, reason, info)
end

-- Skip to the next spoken line (only meaningful while Speaking).
function UIState:requestAdvance()
	if self._stage == Stage.Speaking then
		self.AdvanceRequested:Fire()
	end
end

return UIState
