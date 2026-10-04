--[[
	FeedbackDialog ("What Happened")

	Shown after a scenario choice or an activity. Explains the tradeoffs
	and which meters moved, then returns the player to exploring. Wording
	stays supportive: outcomes are tradeoffs, never right or wrong.
]]

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors

local FeedbackDialog = {}

function FeedbackDialog.render(parent: Instance, ctx, view, actions): Instance
	local result = view.result
	local dialog = Components.dialog(parent, ctx, "FeedbackDialog")

	Components.text(dialog, ctx, `WHAT HAPPENED  ·  {string.upper(result.title)}`, {
		size = "Caption",
		font = "Bold",
		color = Colors.Accent,
	})
	Components.text(dialog, ctx, result.heading, { size = "Subheading", font = "Bold" })
	Components.text(dialog, ctx, result.feedback)

	if not Components.changeChips(dialog, ctx, result.changes) then
		Components.text(dialog, ctx, "None of the meters changed this time.", { size = "Caption", color = Colors.TextMuted })
	end
	Components.text(dialog, ctx, "Meters show tradeoffs, not a score.", { size = "Caption", color = Colors.TextMuted })

	local continueButton
	continueButton = Components.button(dialog, ctx, {
		name = "ContinueButton",
		text = "Continue",
		variant = "primary",
		textSize = "Body",
		modal = true,
		width = if ctx.compact then nil else UDim.new(0, Components.px(ctx, 220)),
		onActivated = function()
			Components.setButtonEnabled(continueButton, false)
			actions.continue()
		end,
	})

	return dialog
end

return FeedbackDialog
