--[[
	Settings

	Player-adjustable comfort and accessibility options. Every optional
	effect checks its setting, so anything that could be distracting can be
	turned off from the Settings panel (P). Values last for the session.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local Settings = {}

Settings.Changed = Signal.new()

Settings.Definitions = table.freeze({
	{ key = "cameraMotion", label = "Camera motion", description = "Landing dip and marker bobbing" },
	{ key = "highlights", label = "Object highlights", description = "Outline on things you can use" },
	{ key = "objectiveMarker", label = "Objective marker", description = "Marker over your next goal" },
	{ key = "environmentAudio", label = "Environment sounds", description = "Room and crowd ambience" },
	{ key = "captions", label = "Captions", description = "Subtitles for spoken lines" },
})

local values = {
	cameraMotion = true,
	highlights = true,
	objectiveMarker = true,
	environmentAudio = true,
	captions = true,
}

function Settings.get(key: string): boolean
	return values[key] == true
end

function Settings.set(key: string, value: boolean)
	if values[key] == nil or values[key] == value then
		return
	end
	values[key] = value
	Settings.Changed:Fire(key, value)
end

function Settings.toggle(key: string)
	Settings.set(key, not values[key])
end

return Settings
