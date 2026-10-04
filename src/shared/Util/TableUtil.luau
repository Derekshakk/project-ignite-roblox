--[[
	TableUtil

	Small table helpers shared by the data registries and game state.
]]

local TableUtil = {}

-- Recursively freezes a table so content data cannot be mutated at runtime.
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			TableUtil.deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

-- Recursively copies plain tables. Used to hand out snapshots of state so
-- callers cannot modify the live session by accident.
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = TableUtil.deepCopy(child)
	end
	return copy :: any
end

return TableUtil
