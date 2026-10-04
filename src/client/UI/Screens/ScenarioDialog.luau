--[[
	ScenarioDialog

	Compact dialog at the bottom of the screen; the 3D world stays visible
	above it. Shows the situation, inner thoughts and choices. Choice
	buttons only call actions.submitChoice (the controller decides what
	happens) and lock locally after the first click for instant feedback.
]]

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local Spacing = Theme.Spacing

local ScenarioDialog = {}

function ScenarioDialog.render(parent: Instance, ctx, view, actions): Instance
	local character = view.character
	local scenario = view.scenario
	local dialog = Components.dialog(parent, ctx, "ScenarioDialog")

	local header = Components.stack(dialog, ctx, { name = "Header", gap = 2 })
	Components.text(header, ctx, `{view.timeText or scenario.timeOfDay}  ·  {string.upper(character.name)}`, {
		size = "Caption",
		font = "Bold",
		color = Colors.Accent,
	})
	Components.text(header, ctx, scenario.title, { size = "Heading", font = "Bold" })

	local _, left, right = Components.columns(dialog, ctx, 0.46)

	Components.text(left, ctx, scenario.situation)
	local thoughts = Components.panel(left, ctx, { name = "InnerThoughts", color = Colors.PanelAlt, padding = Spacing.Medium })
	Components.text(thoughts, ctx, `{character.name}'s inner thoughts`, { size = "Caption", font = "Bold", color = Colors.Accent })
	Components.text(thoughts, ctx, `“{scenario.innerThoughts}”`, { font = "Medium", color = Colors.TextMuted })

	local choiceList = Components.stack(right, ctx, { name = "Choices", gap = Spacing.Small })
	Components.text(choiceList, ctx, `What should {character.name} do?`, { size = "Subheading", font = "Bold" })

	local buttons = {}
	local submitted = false
	local function lockAll()
		submitted = true
		for _, button in buttons do
			Components.setButtonEnabled(button, false)
		end
	end

	for _, choice in scenario.choices do
		table.insert(
			buttons,
			Components.button(choiceList, ctx, {
				name = `Choice_{choice.id}`,
				text = choice.text,
				subtext = choice.description,
				variant = "secondary",
				align = Enum.TextXAlignment.Left,
				textSize = "Body",
				modal = true,
				onActivated = function()
					if submitted then
						return
					end
					lockAll()
					actions.submitChoice(choice.id)
				end,
			})
		)
	end

	table.insert(
		buttons,
		Components.button(dialog, ctx, {
			name = "StepAway",
			text = "Step away for now",
			variant = "secondary",
			textSize = "Caption",
			width = if ctx.compact then nil else UDim.new(0, Components.px(ctx, 220)),
			onActivated = function()
				if submitted then
					return
				end
				lockAll()
				actions.cancelScenario()
			end,
		})
	)

	return dialog
end

return ScenarioDialog
