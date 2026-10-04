--[[
	Paths

	Polyline routes for background traffic and pedestrians. A route's
	corners can be rounded (quadratic curves), and positions are sampled by
	distance along the route, so movers travel at an exact speed and face
	along the curve.

		Paths.build(points, radii?, defaultRadius?) → Path
		Paths.sample(path, distance) → (position, direction)
		Paths.isHidden(position, clearance) → boolean

	Path.marks[i] is the distance along the path of route point i (for a
	rounded corner, the middle of its curve), used for stops and events.
	Path.curves lists the distance ranges of rounded corners (for slowing
	down through turns).
]]

local Paths = {}

export type Path = {
	points: { Vector3 },
	distances: { number },
	length: number,
	marks: { number },
	curves: { { from: number, to: number } },
}

local CURVE_STEPS = 8

function Paths.build(points: { Vector3 }, radii: { [number]: number }?, defaultRadius: number?): Path
	local out: { Vector3 } = {}
	local markIndex: { number } = {}
	local curveIndex: { { number } } = {}
	local function push(point: Vector3)
		local last = out[#out]
		if last == nil or (last - point).Magnitude > 0.01 then
			table.insert(out, point)
		end
	end
	for i, point in points do
		local radius = (radii and radii[i]) or defaultRadius
		if radius and radius > 0 and i > 1 and i < #points then
			local previous, nextPoint = points[i - 1], points[i + 1]
			local inLength, outLength = (point - previous).Magnitude, (nextPoint - point).Magnitude
			local r = math.min(radius, inLength / 2, outLength / 2)
			local a = point - (point - previous).Unit * r
			local b = point + (nextPoint - point).Unit * r
			local first = #out + 1
			for step = 0, CURVE_STEPS do
				local t = step / CURVE_STEPS
				push(a * (1 - t) ^ 2 + point * (2 * t * (1 - t)) + b * t * t)
				if step == CURVE_STEPS // 2 then
					markIndex[i] = #out
				end
			end
			table.insert(curveIndex, { first, #out })
		else
			push(point)
			markIndex[i] = #out
		end
	end

	local distances = { 0 }
	for i = 2, #out do
		distances[i] = distances[i - 1] + (out[i] - out[i - 1]).Magnitude
	end
	local marks = {}
	for i = 1, #points do
		marks[i] = distances[markIndex[i] or 1]
	end
	local curves = {}
	for _, range in curveIndex do
		table.insert(curves, { from = distances[math.max(1, range[1])], to = distances[range[2]] })
	end
	return {
		points = out,
		distances = distances,
		length = distances[#distances],
		marks = marks,
		curves = curves,
	}
end

-- Position and travel direction (unit, flat) at `distance` along the path.
function Paths.sample(path: Path, distance: number): (Vector3, Vector3)
	local points, distances = path.points, path.distances
	local count = #points
	if count == 1 then
		return points[1], Vector3.new(0, 0, -1)
	end
	distance = math.clamp(distance, 0, path.length)
	-- Binary search for the segment containing `distance`.
	local low, high = 1, count - 1
	while low < high do
		local middle = (low + high + 1) // 2
		if distances[middle] <= distance then
			low = middle
		else
			high = middle - 1
		end
	end
	local a, b = points[low], points[low + 1]
	local span = distances[low + 1] - distances[low]
	local t = if span > 0 then (distance - distances[low]) / span else 0
	local direction = b - a
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 1e-4 then
		direction = Vector3.new(0, 0, -1)
	end
	return a:Lerp(b, t), direction.Unit
end

--[[
	True when something can appear or disappear at `position` without the
	player noticing: it is off-screen and not right next to the camera, or
	far enough away (beyond `clearance` studs).
]]
function Paths.isHidden(position: Vector3, clearance: number): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance > clearance then
		return true
	end
	local _, onScreen = camera:WorldToViewportPoint(position)
	return not onScreen and distance > 30
end

return Paths
