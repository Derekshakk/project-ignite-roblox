--[[
	LightingSetup

	Global lighting for the prototype, applied by the server at start (and
	replicated to everyone). Tuned for indoor scenes: rooms are lit mainly
	by warm ceiling lights and a moderate ambient, with exposure pulled down
	so off-white surfaces don't blow out. Post-processing is deliberately
	subtle and never reduces readability (no depth of field, no blur).

	Lighting.Technology can't be set from scripts; it is set to Future in
	default.project.json.

	Effects that already exist in the place (for example the default
	template's Bloom or SunRays) are disabled so they can't stack with ours.
]]

local Lighting = game:GetService("Lighting")

local rgb = Color3.fromRGB

local PROPERTIES = {
	Brightness = 1.6,
	ExposureCompensation = -0.35,
	ClockTime = 9.5,
	GeographicLatitude = 35,
	-- Indoor (non sky-lit) fill. Low enough for lights to create depth,
	-- high enough that corners stay readable.
	Ambient = rgb(74, 70, 66),
	OutdoorAmbient = rgb(118, 118, 126),
	-- Reduce sky reflections that make smooth surfaces look shiny.
	EnvironmentDiffuseScale = 0.35,
	EnvironmentSpecularScale = 0.15,
	GlobalShadows = true,
	ShadowSoftness = 0.3,
	ColorShift_Top = rgb(0, 0, 0),
	ColorShift_Bottom = rgb(0, 0, 0),
}

-- Name → { className, properties }
local EFFECTS = {
	IgniteColorGrade = {
		className = "ColorCorrectionEffect",
		properties = {
			Brightness = -0.02,
			Contrast = 0.06,
			Saturation = 0.04,
			TintColor = rgb(255, 250, 244),
		},
	},
	-- Only the brightest pixels (light fixtures) get a faint glow.
	IgniteBloom = {
		className = "BloomEffect",
		properties = {
			Intensity = 0.25,
			Size = 18,
			Threshold = 1.8,
		},
	},
	-- Very light haze for depth down the long hallway; no glare.
	IgniteAtmosphere = {
		className = "Atmosphere",
		properties = {
			Density = 0.2,
			Offset = 0,
			Color = rgb(196, 188, 176),
			Decay = rgb(110, 116, 128),
			Glare = 0,
			Haze = 0,
		},
	},
}

local MANAGED_CLASSES = { "PostEffect", "Atmosphere" }

local LightingSetup = {}

local function isManagedClass(instance: Instance): boolean
	for _, className in MANAGED_CLASSES do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

function LightingSetup.apply()
	for property, value in PROPERTIES do
		local ok, err = pcall(function()
			(Lighting :: any)[property] = value
		end)
		if not ok then
			warn(`[LightingSetup] Could not set Lighting.{property}: {err}`)
		end
	end

	-- Disable or remove pre-existing effects so only ours apply.
	for _, child in Lighting:GetChildren() do
		if isManagedClass(child) and not EFFECTS[child.Name] then
			if child:IsA("Atmosphere") then
				child:Destroy() -- only one Atmosphere is used by the engine
			else
				(child :: any).Enabled = false
			end
		end
	end

	for name, spec in EFFECTS do
		local effect = Lighting:FindFirstChild(name) or Instance.new(spec.className)
		effect.Name = name
		for property, value in spec.properties do
			(effect :: any)[property] = value
		end
		effect.Parent = Lighting
	end
end

return LightingSetup
