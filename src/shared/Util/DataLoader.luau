--[[
	DataLoader

	Shared helpers for the data registries (Characters, Scenarios, Activities,
	Zones, DayPlans): loading every data module in a folder and validating
	meter effect tables.
]]

local Meters = require(script.Parent.Parent.Constants.Meters)
local TableUtil = require(script.Parent.TableUtil)

local DataLoader = {}

-- Requires every ModuleScript child of `container` and passes each result
-- to `callback`. A module that errors is reported and skipped.
function DataLoader.forEachModule(container: Instance, callback: (value: any, name: string) -> ())
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				callback(result, child.Name)
			else
				warn(`[DataLoader] {child:GetFullName()} failed to load: {result}`)
			end
		end
	end
end

-- True when `effects` is a table of known meter ids mapped to real numbers.
function DataLoader.validateEffects(effects: any, label: string): boolean
	if effects == nil then
		return true
	end
	if type(effects) ~= "table" then
		warn(`[Data] {label}: effects must be a table.`)
		return false
	end
	for meterId, delta in effects do
		if not Meters.isValidId(meterId) then
			warn(`[Data] {label}: unknown meter "{meterId}".`)
			return false
		end
		if type(delta) ~= "number" or delta ~= delta then
			warn(`[Data] {label}: effect "{meterId}" must be a number.`)
			return false
		end
	end
	return true
end

--[[
	Loads modules that each return a list of entries with unique string ids.
	`validate(entry, source)` decides whether an entry is kept. Returns a
	frozen id → entry map.
]]
function DataLoader.loadById(container: Instance, label: string, validate: (any, string) -> boolean)
	local byId = {}
	DataLoader.forEachModule(container, function(list, source)
		if type(list) ~= "table" then
			warn(`[{label}] {source} must return a list.`)
			return
		end
		for _, entry in list do
			if type(entry) ~= "table" or type(entry.id) ~= "string" then
				warn(`[{label}] Entry without a string id in {source}; skipped.`)
			elseif byId[entry.id] then
				warn(`[{label}] Duplicate id "{entry.id}" in {source}; skipped.`)
			elseif validate(entry, source) then
				byId[entry.id] = TableUtil.deepFreeze(entry)
			end
		end
	end)
	return table.freeze(byId)
end

return DataLoader
