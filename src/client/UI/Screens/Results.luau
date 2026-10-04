--[[
	Results screen (temporary)

	Shown when the character ends the day in bed: final meters, choices
	made, moments from the environment, a reflection message, and a way back
	to character select. The full Project Ignite results page will replace
	this.
]]

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local Spacing = Theme.Spacing

local Results = {}
Results.fullscreen = true

function Results.render(parent: Instance, ctx, view, actions): Instance
	local character = view.character
	local content = Components.page(parent, ctx, "Results")
	local page = content.Parent :: Instance

	local header = Components.stack(content, ctx, { name = "Header", gap = Spacing.Small })
	local ended = if view.timeText then `  ·  {view.timeText}` else ""
	Components.text(header, ctx, `END OF DAY {view.day}{ended}`, { size = "Caption", font = "Bold", color = Colors.Accent })
	Components.text(header, ctx, `{character.name}'s Day`, { size = "Title", font = "Bold" })
	Components.text(header, ctx, "Temporary results screen", { size = "Caption", color = Colors.TextMuted })

	local _, left, right = Components.columns(content, ctx, 0.55)

	local choicesPanel = Components.panel(left, ctx, { name = "ChoicesMade" })
	Components.text(choicesPanel, ctx, "Choices made", { size = "Caption", font = "Bold", color = Colors.Accent })
	if #view.history == 0 then
		Components.text(choicesPanel, ctx, "No choices were recorded.", { color = Colors.TextMuted })
	end
	for _, entry in view.history do
		local item = Components.stack(choicesPanel, ctx, { gap = 2 })
		Components.text(item, ctx, entry.scenarioTitle, { size = "Caption", color = Colors.TextMuted })
		Components.text(item, ctx, entry.choiceText, { font = "Medium" })
	end

	if #view.events > 0 then
		local momentsPanel = Components.panel(left, ctx, { name = "Moments" })
		Components.text(momentsPanel, ctx, "Moments along the way", { size = "Caption", font = "Bold", color = Colors.Accent })
		for _, event in view.events do
			Components.text(momentsPanel, ctx, "•  " .. (event.summary or event.title), { color = Colors.TextMuted })
		end
	end

	if view.noticed and view.noticed.total > 0 then
		local noticedPanel = Components.panel(left, ctx, { name = "Noticed" })
		Components.text(noticedPanel, ctx, "Exploring", { size = "Caption", font = "Bold", color = Colors.Accent })
		Components.text(noticedPanel, ctx, `Details noticed along the way: {view.noticed.count} of {view.noticed.total}`, {
			color = Colors.TextMuted,
		})
	end

	local reflectionPanel = Components.panel(left, ctx, { name = "Reflection", color = Colors.PanelAlt })
	Components.text(reflectionPanel, ctx, "Reflection", { size = "Caption", font = "Bold", color = Colors.Accent })
	Components.text(reflectionPanel, ctx, view.reflection)

	-- Deltas compare final values to where the character started the day.
	local deltas = {}
	for id, value in view.meters do
		deltas[id] = value - (view.startingMeters[id] or value)
	end
	Components.meterPanel(right, ctx, view.meters, { title = "Remaining capacity", deltas = deltas })
	Components.text(right, ctx, "Numbers in brackets show the change since the start of the day.", {
		size = "Caption",
		color = Colors.TextMuted,
	})

	local restartButton
	restartButton = Components.button(content, ctx, {
		name = "RestartButton",
		text = "Back to Character Select",
		variant = "primary",
		modal = true, -- frees the mouse if the player was in first person
		width = if ctx.compact then nil else UDim.new(0, Components.px(ctx, 320)),
		onActivated = function()
			Components.setButtonEnabled(restartButton, false)
			actions.restart()
		end,
	})

	return page
end

return Results
