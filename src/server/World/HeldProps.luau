--[[
	HeldProps

	Small things NPCs hold in a hand: a watering can, a broom, a trowel, a
	mug, a phone, a grocery bag. Each is built in "grip space" — the origin
	is where the hand closes, -Y is down along a relaxed arm and -Z points
	forward — so it can be welded to any R15 hand:

		HeldProps.attach(hand, name)        weld a new prop to a hand
		HeldProps.build(parent, name)       unattached, pivot at the grip
		                                     (for client templates)

	Parts are unanchored, massless and non-colliding once attached, so they
	follow the hand through every animation. The watering can's spout has
	an Attachment "Pour" with a disabled ParticleEmitter "Water"; the
	NpcAnimator turns it on while pouring.
]]

local Builder = require(script.Parent.Builder)
local Palette = require(script.Parent.Palette)

local Colors = Palette.Colors
local Materials = Palette.Materials
local rgb = Color3.fromRGB

-- Hand centre → where the fingers close around a handle.
local GRIP = CFrame.new(0, -0.15, 0)

local HeldProps = {}
HeldProps.GRIP = GRIP

local BUILDERS: { [string]: (Model) -> () } = {}

local function piece(model: Model, name: string, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	return Builder.detail(model, name, cframe, size, color, props)
end

local function stick(model: Model, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, props: { [string]: any }?)
	local part = Builder.beam(model, name, a, b, thickness, thickness, color, props)
	part.CanCollide = false
	part.CastShadow = false
	return part
end

BUILDERS.watering_can = function(model)
	local green = rgb(78, 136, 104)
	piece(model, "Can", CFrame.new(0, -0.72, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.9, 0.85, 0.85), green, {
		Shape = Enum.PartType.Cylinder,
		Material = Materials.Metal,
	})
	piece(model, "CanTop", CFrame.new(0, -0.27, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 0.6, 0.6), green:Lerp(Colors.Charcoal, 0.3), {
		Shape = Enum.PartType.Cylinder,
	})
	piece(model, "Handle", CFrame.new(0, 0, 0.1), Vector3.new(0.12, 0.12, 0.75), green:Lerp(Colors.Charcoal, 0.2))
	stick(model, "Handle", Vector3.new(0, 0, 0.45), Vector3.new(0, -0.3, 0.45), 0.1, green)
	stick(model, "Handle", Vector3.new(0, 0, -0.25), Vector3.new(0, -0.3, -0.25), 0.1, green)
	local spoutFrom, spoutTo = Vector3.new(0, -0.95, -0.3), Vector3.new(0, -0.4, -1.2)
	stick(model, "Spout", spoutFrom, spoutTo, 0.14, green)
	local direction = (spoutTo - spoutFrom).Unit
	local rose = piece(model, "Rose", CFrame.lookAt(spoutTo, spoutTo + direction), Vector3.new(0.3, 0.3, 0.12), green:Lerp(Colors.Metal, 0.4), {
		Shape = Enum.PartType.Ball,
	})
	local pour = Instance.new("Attachment")
	pour.Name = "Pour"
	pour.Parent = rose
	local water = Instance.new("ParticleEmitter")
	water.Name = "Water"
	water.Enabled = false
	water.Color = ColorSequence.new(rgb(190, 220, 236))
	water.LightEmission = 0.1
	water.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	water.Size = NumberSequence.new(0.1, 0.05)
	water.Lifetime = NumberRange.new(0.35, 0.55)
	water.Rate = 26
	water.Speed = NumberRange.new(2.5, 3.5)
	water.SpreadAngle = Vector2.new(8, 8)
	water.Acceleration = Vector3.new(0, -24, 0)
	water.EmissionDirection = Enum.NormalId.Front
	water.Parent = pour
end

BUILDERS.broom = function(model)
	-- Hangs almost straight down at rest; leans forward in the sweeping pose.
	local direction = Vector3.new(0, -0.99, 0.15).Unit
	local top, bottom = -direction * 0.9, direction * 2.6
	stick(model, "Handle", top, bottom, 0.16, Colors.LightWood, { Material = Materials.Wood })
	local headFrame = CFrame.lookAt(direction * 2.85, direction * 2.85 + Vector3.new(0, 0, -1), -direction)
	piece(model, "Head", headFrame, Vector3.new(1.7, 0.32, 0.4), Colors.Red:Lerp(Colors.Charcoal, 0.2))
	piece(model, "Bristles", headFrame * CFrame.new(0, 0, 0) + direction * 0.32, Vector3.new(1.75, 0.36, 0.42), rgb(196, 168, 110), {
		Material = Materials.Fabric,
	})
end

BUILDERS.trowel = function(model)
	piece(model, "Handle", CFrame.new(0, -0.05, 0.05), Vector3.new(0.16, 0.16, 0.5), Colors.Red:Lerp(Colors.Wood, 0.4))
	piece(model, "Blade", CFrame.new(0, -0.1, -0.5) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(0.36, 0.05, 0.55), Colors.Metal, {
		Material = Materials.Metal,
	})
end

BUILDERS.mug = function(model)
	piece(model, "Mug", CFrame.new(0, -0.05, -0.25) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.5, 0.42, 0.42), rgb(214, 120, 84), {
		Shape = Enum.PartType.Cylinder,
	})
	piece(model, "MugHandle", CFrame.new(0, -0.05, 0.02), Vector3.new(0.08, 0.3, 0.14), rgb(214, 120, 84))
end

BUILDERS.phone = function(model)
	piece(model, "Phone", CFrame.new(0, -0.1, -0.2), Vector3.new(0.34, 0.05, 0.62), rgb(36, 38, 44))
	piece(model, "Screen", CFrame.new(0, -0.07, -0.2), Vector3.new(0.28, 0.01, 0.52), rgb(120, 156, 196), { Material = Materials.Glass })
end

BUILDERS.groceries = function(model)
	local paper = rgb(186, 150, 104)
	piece(model, "Bag", CFrame.new(0, -0.85, 0.05), Vector3.new(1.0, 1.2, 0.66), paper, { Material = Materials.Fabric })
	piece(model, "BagFold", CFrame.new(0, -0.22, 0.05), Vector3.new(1.03, 0.12, 0.69), paper:Lerp(Colors.Charcoal, 0.15))
	piece(model, "Greens", CFrame.new(0.2, -0.1, 0.1), Vector3.new(0.55, 0.5, 0.45), Colors.Green, {
		Shape = Enum.PartType.Ball,
		Material = Materials.Grass,
	})
	stick(model, "Bread", Vector3.new(-0.25, -0.4, -0.05), Vector3.new(-0.32, 0.25, 0.1), 0.26, rgb(204, 160, 96))
end

-- Builds a prop with its pivot at the grip (unattached, anchored).
function HeldProps.build(parent: Instance, name: string): Model?
	local build = BUILDERS[name]
	if not build then
		warn(`[HeldProps] Unknown prop "{name}".`)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	build(model)
	model.WorldPivot = CFrame.new()
	model:SetAttribute("Grip", GRIP)
	model.Parent = parent
	return model
end

-- Builds a prop and welds it into `hand` (an R15 hand part).
function HeldProps.attach(hand: BasePart, name: string): Model?
	local model = HeldProps.build(hand.Parent :: Instance, name)
	if not model then
		return nil
	end
	model:PivotTo(hand.CFrame * GRIP)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return model
end

return HeldProps
