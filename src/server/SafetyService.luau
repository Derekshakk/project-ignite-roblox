--[[
	SafetyService

	Keeps characters on the map now that there's no giant baseplate under
	it. The world has its own ground and an invisible boundary; as a last
	resort, a character that falls below the ground is put back where it
	last stood safely (or at the spawn point), without a respawn.
]]

local Players = game:GetService("Players")

local CHECK_INTERVAL = 0.5
local FALL_LIMIT_Y = -25
local SAFE_MIN_Y = -2

local SafetyService = {}

function SafetyService.start(fallback: () -> CFrame?)
	-- Below the recovery height, but well above the engine's default.
	workspace.FallenPartsDestroyHeight = -200

	local lastSafe: { [Player]: CFrame } = {}
	Players.PlayerRemoving:Connect(function(player)
		lastSafe[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not humanoid or not root or humanoid.Health <= 0 then
					continue
				end
				if root.Position.Y < FALL_LIMIT_Y then
					local target = lastSafe[player] or fallback()
					if target then
						character:PivotTo(target + Vector3.new(0, 3, 0))
						root.AssemblyLinearVelocity = Vector3.zero
					end
				elseif humanoid.FloorMaterial ~= Enum.Material.Air and not humanoid.SeatPart and root.Position.Y > SAFE_MIN_Y then
					lastSafe[player] = root.CFrame
				end
			end
		end
	end)
end

return SafetyService
