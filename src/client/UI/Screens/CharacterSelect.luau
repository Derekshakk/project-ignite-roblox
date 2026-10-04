--[[
	CharacterSelect screen

	Shows one card per character returned by the Characters registry. Cards
	are generated from data, so new characters appear here automatically.
]]

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Colors = Theme.Colors
local Spacing = Theme.Spacing
local px = Components.px

local MAX_COLUMNS = 3

local CharacterSelect = {}
CharacterSelect.fullscreen = true

local function buildCard(parent: Instance, ctx, character, width: UDim, actions)
	local card = Components.panel(parent, ctx, { name = `Card_{character.id}`, width = width })

	if character.accentColor then
		Components.create("Frame", {
			Name = "AccentBar",
			BackgroundColor3 = character.accentColor,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, px(ctx, 6)),
		}, card)
	end

	Components.text(card, ctx, character.name, { size = "Heading", font = "Bold" })
	Components.text(card, ctx, `Age {character.age or "?"}  ·  {character.pronouns}`, {
		size = "Caption",
		color = Colors.TextMuted,
	})
	Components.text(card, ctx, character.shortDescription)

	Components.labeledList(card, ctx, "Neurodivergent experiences", character.neurodivergentExperiences)
	Components.labeledList(card, ctx, "Strengths", character.strengths)
	Components.labeledList(card, ctx, "Burnout triggers", character.burnoutTriggers)
	Components.labeledList(card, ctx, "Recovery strategies", character.recoveryStrategies)

	Components.button(card, ctx, {
		name = "PlayButton",
		text = `Play as {character.name}`,
		variant = "primary",
		modal = true, -- frees the mouse if the player was in first person
		onActivated = function()
			actions.selectCharacter(character.id)
		end,
	})
	return card
end

function CharacterSelect.render(parent: Instance, ctx, view, actions): Instance
	local content = Components.page(parent, ctx, "CharacterSelect")
	local page = content.Parent :: Instance

	local header = Components.stack(content, ctx, { name = "Header", gap = Spacing.Small })
	Components.text(header, ctx, "Project Ignite", { size = "Title", font = "Bold", color = Colors.Accent })
	Components.text(
		header,
		ctx,
		"Choose a character, then explore their school day: walk around, interact with the world, "
			.. "and notice how each moment affects them.",
		{ size = "Subheading" }
	)
	Components.text(
		header,
		ctx,
		"This is an educational reflection experience. It does not diagnose burnout or anything else.",
		{ size = "Caption", color = Colors.TextMuted }
	)

	local characters = view.characters
	if #characters == 0 then
		Components.text(content, ctx, "No characters are available yet.", { color = Colors.TextMuted })
		return page
	end

	-- Wrapping row of cards: columns adapt to the number of characters and
	-- screen width (a single card sits centered at half width on desktop).
	local columns = if ctx.compact then 1 else math.clamp(#characters, 2, MAX_COLUMNS)
	local gap = px(ctx, Spacing.Large)
	local cardWidth = UDim.new(1 / columns, -gap * (columns - 1) / columns)

	local grid = Components.create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, content)
	Components.listLayout(grid, ctx, {
		direction = Enum.FillDirection.Horizontal,
		horizontalAlignment = Enum.HorizontalAlignment.Center,
		gap = Spacing.Large,
		wraps = true,
	})

	for _, character in characters do
		buildCard(grid, ctx, character, cardWidth, actions)
	end

	return page
end

return CharacterSelect
