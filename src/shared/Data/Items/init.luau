--[[
	Items registry

	Item definitions only — no behaviour. The pieces that use them:
		pickup interaction   InteractionType "Pickup" (world prompt → client)
		ownership            GameState inventory, via GameController
		Tool creation        server ItemService (Backpack/hotbar, worn model)
		equipped effects     zone `modifiers` keyed on "equipped:<itemId>"
		                     + client AudioController (environment audio)

	Item shape:
		id, name: string
		description: string              Tool tooltip
		pickupActionText: string         prompt label ("Pick up")
		collectedMessage: string         toast after collecting
		hudLabel: string?                shown in the HUD while equipped
		icon: string?                    Tool TextureId (optional)
		wearable: { model: string }?     model name in server ItemModels,
		                                 worn on the head while equipped
		effects: {
			environmentVolume: number?   0–1 multiplier on environment audio
			muffle: boolean?             low-pass "muffled" environment audio
		}?
		equipMessage: string?            toast the first time it's equipped

	Equipping an item sets the flag "equipped:<id>"; data (zones,
	activities, scenarios) can react to it with Conditions.
]]

local DataLoader = require(script.Parent.Parent.Util.DataLoader)

local function validate(item: any, source: string): boolean
	for _, field in { "name", "description", "pickupActionText", "collectedMessage" } do
		if type(item[field]) ~= "string" then
			warn(`[Items] Item "{item.id}" ({source}) is missing "{field}"; skipped.`)
			return false
		end
	end
	return true
end

local byId = DataLoader.loadById(script, "Items", validate)

local Items = {}

function Items.get(id: string)
	return byId[id]
end

function Items.equippedFlag(id: string): string
	return `equipped:{id}`
end

return Items
