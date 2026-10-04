--[[
	Vehicles

	Low-poly cars in four body styles (sedan, hatchback, SUV, van) built
	from one parameterised shape: a lower body with rounded nose and tail
	(cylinders), a sloped hood, a glasshouse with wedge windshield and rear
	window, pillars, spoked wheels in dark wheel wells, bumpers, lights,
	grille, plates and mirrors. About 45 parts each.

	Vehicles.car(parent, floor, color, style?) builds one standing on
	`floor`, facing its LookVector. The model's PrimaryPart is an invisible
	"Root" at `floor`, and parts are marked for the client's traffic:
		Paint = true        body-coloured (recoloured per car)
		Brake = true        taillights (light up when braking)
		Wheel models        attributes WheelCenter (CFrame relative to
		                    the root) and WheelRadius; their parts spin
	Parked cars collide with a simple box (body + cabin); details don't.
]]

local Builder = require(script.Parent.Builder)
local Palette = require(script.Parent.Palette)

local Colors = Palette.Colors
local Materials = Palette.Materials
local rgb = Color3.fromRGB

local GLASS = rgb(52, 62, 74)
local TIRE = rgb(38, 38, 42)
local RIM = rgb(186, 188, 192)
local TRIM = rgb(48, 50, 54)

local Vehicles = {}

--[[
	Shape parameters (studs). z runs nose (−) to tail (+).
		length, width, wheel (diameter), wheelbase
		bottom, belt         lower body from ground clearance to beltline
		hood, trunk          flat lengths at the front and back
		roof                 roof height
		windshield, rear     horizontal run of the sloped glass
]]
Vehicles.Styles = table.freeze({
	sedan = { length = 9.2, width = 4.4, wheel = 1.7, wheelbase = 5.6, bottom = 0.75, belt = 2.05, hood = 2.6, trunk = 1.8, roof = 3.45, windshield = 1.35, rear = 1.1 },
	hatchback = { length = 7.8, width = 4.2, wheel = 1.6, wheelbase = 5.0, bottom = 0.75, belt = 2.0, hood = 2.1, trunk = 0.35, roof = 3.5, windshield = 1.3, rear = 0.55 },
	suv = { length = 9.6, width = 4.7, wheel = 2.0, wheelbase = 5.9, bottom = 1.0, belt = 2.6, hood = 2.5, trunk = 0.3, roof = 4.45, windshield = 1.2, rear = 0.45, rails = true },
	van = { length = 9.8, width = 4.6, wheel = 1.8, wheelbase = 6.2, bottom = 0.9, belt = 2.5, hood = 1.5, trunk = 0.2, roof = 4.85, windshield = 1.6, rear = 0.3, slider = true },
})
Vehicles.StyleNames = table.freeze({ "sedan", "hatchback", "suv", "van" })

local function paint(part: BasePart): BasePart
	part:SetAttribute("Paint", true)
	return part
end

function Vehicles.car(parent: Instance, floor: CFrame, color: Color3, styleName: string?)
	local s = Vehicles.Styles[styleName or "sedan"] or Vehicles.Styles.sedan
	local model = Builder.model(parent, "Car")
	model:SetAttribute("Style", styleName or "sedan")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = Builder.part(model, "Root", floor, Vector3.new(1, 1, 1), color, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	model.PrimaryPart = root
	local function at(x: number, y: number, z: number): CFrame
		return floor * CFrame.new(x, y, z)
	end

	local L, W = s.length, s.width
	local lowerHeight = s.belt - s.bottom
	local capRadius = lowerHeight / 2
	local midY = (s.bottom + s.belt) / 2
	local bodyMaterial = { Material = Materials.Metal, Reflectance = 0.05 }

	-- Lower body with rounded nose and tail.
	paint(Builder.part(model, "Body", at(0, midY, 0), Vector3.new(W, lowerHeight, L - capRadius * 2), color, bodyMaterial))
	for _, side in { -1, 1 } do
		paint(Builder.detail(model, "BodyCap", at(0, midY, side * (L / 2 - capRadius)), Vector3.new(W, lowerHeight, lowerHeight), color, {
			Shape = Enum.PartType.Cylinder,
			Material = Materials.Metal,
			Reflectance = 0.05,
		}))
	end
	-- Hood: a shallow slope up toward the windshield.
	paint(Builder.wedge(model, "Hood", at(0, s.belt + 0.14, -L / 2 + capRadius * 0.6 + s.hood / 2), Vector3.new(W - 0.08, 0.28, s.hood), color, {
		Material = Materials.Metal,
		CanCollide = false,
		CastShadow = false,
	}))

	-- Glasshouse.
	local cabinBase = s.belt + 0.25
	local cabinFront = -L / 2 + capRadius * 0.6 + s.hood
	local cabinBack = L / 2 - s.trunk - capRadius * 0.4
	local roofFront = cabinFront + s.windshield
	local roofBack = cabinBack - s.rear
	local glassHeight = s.roof - 0.2 - cabinBase
	local glassY = cabinBase + glassHeight / 2
	Builder.part(model, "Cabin", at(0, glassY, (roofFront + roofBack) / 2), Vector3.new(W - 0.5, glassHeight, roofBack - roofFront), GLASS, {
		Material = Materials.Glass,
		Reflectance = 0.15,
	})
	Builder.wedge(model, "Windshield", at(0, glassY, cabinFront + s.windshield / 2), Vector3.new(W - 0.56, glassHeight, s.windshield), GLASS, {
		Material = Materials.Glass,
		Reflectance = 0.2,
		CanCollide = false,
	})
	Builder.wedge(model, "RearWindow", at(0, glassY, cabinBack - s.rear / 2) * CFrame.Angles(0, math.pi, 0), Vector3.new(W - 0.56, glassHeight, s.rear), GLASS, {
		Material = Materials.Glass,
		Reflectance = 0.2,
		CanCollide = false,
	})
	-- A bit of body below the glass, so the glass sits in the body.
	paint(Builder.detail(model, "Shoulder", at(0, s.belt + 0.12, (cabinFront + cabinBack) / 2), Vector3.new(W - 0.2, 0.26, cabinBack - cabinFront), color, bodyMaterial))
	paint(Builder.detail(model, "Roof", at(0, s.roof - 0.1, (roofFront + roofBack) / 2), Vector3.new(W - 0.36, 0.22, roofBack - roofFront + 0.3), color, bodyMaterial))
	-- Pillars along the glass edges.
	for _, x in { -(W / 2 - 0.3), W / 2 - 0.3 } do
		local function pillar(from: Vector3, to: Vector3)
			local part = Builder.beam(model, "Pillar", floor * from, floor * to, 0.22, 0.22, color, {
				Material = Materials.Metal,
				CanCollide = false,
				CastShadow = false,
			}, floor.UpVector)
			paint(part)
		end
		pillar(Vector3.new(x, cabinBase, cabinFront), Vector3.new(x, s.roof - 0.15, roofFront))
		pillar(Vector3.new(x, cabinBase, cabinBack), Vector3.new(x, s.roof - 0.15, roofBack))
	end
	paint(Builder.detail(model, "BPillar", at(0, glassY, roofFront + (roofBack - roofFront) * (if s.slider then 0.3 else 0.5)), Vector3.new(W - 0.44, glassHeight, 0.32), color, bodyMaterial))
	if s.rails then
		for _, x in { -(W / 2 - 0.55), W / 2 - 0.55 } do
			Builder.detail(model, "RoofRail", at(x, s.roof + 0.12, (roofFront + roofBack) / 2), Vector3.new(0.14, 0.14, roofBack - roofFront - 0.4), TRIM)
		end
	end

	-- Wheels: tyre, rim and a spoke cross (so rotation is visible), each
	-- in a dark wheel well on the body side.
	local radius = s.wheel / 2
	for _, z in { -s.wheelbase / 2, s.wheelbase / 2 } do
		for _, side in { -1, 1 } do
			local x = side * (W / 2 - 0.25)
			local center = CFrame.new(x, radius, z)
			local wheel = Builder.model(model, "Wheel")
			wheel:SetAttribute("WheelCenter", center)
			wheel:SetAttribute("WheelRadius", radius)
			local world = floor * center
			Builder.detail(wheel, "Tire", world, Vector3.new(0.75, s.wheel, s.wheel), TIRE, { Shape = Enum.PartType.Cylinder })
			Builder.detail(wheel, "Rim", world * CFrame.new(side * 0.03, 0, 0), Vector3.new(0.77, s.wheel * 0.58, s.wheel * 0.58), RIM, {
				Shape = Enum.PartType.Cylinder,
				Material = Materials.Metal,
			})
			Builder.detail(wheel, "Spoke", world * CFrame.new(side * 0.05, 0, 0), Vector3.new(0.78, s.wheel * 0.5, 0.16), RIM:Lerp(TRIM, 0.35))
			Builder.detail(wheel, "Spoke", world * CFrame.new(side * 0.05, 0, 0), Vector3.new(0.78, 0.16, s.wheel * 0.5), RIM:Lerp(TRIM, 0.35))
			Builder.detail(model, "WheelWell", at(side * (W / 2 + 0.01), radius, z), Vector3.new(0.04, s.wheel + 0.4, s.wheel + 0.4), TRIM, {
				Shape = Enum.PartType.Cylinder,
			})
		end
	end

	-- Bumpers, lights, grille, plates, mirrors.
	for _, side in { -1, 1 } do
		local endZ = side * (L / 2)
		Builder.detail(model, "Bumper", at(0, s.bottom + 0.22, endZ + side * 0.02), Vector3.new(W + 0.1, 0.45, 0.5), TRIM)
		Builder.detail(model, "Plate", at(0, s.bottom + 0.22, endZ + side * 0.28), Vector3.new(1.1, 0.4, 0.04), rgb(222, 220, 208))
		-- Where the rounded cap's surface is at the lamp height.
		local lampY = s.belt - 0.38
		local dy = math.clamp(lampY - midY, -capRadius, capRadius)
		local surfaceZ = side * (L / 2 - capRadius + math.sqrt(capRadius * capRadius - dy * dy))
		for _, x in { -(W / 2 - 0.7), W / 2 - 0.7 } do
			if side < 0 then
				Builder.detail(model, "Headlight", at(x, lampY, surfaceZ - 0.02), Vector3.new(0.95, 0.36, 0.12), rgb(236, 232, 214), {
					Material = Materials.Glass,
				})
			else
				Builder.detail(model, "Taillight", at(x, lampY, surfaceZ + 0.02), Vector3.new(0.85, 0.32, 0.12), rgb(150, 36, 36), {
					Material = Materials.Glass,
				}):SetAttribute("Brake", true)
			end
		end
	end
	Builder.detail(model, "Grille", at(0, midY - 0.05, -L / 2 - 0.02), Vector3.new(W * 0.42, 0.32, 0.1), TRIM)
	for _, side in { -1, 1 } do
		paint(Builder.detail(model, "Mirror", at(side * (W / 2 + 0.16), cabinBase + 0.35, cabinFront + 0.35), Vector3.new(0.32, 0.3, 0.45), color, bodyMaterial))
		-- Door seams.
		local seams = if s.slider then { roofFront + (roofBack - roofFront) * 0.3, roofBack - 0.4 } else { roofFront + 0.1, roofFront + (roofBack - roofFront) * 0.5 }
		for _, z in seams do
			Builder.detail(model, "Seam", at(side * (W / 2 + 0.01), midY + 0.1, z), Vector3.new(0.03, lowerHeight - 0.3, 0.06), color:Lerp(TRIM, 0.6))
		end
	end
	return model
end

-- Picks a style from a seed, for variety in parked cars.
function Vehicles.styleFor(seed: number): string
	return Vehicles.StyleNames[(seed % #Vehicles.StyleNames) + 1]
end

Vehicles.Colors = table.freeze({
	rgb(160, 60, 56),
	rgb(70, 96, 140),
	rgb(196, 196, 190),
	rgb(60, 62, 70),
	rgb(120, 140, 110),
	rgb(206, 180, 120),
	rgb(118, 68, 84),
	Colors.Metal,
})

return Vehicles
