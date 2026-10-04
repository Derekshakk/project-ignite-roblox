--[[
	TravelService

	Moves a player's character between areas when the client asks (for
	example after using the bedroom door). The server owns this so it works
	with streaming and so clients can only travel to registered destinations.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Remotes = require(script.Parent.Remotes)

local COOLDOWN_SECONDS = 0.75
local STANDING_OFFSET = CFrame.new(0, 3, 0)

local TravelService = {}

function TravelService.start(destinations: { [string]: { cframe: CFrame, areaId: string } })
	local lastTravel: { [Player]: number } = {}

	Remotes.handle(World.Remotes.Travel, function(player: Player, destinationId: any)
		if type(destinationId) ~= "string" then
			return false
		end
		local destination = destinations[destinationId]
		if not destination then
			warn(`[TravelService] Unknown destination "{destinationId}".`)
			return false
		end

		local now = os.clock()
		if lastTravel[player] and now - lastTravel[player] < COOLDOWN_SECONDS then
			return false
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not root then
			return false
		end
		lastTravel[player] = now

		-- Leave any seat first, or the seat weld would pull the character back.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
		end

		local target = destination.cframe * STANDING_OFFSET
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 3)
		end)
		character:PivotTo(target)
		root.AssemblyLinearVelocity = Vector3.zero
		return true, destination.areaId
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
