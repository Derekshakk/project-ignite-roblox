--[[
	Common items.

	Items are accommodations and everyday tools, not power-ups: they change
	how demanding a situation is, never remove it.
]]

return {
	{
		id = "headphones",
		name = "Headphones",
		description = "Noise-reducing headphones. They turn down some of the noise, not all of it.",
		pickupActionText = "Pick up",
		collectedMessage = "Headphones added to the backpack. Equip them from the hotbar when a space gets loud.",
		equipMessage = "Headphones on. Busy spaces will feel a little less loud.",
		hudLabel = "Headphones on",
		wearable = { model = "Headphones" },
		effects = {
			environmentVolume = 0.45,
			muffle = true,
		},
	},
}
