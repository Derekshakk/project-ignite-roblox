--[[
	Theme

	Colors, fonts and base sizes for the UI. Sizes here are "design pixels"
	for a ~900px-tall desktop window; Theme.getScale turns them into real
	pixels for the current screen so text and spacing grow/shrink with the
	window. Future accessibility settings (larger text, high contrast) can hook
	in here.
]]

local Theme = {}

Theme.Colors = table.freeze({
	Background = Color3.fromRGB(24, 27, 38),
	Panel = Color3.fromRGB(36, 40, 56),
	PanelAlt = Color3.fromRGB(46, 51, 70),
	Stroke = Color3.fromRGB(70, 77, 102),

	Text = Color3.fromRGB(236, 238, 245),
	TextMuted = Color3.fromRGB(170, 176, 196),
	Accent = Color3.fromRGB(255, 170, 70),

	ButtonPrimary = Color3.fromRGB(255, 150, 60),
	ButtonPrimaryText = Color3.fromRGB(30, 22, 12),
	ButtonSecondary = Color3.fromRGB(58, 64, 88),
	ButtonSecondaryText = Color3.fromRGB(236, 238, 245),
	ButtonDisabled = Color3.fromRGB(50, 54, 68),

	MeterTrack = Color3.fromRGB(28, 31, 44),
	-- Neutral, non-judgmental colors: one for "capacity" meters, one for
	-- "strain" meters (burnout, stress). Neither means good or bad.
	MeterCapacity = Color3.fromRGB(88, 196, 190),
	MeterStrain = Color3.fromRGB(240, 160, 90),
	ChangeUp = Color3.fromRGB(150, 210, 255),
	ChangeDown = Color3.fromRGB(255, 200, 140),
})

Theme.Fonts = table.freeze({
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
})

-- Base text sizes in design pixels.
Theme.TextSizes = table.freeze({
	Title = 34,
	Heading = 24,
	Subheading = 19,
	Body = 18,
	Caption = 15,
})

Theme.Spacing = table.freeze({
	Small = 6,
	Medium = 12,
	Large = 20,
	Page = 28,
})

Theme.CornerRadius = 10
Theme.MaxContentWidth = 1100
Theme.CompactWidth = 900 -- below this many pixels, layouts stack vertically

local DESIGN_HEIGHT = 900

-- Scale factor for the current viewport, rounded so tiny resizes don't
-- trigger re-renders.
function Theme.getScale(viewportSize: Vector2): number
	local raw = math.clamp(viewportSize.Y / DESIGN_HEIGHT, 0.7, 1.5)
	return math.round(raw * 20) / 20
end

return Theme
