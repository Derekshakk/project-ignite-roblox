--[[
	SpeechHint

	Shown while an NPC is speaking to the player (UIState Speaking): a small
	"Next" button at the bottom of the screen. The words themselves are in
	the speech bubble over the NPC; this only lets the player move on at
	their own pace (E / Enter work too). Lines also advance on their own.
]]

local Components = require(script.Parent.Parent.Components)

local px = Components.px

local SpeechHint = {}

function SpeechHint.render(parent: Instance, ctx, _view, actions): Instance
	local button = Components.button(parent, ctx, {
		name = "SpeechNext",
		text = "Next  ›",
		subtext = "E / Enter",
		variant = "secondary",
		textSize = "Body",
		modal = true,
		width = UDim.new(0, px(ctx, 150)),
		onActivated = function()
			actions.advanceDialogue()
		end,
	})
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -px(ctx, 28))
	button.BackgroundTransparency = 0.15
	return button
end

return SpeechHint
