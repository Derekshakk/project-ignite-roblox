--[[
	GuidedTask

	Short physical actions instead of one-click menus. An activity with a
	`guided` definition (Data/Activities) is done as a task: breathing on
	the alcove bench, stretching on the bedroom mat, waiting by the hallway
	wall for the rush to pass. Steps, repeated for `cycles` rounds:

		hold     hold E / X (gamepad) / the circle until it fills
		release  let go; the circle empties over `seconds`
		still    stand still until it fills (moving lets it settle back)

	There is no way to fail: letting go early or moving just lets the
	progress settle back. Finishing performs the activity through the
	GameController (effects, time, flags). Stopping early does nothing, so
	the player can come back.

	Started two ways:
	- sitting on a seat with a RecoveryActivity (stand up to stop)
	- an Activity prompt whose activity is guided (walk away to stop)

	The task holds a UIState "Task" session, so prompts, NPC chatter and
	other interactions stay out of the way until it ends.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Activities = require(Shared.Data.Activities)
local GameController = require(Shared.Game.GameController)
local TaskGuide = require(script.Parent.Parent.UI.Hud.TaskGuide)
local PlayerControl = require(script.Parent.PlayerControl)

local ACTION = "IgniteGuidedTask"
local OWNER = "task"
-- Prompt-started tasks stop if the player walks this far away.
local LEAVE_DISTANCE = 9
local SEATED_HINT = "Jump to stand up any time."
local STANDING_HINT = "Walk away to stop any time."

local player = Players.LocalPlayer

local GuidedTask = {}
GuidedTask.__index = GuidedTask

function GuidedTask.new(controller, uiState, feedback, playerGui: PlayerGui)
	return setmetatable({
		_controller = controller,
		_uiState = uiState,
		_feedback = feedback,
		_playerGui = playerGui,
		_active = nil :: any,
		_characterConnections = {} :: { RBXScriptConnection },
	}, GuidedTask)
end

function GuidedTask:start()
	local function onCharacter(character: Model)
		for _, connection in self._characterConnections do
			connection:Disconnect()
		end
		table.clear(self._characterConnections)
		self:_cleanup()
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		table.insert(self._characterConnections, humanoid.Seated:Connect(function(active, seat)
			local activityId = active and seat and seat:GetAttribute(World.Attributes.RecoveryActivity)
			if type(activityId) == "string" then
				self:begin(activityId, nil)
			elseif self._active and self._active.seated then
				self:_cleanup()
			end
		end))
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- Death, respawn, restart: whoever cancels the session, clean up here.
	self._uiState.Cancelled:Connect(function(owner)
		if owner == OWNER then
			self:_cleanup()
		end
	end)
end

function GuidedTask.isGuided(activityId: string): boolean
	local activity = Activities.get(activityId)
	return activity ~= nil and activity.guided ~= nil
end

--[[
	Starts the guided task for an activity. `anchor` is where a standing
	task happens (walking away from it stops the task); nil for a seat.
	Returns true if it started.
]]
function GuidedTask:begin(activityId: string, anchor: Vector3?): boolean
	local controller = self._controller
	local activity = Activities.get(activityId)
	local guided = activity and activity.guided
	if not guided or self._active or controller:getPhase() ~= GameController.Phase.Exploring then
		return false
	end
	if not controller:getInteraction(World.InteractionTypes.Activity, activityId).available then
		return false
	end
	local token = self._uiState:begin(OWNER, self._uiState.Stage.Task, { activityId = activityId })
	if not token then
		return false
	end

	local active = {
		token = token,
		activityId = activityId,
		guided = guided,
		seated = anchor == nil,
		anchor = anchor,
		stepIndex = 1,
		cycle = 0,
		fill = 0,
		waitingForRelease = false,
		keyHeld = false,
		circleHeld = false,
	}
	self._active = active
	active.guide = TaskGuide.new(self._playerGui, guided.title, if anchor then STANDING_HINT else SEATED_HINT, guided.cycles, function(holding)
		active.circleHeld = holding
	end)
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			active.keyHeld = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			active.keyHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonR2)
	active.connection = RunService.Heartbeat:Connect(function(dt)
		self:_step(active, dt)
	end)
	self:_step(active, 0)
	return true
end

local function isMoving(): boolean
	local humanoid = PlayerControl.getHumanoid()
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
end

-- Moves to the next step (and round). Returns true when the task is done.
function GuidedTask:_advance(active): boolean
	local steps = active.guided.steps
	active.stepIndex += 1
	if active.stepIndex > #steps then
		active.stepIndex = 1
		active.cycle += 1
		active.guide:setRounds(active.cycle)
		self._feedback:cue("step")
		if active.cycle >= active.guided.cycles then
			return true
		end
	end
	local step = steps[active.stepIndex]
	-- Fill direction: hold/still fill up from empty, release empties.
	active.fill = if step.input == "release" then active.fill else 0
	return false
end

function GuidedTask:_step(active, dt: number)
	if self._active ~= active then
		return
	end
	if not self._uiState:isCurrent(active.token) then
		self:_cleanup()
		return
	end
	if active.anchor then
		local position = PlayerControl.getRootPosition()
		if position and (position - active.anchor).Magnitude > LEAVE_DISTANCE then
			self:_cleanup()
			return
		end
	end

	local steps = active.guided.steps
	local step = steps[active.stepIndex]
	local nextStep = steps[active.stepIndex % #steps + 1]
	local holding = active.keyHeld or active.circleHeld
	local text = step.text
	local done = false

	if step.input == "hold" then
		if active.waitingForRelease then
			text = nextStep.ready or "Now let go"
			if not holding then
				active.waitingForRelease = false
				done = self:_advance(active)
			end
		elseif holding then
			active.fill = math.min(1, active.fill + dt / step.seconds)
			if active.fill >= 1 then
				if nextStep.input == "release" and #steps > 1 then
					active.waitingForRelease = true
				else
					done = self:_advance(active)
				end
			end
		else
			-- Letting go early is fine: the circle just settles back.
			active.fill = math.max(0, active.fill - dt / (step.seconds * 1.5))
			text = if active.fill > 0 then "Keep holding…" else step.idle or step.text
		end
	elseif step.input == "release" then
		active.fill = math.max(0, active.fill - dt / step.seconds)
		if active.fill <= 0 then
			done = self:_advance(active)
		end
	elseif step.input == "still" then
		if isMoving() then
			active.fill = math.max(0, active.fill - dt / step.seconds)
			text = step.idle or step.text
		else
			active.fill = math.min(1, active.fill + dt / step.seconds)
			if active.fill >= 1 then
				done = self:_advance(active)
			end
		end
	end

	if done then
		self:_complete(active)
		return
	end
	active.guide:setFill(active.fill)
	active.guide:setHolding(holding or (step.input == "still" and not isMoving()))
	active.guide:setText(text)
end

function GuidedTask:_complete(active)
	local activityId = active.activityId
	self:_cleanup()
	self._feedback:cue("complete")
	self._controller:performActivity(activityId)
end

-- Ends the task (finished, stood up, walked away, or cancelled).
function GuidedTask:_cleanup()
	local active = self._active
	if not active then
		return
	end
	self._active = nil
	ContextActionService:UnbindAction(ACTION)
	if active.connection then
		active.connection:Disconnect()
	end
	active.guide:destroy()
	self._uiState:finish(active.token)
end

return GuidedTask
