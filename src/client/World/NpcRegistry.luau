--[[
	NpcRegistry

	Tracks the NPC models in the world (tagged IgniteNpc) for the client
	modules that work with them: NpcAnimator, NpcSpeech, AmbientChatter and
	SceneDirector. NPCs can be referred to by model or by NpcId (named NPCs
	from Data/Npcs, e.g. "teacher").
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Constants.World)
local Signal = require(Shared.Util.Signal)

local NpcRegistry = {}

NpcRegistry.Added = Signal.new()
NpcRegistry.Removed = Signal.new()

local models: { [Model]: boolean } = {}
local byId: { [string]: Model } = {}
local started = false

local function add(instance: Instance)
	if not instance:IsA("Model") or models[instance] then
		return
	end
	models[instance] = true
	local npcId = instance:GetAttribute(World.Attributes.NpcId)
	if type(npcId) == "string" then
		byId[npcId] = instance
	end
	NpcRegistry.Added:Fire(instance)
end

local function remove(instance: Instance)
	if not models[instance :: any] then
		return
	end
	models[instance :: any] = nil
	for npcId, model in byId do
		if model == instance then
			byId[npcId] = nil
		end
	end
	NpcRegistry.Removed:Fire(instance)
end

function NpcRegistry.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(World.Tags.Npc) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(World.Tags.Npc):Connect(add)
	CollectionService:GetInstanceRemovedSignal(World.Tags.Npc):Connect(remove)
end

-- Resolves an NPC id or model to its model (nil if not loaded).
function NpcRegistry.get(target: string | Model | nil): Model?
	if typeof(target) == "Instance" then
		return if models[target :: Model] then target :: Model else nil
	elseif type(target) == "string" then
		local model = byId[target]
		return if model and model.Parent then model else nil
	end
	return nil
end

function NpcRegistry.getNpcId(model: Model): string?
	local npcId = model:GetAttribute(World.Attributes.NpcId)
	return if type(npcId) == "string" then npcId else nil
end

function NpcRegistry.all(): { Model }
	local list = {}
	for model in models do
		if model.Parent then
			table.insert(list, model)
		end
	end
	return list
end

function NpcRegistry.getHead(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

function NpcRegistry.getRoot(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where the NPC's face is (for looking at it / placing a bubble).
function NpcRegistry.getHeadPosition(model: Model): Vector3?
	local head = NpcRegistry.getHead(model)
	if head then
		return head.Position
	end
	local root = NpcRegistry.getRoot(model)
	return root and root.Position + Vector3.new(0, 1.5, 0)
end

-- Nearest other NPC within `radius` studs of `model`.
function NpcRegistry.nearestTo(model: Model, radius: number, filter: ((Model) -> boolean)?): Model?
	local root = NpcRegistry.getRoot(model)
	if not root then
		return nil
	end
	local best, bestDistance = nil, radius
	for other in models do
		if other ~= model and other.Parent and (filter == nil or filter(other)) then
			local otherRoot = NpcRegistry.getRoot(other)
			if otherRoot then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

return NpcRegistry
