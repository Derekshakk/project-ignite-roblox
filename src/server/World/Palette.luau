--[[
	Palette

	Colours and materials for the world in one place, so the overall look can
	be tuned without touching area layouts.

	Guidelines used here:
	- No pure white: the lightest surfaces are warm off-whites around 220,
	  so lit surfaces don't blow out under indoor lights.
	- Surfaces step in brightness: ceiling < walls < trim contrast, floors
	  darker than walls, so rooms read clearly and feel grounded.
	- Matte materials (plaster, fabric, wood) for large surfaces; metal and
	  glass only for small accents.
]]

local Palette = {}

-- Newer materials are looked up safely so an older engine falls back
-- instead of erroring during world build.
local function material(name: string, fallback: Enum.Material): Enum.Material
	local ok, result = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and result then result else fallback
end

Palette.Materials = table.freeze({
	Plaster = material("Plaster", Enum.Material.SmoothPlastic),
	Tiles = material("CeramicTiles", Enum.Material.Slate),
	Carpet = material("Carpet", Enum.Material.Fabric),
	Fabric = Enum.Material.Fabric,
	Wood = Enum.Material.Wood,
	WoodPlanks = Enum.Material.WoodPlanks,
	Metal = Enum.Material.Metal,
	Matte = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
	Concrete = Enum.Material.Concrete,
	Brick = Enum.Material.Brick,
	Slate = Enum.Material.Slate,
	Grass = Enum.Material.Grass,
	Ground = Enum.Material.Ground,
})

local rgb = Color3.fromRGB

Palette.Colors = table.freeze({
	-- Neutrals
	OffWhite = rgb(222, 216, 204),
	Paper = rgb(226, 222, 210),
	Ceiling = rgb(196, 192, 184),
	CeilingTrim = rgb(160, 156, 148),
	Charcoal = rgb(58, 58, 64),

	-- Woods
	Wood = rgb(140, 100, 68),
	LightWood = rgb(178, 144, 104),
	DarkWood = rgb(86, 60, 42),
	Trim = rgb(92, 72, 58),

	-- Metals / glass
	Metal = rgb(112, 118, 126),
	DarkMetal = rgb(72, 76, 84),
	Glass = rgb(150, 188, 210),

	-- Room surfaces
	BedroomWall = rgb(168, 180, 192),
	BedroomFloor = rgb(128, 94, 66),
	HallwayWall = rgb(204, 194, 174),
	HallwayWainscot = rgb(104, 126, 146),
	HallwayFloor = rgb(170, 166, 156),
	HallwayStripe = rgb(110, 136, 160),
	ClassroomWall = rgb(208, 198, 172),
	ClassroomWainscot = rgb(132, 150, 128),
	ClassroomFloor = rgb(150, 120, 88),
	AlcoveWall = rgb(170, 196, 178),
	AlcoveFloor = rgb(96, 120, 138),

	-- Accents
	Locker = rgb(88, 112, 138),
	LockerAlt = rgb(78, 100, 126),
	OwnLocker = rgb(62, 150, 142),
	Door = rgb(150, 104, 70),
	Cork = rgb(170, 132, 90),
	Whiteboard = rgb(214, 218, 214),
	Sign = rgb(222, 216, 200),
	Plant = rgb(78, 132, 82),
	Pot = rgb(160, 92, 64),
	Light = rgb(255, 226, 186), -- warm, never pure white
	LightFixture = rgb(214, 204, 182),

	-- Soft furnishings and props
	Bedding = rgb(84, 132, 196),
	Sheets = rgb(214, 208, 196),
	Rug = rgb(98, 150, 146),
	Accent = rgb(232, 140, 64),
	Purple = rgb(132, 100, 172),
	Teal = rgb(70, 156, 150),
	Lavender = rgb(170, 152, 204),
	Red = rgb(176, 72, 66),
	Yellow = rgb(214, 176, 72),
	Green = rgb(96, 150, 104),
	Blue = rgb(74, 112, 170),
})

-- Cover colours for books, binders, bins and posters.
Palette.Assorted = table.freeze({
	rgb(176, 72, 66),
	rgb(74, 112, 170),
	rgb(214, 176, 72),
	rgb(96, 150, 104),
	rgb(132, 100, 172),
	rgb(206, 120, 70),
	rgb(70, 140, 150),
})

function Palette.pick(list: { Color3 }, index: number): Color3
	return list[(index - 1) % #list + 1]
end

return Palette
