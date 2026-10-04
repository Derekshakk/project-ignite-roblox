--[[
	ItemService

	Server side of the inventory. The client asks for an item after the
	player uses a pickup; the server checks it hasn't already been granted,
	then creates a Tool in the player's Backpack (so it shows in the hotbar
	and equips normally). Wearable items get a visible model on the
	character's head while equipped.

	The server remembers what each player has been granted, so:
	- an item can't be granted twice (no duplicates),
	- Tools are re-created after a respawn (Backpacks are cleared on death),
	- "reset" (new run) removes everything.

	Item definitions come from Shared/Data/Items; gameplay effects of
	equipping are handled on the client via GameController flags.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Items = require(Shared.Data.Items)
local ItemModels = require(script.Parent.World.ItemModels)
local Remotes = require(script.Parent.Remotes)

local ITEM_ATTRIBUTE = World.Attributes.ItemId
local WORN_ATTRIBUTE = "WornItemId"

local ItemService = {}

local granted: { [Player]: { [string]: boolean } } = {}

local function findTool(player: Player, itemId: string): Tool?
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(ITEM_ATTRIBUTE) == itemId then
					return child
				end
			end
		end
	end
	return nil
end

local function removeWorn(character: Instance?, itemId: string)
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		if child:GetAttribute(WORN_ATTRIBUTE) == itemId then
			child:Destroy()
		end
	end
end

-- Shows/hides the worn model as the Tool moves between Backpack and
-- character (that's what equipping is).
local function trackWearable(tool: Tool, item)
	local wornCharacter: Instance? = nil
	local function update()
		local parent = tool.Parent
		local isEquipped = parent ~= nil and parent:FindFirstChildOfClass("Humanoid") ~= nil
		if isEquipped and wornCharacter ~= parent then
			removeWorn(wornCharacter, item.id)
			local head = parent:FindFirstChild("Head") :: BasePart?
			if head then
				local model = ItemModels.buildWorn(item.wearable.model, head)
				if model then
					model.Name = `Worn_{item.id}`
					model:SetAttribute(WORN_ATTRIBUTE, item.id)
					model.Parent = parent
				end
			end
			wornCharacter = parent
		elseif not isEquipped and wornCharacter then
			removeWorn(wornCharacter, item.id)
			wornCharacter = nil
		end
	end
	tool.AncestryChanged:Connect(update)
	tool.Destroying:Connect(function()
		removeWorn(wornCharacter, item.id)
	end)
end

local function createTool(player: Player, item)
	if findTool(player, item.id) then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.description
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.TextureId = item.icon or ""
	tool:SetAttribute(ITEM_ATTRIBUTE, item.id)
	if item.wearable then
		trackWearable(tool, item)
	end
	tool.Parent = backpack
end

-- Removes every item Tool and worn model (new run).
local function removeAll(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in container:GetChildren() do
			local isItemTool = child:IsA("Tool") and child:GetAttribute(ITEM_ATTRIBUTE) ~= nil
			if isItemTool or child:GetAttribute(WORN_ATTRIBUTE) ~= nil then
				child:Destroy()
			end
		end
	end
	granted[player] = {}
end

function ItemService.start()
	Remotes.handle(World.Remotes.Inventory, function(player: Player, action: any, itemId: any)
		if action == "grant" then
			if type(itemId) ~= "string" then
				return false
			end
			local item = Items.get(itemId)
			local playerItems = granted[player]
			if not item or not playerItems or playerItems[itemId] then
				return false
			end
			playerItems[itemId] = true
			createTool(player, item)
			return true
		elseif action == "reset" then
			removeAll(player)
			return true
		end
		return false
	end)

	local function onPlayer(player: Player)
		granted[player] = granted[player] or {}
		-- Backpacks are cleared on respawn; give granted items back.
		player.CharacterAdded:Connect(function()
			task.defer(function()
				for itemId in granted[player] or {} do
					local item = Items.get(itemId)
					if item then
						createTool(player, item)
					end
				end
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		granted[player] = nil
	end)
end

return ItemService
