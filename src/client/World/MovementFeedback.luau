--[[
	MovementFeedback

	Small, comfortable game-feel touches for the player's own character:
	- Footsteps: Roblox's default running sound, re-voiced per floor
	  material (soft on carpet, warmer on wood, crisper on tile) with an
	  equalizer and volume change. No new assets needed.
	- Landing: after a real fall (not a hop), the camera dips very slightly
	  and recovers. Off when Settings "Camera motion" is off.
	There is no camera shake or head bob.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Parent.Settings)

local player = Players.LocalPlayer

-- Floor material name → footstep voicing.
local PROFILES = {
	Carpet = { volume = 0.45, HighGain = -10, MidGain = -2, LowGain = 0 },
	Fabric = { volume = 0.45, HighGain = -10, MidGain = -2, LowGain = 0 },
	WoodPlanks = { volume = 0.8, HighGain = -3, MidGain = 0, LowGain = 2 },
	Wood = { volume = 0.8, HighGain = -3, MidGain = 0, LowGain = 2 },
	CeramicTiles = { volume = 0.95, HighGain = 2, MidGain = 0, LowGain = -1 },
	Slate = { volume = 0.95, HighGain = 2, MidGain = 0, LowGain = -1 },
	Marble = { volume = 0.95, HighGain = 2, MidGain = 0, LowGain = -1 },
}
local DEFAULT_PROFILE = { volume = 0.85, HighGain = 0, MidGain = 0, LowGain = 0 }

local MIN_FALL_SECONDS = 0.35
local DIP_DOWN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DIP_UP = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local MovementFeedback = {}

local function setupFootsteps(humanoid: Humanoid, root: BasePart)
	local running = root:WaitForChild("Running", 5) :: Sound?
	if not running then
		return
	end
	local baseVolume = running.Volume
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "SurfaceVoicing"
	equalizer.Parent = running

	local function apply()
		local profile = PROFILES[humanoid.FloorMaterial.Name] or DEFAULT_PROFILE
		running.Volume = baseVolume * profile.volume
		equalizer.HighGain = profile.HighGain
		equalizer.MidGain = profile.MidGain
		equalizer.LowGain = profile.LowGain
	end
	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(apply)
	apply()
end

local function setupLanding(humanoid: Humanoid)
	local fallStarted: number? = nil
	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Freefall then
			fallStarted = os.clock()
		elseif newState == Enum.HumanoidStateType.Landed then
			local fell = fallStarted and os.clock() - fallStarted or 0
			fallStarted = nil
			if fell >= MIN_FALL_SECONDS and Settings.get("cameraMotion") then
				local down = TweenService:Create(humanoid, DIP_DOWN, { CameraOffset = Vector3.new(0, -0.22, 0) })
				down.Completed:Connect(function()
					TweenService:Create(humanoid, DIP_UP, { CameraOffset = Vector3.zero }):Play()
				end)
				down:Play()
			end
		end
	end)
end

function MovementFeedback.start()
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not humanoid or not root then
			return
		end
		setupLanding(humanoid)
		task.spawn(setupFootsteps, humanoid, root)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return MovementFeedback
