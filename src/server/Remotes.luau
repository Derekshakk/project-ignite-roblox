--[[
	Remotes

	Creates the RemoteFunctions the client uses, in one shared folder
	(ReplicatedStorage.IgniteRemotes; names in Constants/World).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared").Constants.World)

local Remotes = {}

local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(World.Remotes.Folder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = World.Remotes.Folder
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

-- Creates a RemoteFunction with the given handler and publishes it.
function Remotes.handle(name: string, handler: (Player, ...any) -> ...any): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.OnServerInvoke = handler
	remote.Parent = getFolder()
	return remote
end

return Remotes
