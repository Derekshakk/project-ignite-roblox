--[[
	SeatService

	Seats players in chairs on request (from a Sit prompt). Seats are
	Disabled by default so walking into a chair never sits you by accident;
	a seat is enabled only while a player is being seated in it and goes
	back to Disabled when they stand up (jump).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)
local Remotes = require(script.Parent.Remotes)

local MAX_DISTANCE = 14

local SeatService = {}

function SeatService.start(seats: { [string]: Seat })
	for _, seat in seats do
		seat.Disabled = true
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not seat.Occupant then
				seat.Disabled = true
			end
		end)
	end

	Remotes.handle(World.Remotes.Sit, function(player: Player, seatId: any)
		local seat = type(seatId) == "string" and seats[seatId]
		if not seat or seat.Occupant then
			return false
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
			return false
		end
		if (root.Position - seat.Position).Magnitude > MAX_DISTANCE then
			return false
		end
		seat.Disabled = false
		seat:Sit(humanoid)
		return true
	end)
end

return SeatService
