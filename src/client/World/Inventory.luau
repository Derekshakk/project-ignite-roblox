--[[
	Inventory (client)

	Connects items in the world, the server's Tools and the GameController:

	pickup     A Pickup prompt calls collect(itemId). The server is asked to
	           create the Tool first; only if it agrees is the item added to
	           GameState (so the two can't disagree, and an item can't be
	           collected twice).
	equip      Equipping a Tool moves it into the character. Watching the
	           character's children tells us what's equipped, and the
	           controller sets/clears the "equipped:<id>" flag that zone
	           data reacts to.
	world      Collected pickups are hidden locally (they reappear on a new
	           run).
	respawn    The server re-creates Tools (unequipped); the controller
	           clears equip state and keeps meters and owned items.
	new run    Returning to character select asks the server to remove
	           all item Tools.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local GameController = require(Shared.Game.GameController)
local ServerRequests = require(script.Parent.ServerRequests)

local Attributes = World.Attributes
local player = Players.LocalPlayer

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(controller)
	return setmetatable({
		_controller = controller,
		_characterConnections = {} :: { RBXScriptConnection },
		_hasSpawned = false,
		_originalTransparency = {} :: { [BasePart]: number },
	}, Inventory)
end

-- Collects an item from a pickup. Returns true on success.
function Inventory:collect(itemId: string): boolean
	if not self._controller:canCollect(itemId) then
		return false
	end
	if not ServerRequests.grantItem(itemId) then
		return false
	end
	return self._controller:collectItem(itemId)
end

function Inventory:start()
	local controller = self._controller
	controller.Changed:Connect(function(phase)
		if phase == GameController.Phase.CharacterSelect then
			ServerRequests.resetItems()
		end
		self:_refreshPickups()
	end)
	controller.InventoryChanged:Connect(function()
		self:_refreshPickups()
	end)
	CollectionService:GetInstanceAddedSignal(World.Tags.Interactable):Connect(function()
		self:_refreshPickups()
	end)

	player.CharacterAdded:Connect(function(character)
		if self._hasSpawned then
			controller:onRespawn()
		end
		self._hasSpawned = true
		self:_watchCharacter(character)
	end)
	if player.Character then
		self._hasSpawned = true
		self:_watchCharacter(player.Character)
	end
	self:_refreshPickups()
end

function Inventory:_watchCharacter(character: Model)
	for _, connection in self._characterConnections do
		connection:Disconnect()
	end
	table.clear(self._characterConnections)

	local function itemIdOf(child: Instance): string?
		if child:IsA("Tool") then
			local itemId = child:GetAttribute(Attributes.ItemId)
			return if type(itemId) == "string" then itemId else nil
		end
		return nil
	end
	table.insert(self._characterConnections, character.ChildAdded:Connect(function(child)
		local itemId = itemIdOf(child)
		if itemId then
			self._controller:setItemEquipped(itemId, true)
		end
	end))
	table.insert(self._characterConnections, character.ChildRemoved:Connect(function(child)
		local itemId = itemIdOf(child)
		if itemId then
			self._controller:setItemEquipped(itemId, false)
		end
	end))
end

-- Hides pickups the player already owns (locally only).
function Inventory:_refreshPickups()
	for _, prompt in CollectionService:GetTagged(World.Tags.Interactable) do
		if prompt:GetAttribute(Attributes.InteractionType) ~= World.InteractionTypes.Pickup then
			continue
		end
		local owned = self._controller:hasItem(prompt:GetAttribute(Attributes.InteractionId))
		local part = prompt.Parent
		local root = if part and part.Parent and part.Parent:GetAttribute("PickupItemId") then part.Parent else part
		if root then
			local parts = root:GetDescendants()
			table.insert(parts, root)
			for _, descendant in parts do
				if descendant:IsA("BasePart") then
					-- Client-side change: not replicated, so it only hides
					-- the pickup for this player.
					local original = self._originalTransparency[descendant]
					if original == nil then
						original = descendant.Transparency
						self._originalTransparency[descendant] = original
					end
					descendant.Transparency = if owned then 1 else original
				end
			end
		end
	end
end

return Inventory
