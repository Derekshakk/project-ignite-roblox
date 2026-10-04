--[[
	ServerRequests

	The client's requests to the server (names in Constants/World.Remotes).
	Each call is wrapped so a failure (or a missing remote) returns false
	instead of erroring.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("World"))

local folder = ReplicatedStorage:WaitForChild(World.Remotes.Folder)

local ServerRequests = {}

local function invoke(name: string, ...: any): ...any
	local remote = folder:WaitForChild(name, 10) :: RemoteFunction?
	if not remote then
		warn(`[ServerRequests] Remote "{name}" not found.`)
		return false
	end
	local result = table.pack(pcall(remote.InvokeServer, remote, ...))
	if not result[1] then
		warn(`[ServerRequests] {name} failed: {result[2]}`)
		return false
	end
	return table.unpack(result, 2, result.n)
end

-- Moves the character to a destination. Returns (success, areaId).
function ServerRequests.travel(destinationId: string): (boolean, string?)
	local ok, areaId = invoke(World.Remotes.Travel, destinationId)
	return ok == true, areaId
end

function ServerRequests.sit(seatId: string): boolean
	return invoke(World.Remotes.Sit, seatId) == true
end

-- Asks the server for an item's Tool. False if already granted.
function ServerRequests.grantItem(itemId: string): boolean
	return invoke(World.Remotes.Inventory, "grant", itemId) == true
end

-- Removes all item Tools (start of a new run).
function ServerRequests.resetItems(): boolean
	return invoke(World.Remotes.Inventory, "reset") == true
end

return ServerRequests
