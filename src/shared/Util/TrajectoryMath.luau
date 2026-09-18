local TrajectoryMath = {}

function TrajectoryMath.Reflect(direction, normal)
	return (direction - normal * (2 * direction:Dot(normal))).Unit
end

function TrajectoryMath.RotateTowards(current, desired, maxRadians)
	local from = current.Unit
	local to = desired.Unit
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= maxRadians or angle < 1e-6 then return to end
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then axis = from:Cross(math.abs(from.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis) end
	return CFrame.fromAxisAngle(axis.Unit, maxRadians):VectorToWorldSpace(from).Unit
end

function TrajectoryMath.SegmentSphereTime(origin, delta, center, radius)
	local relative = origin - center
	if relative:Dot(relative) <= radius * radius then return 0 end
	local a = delta:Dot(delta)
	if a < 1e-9 then return nil end
	local b = 2 * relative:Dot(delta)
	local c = relative:Dot(relative) - radius * radius
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then return nil end
	local root = math.sqrt(discriminant)
	local first = (-b - root) / (2 * a)
	local second = (-b + root) / (2 * a)
	if first >= 0 and first <= 1 then return first end
	if second >= 0 and second <= 1 then return second end
	return nil
end

local function pointSegmentDistance(point, a, b)
	local ab = b - a
	local denominator = ab:Dot(ab)
	if denominator < 1e-9 then return (point - a).Magnitude end
	local t = math.clamp((point - a):Dot(ab) / denominator, 0, 1)
	return (point - (a + ab * t)).Magnitude
end

-- Continuous swept-sphere against a vertical capsule. Returns segment fraction and
-- closest centerline distance, so gameplay and debug use the same geometry.
function TrajectoryMath.SweptSphereVsVerticalCapsuleTime(origin, delta, center, capsuleRadius, capsuleHeight, sphereRadius)
	local radius = capsuleRadius + sphereRadius
	local halfSpine = math.max(0, capsuleHeight * 0.5 - capsuleRadius)
	local a = center - Vector3.yAxis * halfSpine
	local b = center + Vector3.yAxis * halfSpine
	if pointSegmentDistance(origin, a, b) <= radius then return 0, pointSegmentDistance(origin, a, b) end
	local length = delta.Magnitude
	if length < 1e-9 then return nil, pointSegmentDistance(origin, a, b) end
	local direction = delta / length
	local ba = b - a
	local oa = origin - a
	local baba = ba:Dot(ba)
	local bard = ba:Dot(direction)
	local baoa = ba:Dot(oa)
	local rdoa = direction:Dot(oa)
	local oaoa = oa:Dot(oa)
	local qa = baba - bard * bard
	local qb = baba * rdoa - baoa * bard
	local qc = baba * oaoa - baoa * baoa - radius * radius * baba
	local best = nil
	local discriminant = qb * qb - qa * qc
	if math.abs(qa) > 1e-9 and discriminant >= 0 then
		local distance = (-qb - math.sqrt(discriminant)) / qa
		local y = baoa + distance * bard
		if distance >= 0 and distance <= length and y > 0 and y < baba then best = distance / length end
	end
	for _, cap in { a, b } do
		local fraction = TrajectoryMath.SegmentSphereTime(origin, delta, cap, radius)
		if fraction and (not best or fraction < best) then best = fraction end
	end
	local closest = if best then pointSegmentDistance(origin + delta * best, a, b)
		else math.min(pointSegmentDistance(origin, a, b), pointSegmentDistance(origin + delta, a, b))
	return best, closest
end

function TrajectoryMath.IsWithinArc(forward, origin, point, arcDegrees)
	local offset = point - origin
	if offset.Magnitude < 1e-6 then return true, 1 end
	local dot = forward.Unit:Dot(offset.Unit)
	return dot >= math.cos(math.rad(arcDegrees * 0.5)), dot
end

function TrajectoryMath.ClosingSpeed(ballPosition, direction, speed, targetPosition, targetVelocity)
	local offset = targetPosition - ballPosition
	if offset.Magnitude < 1e-6 then return speed end
	return math.max(0, (direction * speed - targetVelocity):Dot(offset.Unit))
end

function TrajectoryMath.TimeToImpact(ballPosition, direction, speed, targetPosition, targetVelocity, radius)
	local distance = math.max(0, (targetPosition - ballPosition).Magnitude - radius)
	local closing = TrajectoryMath.ClosingSpeed(ballPosition, direction, speed, targetPosition, targetVelocity)
	return if closing > 1e-4 then distance / closing else math.huge
end

return TrajectoryMath
