--[[
	ItemModels

	Small part-built models for items, used both as world pickups (anchored)
	and as worn visuals (welded to the character). Each builder takes a
	CFrame for the model's centre and a `width` it scales to (for worn
	headphones, the width of the character's head).

	Add a builder here and reference it from an item's `wearable.model`.
]]

local Palette = require(script.Parent.Palette)

local Colors = Palette.Colors

local ItemModels = {}

local function part(model: Model, name: string, cframe: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local BUILDERS = {}

-- Over-ear headphones around a head of the given width, centred on `cframe`.
function BUILDERS.Headphones(cframe: CFrame, width: number): Model
	local model = Instance.new("Model")
	model.Name = "Headphones"
	local half = width / 2
	local shell = Color3.fromRGB(46, 50, 60)
	local accent = Colors.Teal

	local band = part(model, "Band", cframe * CFrame.new(0, half + 0.12, 0), Vector3.new(width * 0.7, 0.14, 0.32), shell)
	for _, side in { -1, 1 } do
		-- Angled band ends meeting the ear cups.
		part(model, "BandSide", cframe * CFrame.new(side * (half + 0.02), half - 0.12, 0) * CFrame.Angles(0, 0, math.rad(side * -18)), Vector3.new(0.14, 0.62, 0.3), shell)
		-- Cylinders point along X, so the cups face the sides of the head.
		part(model, "Cup", cframe * CFrame.new(side * (half + 0.12), -0.12, 0), Vector3.new(0.28, 0.72, 0.72), shell, Enum.PartType.Cylinder)
		part(model, "Cushion", cframe * CFrame.new(side * (half - 0.0), -0.12, 0), Vector3.new(0.08, 0.6, 0.6), accent, Enum.PartType.Cylinder)
	end
	model.PrimaryPart = band
	return model
end

-- Builds `name` (e.g. "Headphones"). Returns nil for unknown models.
function ItemModels.build(name: string, cframe: CFrame, width: number): Model?
	local builder = BUILDERS[name]
	if not builder then
		warn(`[ItemModels] No model named "{name}".`)
		return nil
	end
	return builder(cframe, width)
end

-- Anchored pickup version placed in the world.
function ItemModels.buildPickup(parent: Instance, name: string, cframe: CFrame, width: number): Model?
	local model = ItemModels.build(name, cframe, width)
	if not model then
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

-- Worn version welded to `attachTo` (e.g. the character's Head).
function ItemModels.buildWorn(name: string, attachTo: BasePart): Model?
	local model = ItemModels.build(name, attachTo.CFrame, attachTo.Size.X)
	if not model then
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = attachTo
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	return model
end

return ItemModels
