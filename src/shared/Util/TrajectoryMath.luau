local TrajectoryMath = {}

function TrajectoryMath.SmoothStep01(value)
	local x = math.clamp(value, 0, 1)
	return x * x * (3 - 2 * x)
end

function TrajectoryMath.CurveStrength(initialDirection, targetDirection, maximumAngle)
	local angle = math.acos(math.clamp(initialDirection:Dot(targetDirection), -1, 1))
	return TrajectoryMath.SmoothStep01(angle / math.max(maximumAngle, 1e-6))
end

function TrajectoryMath.CurveSteeringMultiplier(strength, progress, retention)
	local held = 1 - math.clamp(strength, 0, 1) * math.clamp(retention, 0, 0.95)
	return held + (1 - held) * TrajectoryMath.SmoothStep01(progress)
end

function TrajectoryMath.InterceptDirection(projectilePosition, projectileSpeed, targetPosition, targetVelocity)
	local offset = targetPosition - projectilePosition
	local direct = if offset.Magnitude > 1e-6 then offset.Unit else Vector3.zero
	if projectileSpeed <= 1e-6 then return direct end
	local a = targetVelocity:Dot(targetVelocity) - projectileSpeed * projectileSpeed
	local b = 2 * offset:Dot(targetVelocity)
	local c = offset:Dot(offset)
	local time
	if math.abs(a) < 1e-6 then
		if math.abs(b) > 1e-6 then local candidate = -c / b; if candidate > 0 then time = candidate end end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant >= 0 then
			local root = math.sqrt(discriminant)
			local first, second = (-b - root) / (2 * a), (-b + root) / (2 * a)
			if first > 0 and second > 0 then time = math.min(first, second) elseif first > 0 then time = first elseif second > 0 then time = second end
		end
	end
	if not time or time ~= time or time == math.huge then return direct end
	local aim = offset + targetVelocity * time
	return if aim.Magnitude > 1e-6 then aim.Unit else direct
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

function TrajectoryMath.IsApproaching(position, velocity, target, epsilon)
	local offset = target - position
	if offset.Magnitude < 1e-6 then return true end
	return velocity:Dot(offset.Unit) > epsilon
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
	for _, value in { (-b - root) / (2 * a), (-b + root) / (2 * a) } do
		if value >= 0 and value <= 1 then return value end
	end
	return nil
end

local function pointSegmentDistance(point, a, b)
	local segment = b - a
	local denominator = segment:Dot(segment)
	if denominator < 1e-9 then return (point - a).Magnitude end
	local alpha = math.clamp((point - a):Dot(segment) / denominator, 0, 1)
	return (point - (a + segment * alpha)).Magnitude
end

function TrajectoryMath.SweptSphereVsVerticalCapsuleTime(origin, delta, center, capsuleRadius, capsuleHeight, sphereRadius)
	local radius = capsuleRadius + sphereRadius
	local halfSpine = math.max(0, capsuleHeight * 0.5 - capsuleRadius)
	local a = center - Vector3.yAxis * halfSpine
	local b = center + Vector3.yAxis * halfSpine
	if pointSegmentDistance(origin, a, b) <= radius then return 0 end
	local length = delta.Magnitude
	if length < 1e-9 then return nil end
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
	return best
end

return TrajectoryMath
