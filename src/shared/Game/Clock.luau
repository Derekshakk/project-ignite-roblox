--[[
	Clock

	In-game time of day, stored as minutes since midnight (e.g. 7:05 AM =
	425). Data files write times as text ("8:15 AM"); this module converts
	both ways. Time only moves forward during a day; see GameController
	for what advances it (scenarios, activities, zones, arriving in areas).
]]

local Clock = {}

-- "8:15 AM" → 495. Returns nil for text it can't read.
function Clock.parse(text: any): number?
	if type(text) ~= "string" then
		return nil
	end
	local hours, minutes, suffix = string.match(string.upper(text), "^%s*(%d+):(%d%d)%s*([AP]M)%s*$")
	hours, minutes = tonumber(hours), tonumber(minutes)
	if not hours or not minutes or hours < 1 or hours > 12 or minutes > 59 then
		return nil
	end
	hours %= 12
	if suffix == "PM" then
		hours += 12
	end
	return hours * 60 + minutes
end

-- 495 → "8:15 AM".
function Clock.format(totalMinutes: number?): string
	if type(totalMinutes) ~= "number" then
		return ""
	end
	local rounded = math.floor(totalMinutes + 0.5) % (24 * 60)
	local hours24 = rounded // 60
	local minutes = rounded % 60
	local hours12 = hours24 % 12
	if hours12 == 0 then
		hours12 = 12
	end
	return string.format("%d:%02d %s", hours12, minutes, if hours24 >= 12 then "PM" else "AM")
end

-- Fractional hours (8:15 AM → 8.25), e.g. for lighting.
function Clock.toHours(totalMinutes: number): number
	return totalMinutes / 60
end

return Clock
