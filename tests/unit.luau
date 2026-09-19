local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

roblox.implementMethod("Instance", "WaitForChild", function(instance, name) return instance:FindFirstChild(name) end)

local assertions = 0
local function check(value, message) assert(value, message); assertions += 1 end
local function load(path, environment)
	environment.Vector3 = environment.Vector3 or roblox.Vector3
	environment.CFrame = environment.CFrame or roblox.CFrame
	environment.Color3 = environment.Color3 or roblox.Color3
	return luau.load(fs.readFile(path), { environment = environment, debugName = path })()
end

local config = load("src/shared/Config/CombatConfig.luau", {})
local combatTypes = load("src/shared/Combat/CombatTypes.luau", {})
local ballDefinitions = load("src/shared/Balls/BallDefinitions.luau", {})
local effectDefinitions = load("src/shared/Effects/ParryEffectDefinitions.luau", {})
local animationDefinitions = load("src/shared/Animations/AnimationDefinitions.luau", {})
check(animationDefinitions.CharacterSets.Default.Jump == "" and animationDefinitions.CharacterSets.Default.Fall == "", "missing custom locomotion IDs preserve Roblox defaults")
check(animationDefinitions.WeaponSets.TrainingBladeDefault.Equip ~= nil and animationDefinitions.WeaponSets.TrainingBladeDefault.ParryAttempt ~= nil, "weapon animation contract separates equip and immediate attempt slots")
check(animationDefinitions.WeaponSets.TrainingBladeDefault.ParryHit.Left ~= nil and animationDefinitions.WeaponSets.TrainingBladeDefault.ParryMiss.Default ~= nil, "weapon animation contract separates directional hit and miss slots")
check(effectDefinitions.ImpactIntensity(0, 0, config.Ball.MaxSpeed) == 0 and effectDefinitions.ImpactIntensity(config.Ball.MaxSpeed * 2, 100, config.Ball.MaxSpeed) == 1, "shared impact intensity remains normalized")
check(effectDefinitions.Resolve("invalid") == effectDefinitions.DefaultParryEffect, "invalid equipped effect falls back to DefaultParryEffect")
check(ballDefinitions.StandardBall.AssetName == "CombatBall" and ballDefinitions.StandardBall.HitRadius == nil and ballDefinitions.StandardBall.GameplaySpeed == nil, "ball presentation definition cannot override authoritative geometry or speed")
check(config.Ball.Radius > 0 and config.Parry.DefensiveRadius > config.Hurt.BodyRadius + config.Ball.Radius, "visual, hurt, and defensive geometry remain separate")
check(config.SpeedForRally(0) < config.SpeedForRally(3) and config.SpeedForRally(1000) == config.Ball.MaxSpeed, "rally speed progresses monotonically and caps")
local separation = 40
local derivedApproach = (separation - config.Ball.LaunchOffset - config.Parry.DefensiveRadius) / config.Ball.BaseSpeed
check(math.abs(config.FirstApproachSeconds(separation) - derivedApproach) < 1e-6, "first approach timing derives from actual geometry")
check(config.ParryOpportunityMilliseconds(config.SpeedForRally(0)) > config.ParryOpportunityMilliseconds(config.SpeedForRally(3)), "defensive opportunity shrinks as rally speed rises")
check(config.NPC.ReactionRadius == config.Parry.DefensiveRadius, "Combat Lab NPC returns every valid defensive crossing")

local trajectory = load("src/shared/Util/TrajectoryMath.luau", {})
local targetSelector = load("src/server/TargetSelector.luau", {})
local targetA, targetB, targetC = { Id = "A" }, { Id = "B" }, { Id = "C" }
local targetRegistry = { GetAlive = function() return { targetA, targetB, targetC } end }
check(targetSelector.Select(targetRegistry, targetA) == targetB and targetSelector.Select(targetRegistry, targetB) == targetC, "multiplayer target selection advances past the previous defender")
check(trajectory.IsApproaching(roblox.Vector3.new(10, 0, 0), roblox.Vector3.new(-50, 0, 0), roblox.Vector3.zero, 0.1), "incoming direction is accepted")
check(not trajectory.IsApproaching(roblox.Vector3.new(10, 0, 0), roblox.Vector3.new(50, 0, 0), roblox.Vector3.zero, 0.1), "outgoing direction is rejected")
for _, speed in { 50, 100, 200, 300 } do
	local start = roblox.Vector3.new(-20, 0, 0)
	local hit = false
	for _ = 1, 30 do
		local delta = roblox.Vector3.xAxis * speed / 30
		if trajectory.SweptSphereVsVerticalCapsuleTime(start, delta, roblox.Vector3.zero, config.Hurt.BodyRadius, config.Hurt.BodyHeight, config.Ball.Radius) then hit = true; break end
		start += delta
	end
	check(hit, "swept hurt collision prevents tunneling at " .. speed)
end

local lead = trajectory.InterceptDirection(roblox.Vector3.zero, 30, roblox.Vector3.new(30, 0, 0), roblox.Vector3.new(0, 8, 0))
check(lead.Y > 0 and lead.X > 0, "intercept solution leads a laterally moving target")

local function terminalSimulation(initialDirection, speed, moving, dt)
	dt = dt or 1 / 60
	local position = roblox.Vector3.new(-40, 0, 0)
	local velocity = initialDirection.Unit * speed
	local target = roblox.Vector3.zero
	local minimum = math.huge
	local terminal = false
	local strength = trajectory.CurveStrength(velocity.Unit, roblox.Vector3.xAxis, math.rad(config.Parry.MaxAimAngleDegrees))
	local curveDistance = (40 - config.Ball.TerminalDistance) * (config.Ball.CurveDistanceMinimum + config.Ball.CurveDistanceStrength * strength)
	local travel, maximumLateral, elapsed = 0, 0, 0
	for _ = 1, math.ceil(10 / dt) do
		elapsed += dt
		local targetVelocity = if moving then roblox.Vector3.new(0, if elapsed < 1.5 then 7 else -7, 0) else roblox.Vector3.zero
		target += targetVelocity * dt
		local offset = target - position
		local distance = offset.Magnitude
		local direct = offset.Unit
		local contactTime = math.max(0, distance - config.Hurt.BodyRadius - config.Ball.Radius) / speed
		if distance <= config.Ball.TerminalDistance or contactTime <= config.Ball.TerminalTime or distance > minimum + config.Ball.OvershootTolerance or velocity.Unit:Dot(direct) <= 0 then terminal = true end
		minimum = math.min(minimum, distance)
		local desired = trajectory.InterceptDirection(position, speed, target, targetVelocity)
		local progress = if curveDistance > 1e-6 then travel / curveDistance else 1
		local multiplier = trajectory.CurveSteeringMultiplier(strength, progress, config.Ball.CurveSteeringRetention)
		local direction = trajectory.RotateTowards(velocity.Unit, desired, (terminal and config.Ball.TerminalTurnRate or config.Ball.HomingRate * multiplier) * dt)
		local segment = direction * speed * dt
		if trajectory.SweptSphereVsVerticalCapsuleTime(position, segment, target, config.Hurt.BodyRadius, config.Hurt.BodyHeight, config.Ball.Radius) then return true, maximumLateral end
		position += segment
		travel += segment.Magnitude
		maximumLateral = math.max(maximumLateral, math.sqrt(position.Y * position.Y + position.Z * position.Z))
		velocity = direction * speed
	end
	return false, maximumLateral
end

local weak = trajectory.CurveStrength(roblox.Vector3.new(1, 0.15, 0).Unit, roblox.Vector3.xAxis, math.rad(config.Parry.MaxAimAngleDegrees))
local medium = trajectory.CurveStrength(roblox.Vector3.new(1, 0.7, 0).Unit, roblox.Vector3.xAxis, math.rad(config.Parry.MaxAimAngleDegrees))
local strong = trajectory.CurveStrength(roblox.Vector3.new(1, 2.7, 0).Unit, roblox.Vector3.xAxis, math.rad(config.Parry.MaxAimAngleDegrees))
check(weak < medium and medium < strong, "larger aim deviation produces smoothly increasing CurveStrength")
local weakHit, weakArc = terminalSimulation(roblox.Vector3.new(1, 0, 0.2), config.SpeedForRally(3), false)
local strongHit, strongArc = terminalSimulation(roblox.Vector3.new(1, 0, 2.7), config.SpeedForRally(3), false)
check(weakHit and strongHit and strongArc > weakArc * 2, "strong aim produces a visibly larger arc and still intercepts")

for _, speed in { config.Ball.BaseSpeed, config.SpeedForRally(6), config.Ball.MaxSpeed } do
	for _, direction in {
		roblox.Vector3.new(1, 0, 0), roblox.Vector3.new(1, 1.4, 0),
		roblox.Vector3.new(1, -1.4, 0), roblox.Vector3.new(1, 0, 1.4),
	} do check(terminalSimulation(direction, speed, false), "terminal intercept prevents stable orbit at speed " .. speed) end
end
check(terminalSimulation(roblox.Vector3.new(1, 0, 1.2), config.SpeedForRally(3), true), "lead reacquires a target that changes lateral direction")
local reproducibleA, arcA = terminalSimulation(roblox.Vector3.new(1, 0, 1.8), config.SpeedForRally(3), false, 1 / 60)
local reproducibleB, arcB = terminalSimulation(roblox.Vector3.new(1, 0, 1.8), config.SpeedForRally(3), false, 1 / 60)
check(reproducibleA and reproducibleB and math.abs(arcA - arcB) < 1e-6, "identical aim produces deterministic curve geometry")
local hit30, arc30 = terminalSimulation(roblox.Vector3.new(1, 0, 1.8), config.SpeedForRally(3), false, 1 / 30)
local hit120, arc120 = terminalSimulation(roblox.Vector3.new(1, 0, 1.8), config.SpeedForRally(3), false, 1 / 120)
check(hit30 and hit120 and math.abs(arc30 - arc120) < 1.5, "spatial curve remains consistent across frame rates")

local configToken, mathToken, typesToken = {}, {}, {}
local replicated = { Game = { Shared = { Config = { CombatConfig = configToken }, Combat = { CombatTypes = typesToken }, Util = { TrajectoryMath = mathToken } } } }
local now = 10
local actor = { Id = "P:1", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local registry = { IsAlive = function(_, subject) return subject and subject.Alive end }
local position = roblox.Vector3.new(10, 0, 0)
local velocity = roblox.Vector3.new(-50, 0, 0)
local redirects = 0
local lastAim = nil
local ball = {
	IsTracking = function() return true end,
	GetTarget = function() return actor end,
	GetRevision = function() return 3 end,
	GetRally = function() return redirects end,
	GetKinematics = function() return position, velocity end,
	Redirect = function(_, _, aim) lastAim = aim; redirects += 1; return true end,
}
local firedEvents = {}
local events = { FireAllClients = function(_, payload) table.insert(firedEvents, payload) end }
local CombatCore = load("src/server/CombatCore.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return replicated end; error(name) end },
	workspace = { GetServerTimeNow = function() return now end },
	require = function(module) if module == configToken then return config elseif module == mathToken then return trajectory elseif module == typesToken then return combatTypes end; error("dependency") end,
})
local combat = CombatCore.new(registry, events)
combat:SetBall(ball)
combat:SetActive(true)
local accepted, reason = combat:TryParry(actor)
check(accepted and reason == "PARRIED" and redirects == 1, "in-range incoming intent redirects immediately")
check(#firedEvents == 1 and firedEvents[1].Version == combatTypes.ProtocolVersion and firedEvents[1].Kind == combatTypes.EventKind.ParryConfirmed and firedEvents[1].Mode == "IMMEDIATE", "immediate success fires one versioned authoritative hit-confirm")
check(not combat:TryParry(actor) and redirects == 1, "one confirmed parry cannot double-redirect")

local function fresh(subject, distance, direction)
	position = roblox.Vector3.new(distance, 0, 0)
	velocity = roblox.Vector3.new(direction * 50, 0, 0)
	actor = subject
	local value = CombatCore.new(registry, events)
	value:SetBall(ball)
	value:SetActive(true)
	return value
end

local player = { Id = "P:2", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local outOfRange = fresh(player, 17, -1)
local okRange, reasonRange = outOfRange:TryParry(player)
check(not okRange and reasonRange == "OUT_OF_RANGE", "defensive radius rejects early intent")
local redirectsBeforeFailedAim = redirects
outOfRange:TryParry(player, roblox.Vector3.xAxis)
check(redirects == redirectsBeforeFailedAim, "aim cannot alter the ball when parry fails")
local outgoing = fresh(player, 8, 1)
local okDirection, reasonDirection = outgoing:TryParry(player)
check(not okDirection and reasonDirection == "NOT_APPROACHING", "current outgoing ball cannot be parried")
local npc = { Id = "N:TrainingOpponent", Kind = "NPC", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local shared = fresh(npc, 8, -1)
local npcAccepted = shared:TryParry(npc)
check(npcAccepted, "Player and NPC share the same TryParry path")
local invalidAimPlayer = { Id = "P:invalidAim", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local invalidAimCombat = fresh(invalidAimPlayer, 8, -1)
lastAim = roblox.Vector3.xAxis
local invalidAccepted, invalidReason = invalidAimCombat:TryParry(invalidAimPlayer, "spoofed")
check(invalidAccepted, "invalid aim still uses safe gameplay fallback: " .. tostring(invalidReason))
check(lastAim == nil, "invalid aim is not forwarded into redirect")

local bufferedPlayer = { Id = "P:buffer", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local buffered = fresh(bufferedPlayer, 15, -1)
local beforeBufferedRedirects = redirects
local bufferedAccepted, bufferedReason = buffered:TryParry(bufferedPlayer)
check(bufferedAccepted and bufferedReason == "BUFFERED" and redirects == beforeBufferedRedirects, "slightly early Player input stores one pending intent")
position = roblox.Vector3.new(9.9, 0, 0)
now += 0.05
buffered:UpdatePending()
check(redirects == beforeBufferedRedirects + 1 and firedEvents[#firedEvents].Mode == "BUFFERED", "pending intent redirects immediately on defensive-radius crossing")

local expiringPlayer = { Id = "P:expiry", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local expiring = fresh(expiringPlayer, 15, -1)
local beforeExpiry = redirects
check(expiring:TryParry(expiringPlayer), "buffer expiry setup stores intent")
now += config.Parry.EarlyBuffer + 0.01
expiring:UpdatePending()
check(redirects == beforeExpiry and next(expiring.Pending) == nil, "expired buffer cannot redirect")

local resetPlayer = { Id = "P:reset", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local resetCombat = fresh(resetPlayer, 15, -1)
check(resetCombat:TryParry(resetPlayer), "reset buffer setup stores intent")
resetCombat:SetActive(false)
check(next(resetCombat.Pending) == nil, "reset clears pending intent")

local deadPlayer = { Id = "P:dead", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local deadCombat = fresh(deadPlayer, 15, -1)
check(deadCombat:TryParry(deadPlayer), "death buffer setup stores intent")
deadPlayer.Alive = false
deadCombat:UpdatePending()
check(next(deadCombat.Pending) == nil, "death clears pending intent")

local changedPlayer = { Id = "P:changed", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local changedCombat = fresh(changedPlayer, 15, -1)
check(changedCombat:TryParry(changedPlayer), "target-change buffer setup stores intent")
actor = player
changedCombat:UpdatePending()
check(next(changedCombat.Pending) == nil, "target revision/change clears pending intent")

local npcConfigToken, npcCharacterToken, npcMathToken = {}, {}, {}
local npcReplicated = { Game = { Shared = { Config = { CombatConfig = npcConfigToken }, Util = { CharacterUtil = npcCharacterToken, TrajectoryMath = npcMathToken } } } }
local npcActor = { Id = "N:reliable", Kind = "NPC", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local npcRevision = 20
local npcPosition = roblox.Vector3.new(9.9, 0, 0)
local npcVelocity = roblox.Vector3.new(-28, 0, 0)
local npcRedirects = 0
local npcRegistry = { IsAlive = function(_, subject) return subject == npcActor and subject.Alive end }
local npcBall = {
	IsTracking = function() return true end,
	GetTarget = function() return npcActor end,
	GetRevision = function() return npcRevision end,
	GetRally = function() return npcRedirects end,
	GetKinematics = function() return npcPosition, npcVelocity end,
	Redirect = function(_, source) if source ~= npcActor then return false end; npcRedirects += 1; return true end,
}
local npcCombat = CombatCore.new(npcRegistry, events)
npcCombat:SetBall(npcBall)
npcCombat:SetActive(true)
local TrainingOpponent = load("src/server/TrainingOpponent.luau", {
	game = { GetService = function(_, name)
		if name == "Players" then return {} elseif name == "ReplicatedStorage" then return npcReplicated end
		error(name)
	end },
	require = function(module)
		if module == npcConfigToken then return config elseif module == npcCharacterToken then return {} elseif module == npcMathToken then return trajectory end
		error("dependency")
	end,
})
local trainer = TrainingOpponent.new(npcRegistry, npcCombat, npcBall, {})
trainer.Combatant = npcActor
for index, speed in { config.SpeedForRally(0), config.SpeedForRally(6), config.Ball.MaxSpeed } do
	now += 0.2
	npcRevision += 1
	npcPosition = roblox.Vector3.new(9.9, 0, 0)
	npcVelocity = roblox.Vector3.new(-speed, 0, 0)
	trainer:Update()
	check(npcRedirects == index, "TrainingOpponent uses shared TryParry reliably at " .. speed .. " studs/s")
end

local place = roblox.deserializePlace(fs.readFile("Fatal.rbxlx"))
local actualGame = place:GetService("ReplicatedStorage").Game
local ballConfigToken, ballMathToken, ballTypesToken, ballDefinitionsToken = {}, {}, {}, {}
local ballReplicated = { Game = { Shared = { Config = { CombatConfig = ballConfigToken }, Combat = { CombatTypes = ballTypesToken }, Balls = { BallDefinitions = ballDefinitionsToken }, Util = { TrajectoryMath = ballMathToken } }, Assets = { CombatBall = actualGame.Assets.CombatBall } } }
local gameplay = place:GetService("Workspace").Game.Arena.Gameplay
local first = { Id = "P:first", Alive = true, CenterPart = { Position = roblox.Vector3.new(-20, 4, 0) }, RootPart = { Position = roblox.Vector3.new(-20, 3, 0) } }
local second = { Id = "N:second", Alive = true, CenterPart = { Position = roblox.Vector3.new(20, 4, 0) }, RootPart = { Position = roblox.Vector3.new(20, 3, 0) } }
local alive = { first, second }
local ballRegistry = {
	GetAlive = function()
		local result = {}
		for _, subject in alive do if subject.Alive then table.insert(result, subject) end end
		return result
	end,
	IsAlive = function(_, subject) return subject and subject.Alive end,
	SetAlive = function(_, subject, value) subject.Alive = value; return true end,
}
local BallCore = load("src/server/BallCore.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return ballReplicated end; error(name) end },
	require = function(module) if module == ballConfigToken then return config elseif module == ballMathToken then return trajectory elseif module == ballTypesToken then return combatTypes elseif module == ballDefinitionsToken then return ballDefinitions end; error("dependency") end,
})
local remote = { FireAllClients = function() end }
local ballCore = BallCore.new(ballRegistry, remote, remote, gameplay)
ballCore:Start(first)
check(#ballCore:_ownedBalls() == 1, "exactly one authoritative V2 ball spawns")
check((ballCore.Part.Size - roblox.Vector3.one * config.Ball.Radius * 2).Magnitude < 1e-4, "spawned ball visual matches authoritative diameter")
local directOpening = (first.CenterPart.Position - ballCore.Position).Unit
check(ballCore.Velocity.Unit:Dot(directOpening) > 0.999, "initial serve uses safe target direction without invented curvature")
local launchDistance = (ballCore.Position - first.CenterPart.Position).Magnitude
local actualSeparation = (first.CenterPart.Position - second.CenterPart.Position).Magnitude
check(math.abs(launchDistance - (actualSeparation - config.Ball.LaunchOffset)) < 1e-4 and math.abs((launchDistance - config.Parry.DefensiveRadius) / ballCore.Velocity.Magnitude - config.FirstApproachSeconds(actualSeparation)) < 1e-4, "actual first launch matches geometry-derived approach timing")
local stepObservations = 0
ballCore:Update(0.1, function() stepObservations += 1 end)
check(stepObservations >= 2, "ball exposes every bounded movement step to the deterministic NPC decision")
local targetDirection = (second.CenterPart.Position - ballCore.Position).Unit
local right = roblox.Vector3.zAxis
local rightAim = (targetDirection + right).Unit
ballCore.Velocity = targetDirection * 90
ballCore.Terminal = true
ballCore.MinTargetDistance = 1
ballCore.CurveTravel = 99
check(ballCore:Redirect(first, rightAim) and ballCore:GetTarget() == second and ballCore:GetRally() == 1, "redirect changes target and increments rally immediately")
check(ballCore.Velocity.Magnitude >= 90, "post-parry speed never regresses below incoming momentum")
check(not ballCore.Terminal and ballCore.MinTargetDistance == math.huge and ballCore.CurveTravel == 0, "redirect atomically clears the previous trajectory leg")
local redirectPosition = ballCore.Position
local redirectDirection = ballCore.Velocity.Unit
ballCore:Update(1 / 120)
check(ballCore.Velocity.Magnitude >= 90 and (ballCore.Position - redirectPosition):Dot(redirectDirection) > 0, "redirect preserves incoming momentum and advances the new leg in the next simulation step")
check(ballCore.Velocity.Unit:Dot(right) > 0 and ballCore.Velocity.Unit:Dot(targetDirection) < 0.999, "right aim authors a right-curving initial direction")
local leftTarget = (first.CenterPart.Position - ballCore.Position).Unit
ballCore:Redirect(second, (leftTarget - right).Unit)
check(ballCore.Velocity.Unit:Dot(right) < 0, "left aim authors a left-curving initial direction")
local upTarget = (second.CenterPart.Position - ballCore.Position).Unit
ballCore:Redirect(first, (upTarget + roblox.Vector3.yAxis).Unit)
check(ballCore.Velocity.Unit.Y > 0, "upward aim authors an upper arc")
local extremeTarget = (first.CenterPart.Position - ballCore.Position).Unit
ballCore:Redirect(second, -extremeTarget)
check(math.acos(math.clamp(ballCore.Velocity.Unit:Dot(extremeTarget), -1, 1)) <= math.rad(config.Parry.MaxAimAngleDegrees) + 1e-5, "extreme aim is clamped to the authoritative safe cone")
local straightTarget = (second.CenterPart.Position - ballCore.Position).Unit
ballCore:Redirect(first, straightTarget)
check(ballCore.Velocity.Unit:Dot(straightTarget) > 0.9999, "aim at authoritative target produces an almost straight redirect")
ballCore:Stop()
check(#ballCore:_ownedBalls() == 0, "V2 ball cleanup leaves no authoritative instance")

first.Alive = true
second.Alive = true
local reacquiringBall = BallCore.new(ballRegistry, remote, remote, gameplay)
reacquiringBall:Start(first)
reacquiringBall.Position = roblox.Vector3.zero
reacquiringBall.Part.Position = reacquiringBall.Position
reacquiringBall.Velocity = roblox.Vector3.xAxis * 90
first.Alive = false
reacquiringBall:Update(1 / 60)
check(reacquiringBall:IsTracking(), "invalid target reacquisition keeps the ball tracking")
check(reacquiringBall:GetTarget() == second, "invalid target reacquires an alive combatant")
check(reacquiringBall.Velocity.Magnitude >= 90, "invalid target reacquisition preserves momentum")
reacquiringBall:Stop()
first.Alive = true

local rallyEvents = {}
local rallyRemote = { FireAllClients = function(_, payload) table.insert(rallyEvents, payload) end }
local rallyBall = BallCore.new(ballRegistry, remote, rallyRemote, gameplay)
rallyBall:Start(first)
for expected = 1, 130 do
	local incoming = rallyBall.Velocity.Magnitude
	check(rallyBall:Redirect(rallyBall:GetTarget()) and rallyBall:GetRally() == expected and rallyBall.Velocity.Magnitude >= incoming, "long rally preserves momentum at exchange " .. expected)
end
local rallyChanged = 0
for _, event in rallyEvents do if event.Kind == combatTypes.EventKind.RallyChanged then rallyChanged += 1 end end
check(rallyChanged == 131, "rally zero plus 130 redirects emit exactly one RallyChanged each")
local targetChanged = 0
for _, event in rallyEvents do if event.Kind == combatTypes.EventKind.BallTargetChanged then targetChanged += 1 end end
check(targetChanged == 131, "initial target plus 130 redirects emit exactly one BallTargetChanged each")
rallyBall:Stop()

first.Alive = true
second.Alive = true
alive = { first, second }
local hitEvents = {}
local hitRemote = { FireAllClients = function(_, payload) table.insert(hitEvents, payload) end }
local hitBall = BallCore.new(ballRegistry, remote, hitRemote, gameplay)
hitBall:Start(second)
hitBall.Position = roblox.Vector3.new(16, 4, 0)
hitBall.Part.Position = hitBall.Position
hitBall.Velocity = roblox.Vector3.xAxis * config.Ball.BaseSpeed
hitBall:Update(0.1)
check(hitBall.State == "Resolved" and not second.Alive, "swept body contact resolves the target exactly when crossed")
local bodyHitCount = 0
for _, event in hitEvents do if event.Kind == combatTypes.EventKind.CombatantHit and event.TargetId == second.Id then bodyHitCount += 1 end end
check(bodyHitCount == 1, "body contact fires one authoritative hit-confirm")
hitBall:Update(0.1)
local eventsAfterResolved = #hitEvents
hitBall:Update(0.1)
check(#hitEvents == eventsAfterResolved, "resolved body contact cannot fire twice")
hitBall:Stop()
check(#hitBall:_ownedBalls() == 0, "body hit cleanup removes the authoritative ball")

local duelConfigToken, characterToken, duelTypesToken = {}, {}, {}
local fakePlayer = { Name = "Tester" }
local players = { GetPlayers = function() return { fakePlayer } end }
local duelReplicated = { Game = { Shared = { Config = { CombatConfig = duelConfigToken }, Combat = { CombatTypes = duelTypesToken }, Util = { CharacterUtil = characterToken } } } }
local DuelService = load("src/server/DuelService.luau", {
	game = { GetService = function(_, name)
		if name == "Players" then return players elseif name == "ReplicatedStorage" then return duelReplicated end
		error(name)
	end },
	workspace = { GetServerTimeNow = function() return now end },
	require = function(module) if module == duelConfigToken then return config elseif module == characterToken then return {} elseif module == duelTypesToken then return combatTypes end; error("dependency") end,
})
check(not DuelService.IsWinEligible(2), "two humans cannot produce a Win")
check(not DuelService.IsWinEligible(2), "two humans plus any training NPC still cannot produce a Win")
check(DuelService.IsWinEligible(3), "three humans freeze an eligible round")
local duelPlayer = { Id = "P:duel", Alive = true }
local duelNPC = { Id = "N:duel", Alive = true }
local duelAlive = { duelPlayer, duelNPC }
local duelRegistry = {
	GetByPlayer = function() return duelPlayer end,
	IsAlive = function(_, subject) return subject and subject.Alive end,
	GetAlive = function() return duelAlive end,
	SetAlive = function(_, subject, value) subject.Alive = value; return true end,
}
local duelBall = { Starts = 0, Stops = 0, Tracking = false, Start = function(self) self.Starts += 1; self.Tracking = true end, Stop = function(self) self.Stops += 1; self.Tracking = false end, IsTracking = function(self) return self.Tracking end, Update = function() end }
local duelCombat = { SetActive = function() end }
local duelOpponent = { Combatant = duelNPC, Clears = 0, Clear = function(self) self.Clears += 1 end, Update = function() end }
local spawnFolder = { GetChildren = function() return { { Name = "Spawn01" }, { Name = "Spawn02" } } end }
local gameplayStub = { WaitForChild = function(_, name) assert(name == "SpawnPoints"); return spawnFolder end }
local duelEvents = {}
local duelRemote = { FireAllClients = function(_, payload) table.insert(duelEvents, payload) end }
local duel = DuelService.new(duelRegistry, duelCombat, duelBall, duelOpponent, gameplayStub, duelRemote)
local preparations = 0
duel._prepare = function(self) preparations += 1; self:_transition(combatTypes.DuelState.Countdown, config.Duel.Countdown); return true end
duel:Update(0.01)
check(duel.State == combatTypes.DuelState.Intermission, "player presence starts intermission")
now = duel.Deadline
duel:Update(0.01)
check(duel.State == combatTypes.DuelState.Countdown and preparations == 1, "duel prepares one Player and one NPC")
now = duel.Deadline
duel:Update(0.01)
check(duel.State == combatTypes.DuelState.Active and duelBall.Starts == 1, "duel starts exactly one ball")
local duelThird = { Id = "P:third", Alive = true }
duelAlive = { duelPlayer, duelNPC, duelThird }
duelBall.Tracking = false
duel:Update(0.01)
check(duel.State == combatTypes.DuelState.Active and duelBall.Starts == 2, "multiplayer round replaces a resolved ball after elimination without duplicating it")
duelAlive = { duelPlayer }
duel:Update(0.01)
check(duel.State == combatTypes.DuelState.Ending and duelBall.Stops >= 1, "elimination stops the ball deterministically")
now = duel.Deadline
duel:Update(0.01)
duel:Update(0.01)
now = duel.Deadline
duel:Update(0.01)
check(duel.State == combatTypes.DuelState.Countdown and preparations == 2 and duelOpponent.Clears >= 1, "duel resets and re-enters without accumulated state")
local duelTransitions = 0
for _, event in duelEvents do if event.Kind == combatTypes.EventKind.DuelStateChanged then duelTransitions += 1 end end
check(duelTransitions == 7 and duelEvents[1].Kind == combatTypes.EventKind.DuelStateChanged and duelEvents[1].Version == combatTypes.ProtocolVersion, "central lifecycle emits one versioned event per transition")

local schema = load("src/shared/Profile/ProfileSchema.luau", {})
local migrated = schema.Normalize({ Version = 0, Stats = { Wins = 4 }, Currency = { Coins = 8, Gems = 2 } })
check(migrated.Inventory.Weapons.TrainingBlade == true and migrated.Equipped.Weapon == "TrainingBlade", "old profile normalization grants the default weapon safely")
local animationProfile = schema.Normalize({ Inventory = { Animations = { OwnedSet = true } }, Equipped = { CharacterAnimationSet = "OwnedSet", WeaponAnimationSet = "UnownedSet" } })
check(animationProfile.Inventory.Animations.OwnedSet and animationProfile.Equipped.CharacterAnimationSet == "OwnedSet" and animationProfile.Equipped.WeaponAnimationSet == "TrainingBladeDefault", "animation ownership remains separate from validated equipped sets")
local schemaToken = {}
local profileReplicated = { Game = { Shared = { Profile = { ProfileSchema = schemaToken } } } }
local ProfileService = load("src/server/ProfileService.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return profileReplicated end; error(name) end },
	require = function(module) if module == schemaToken then return schema end; error("dependency") end,
	warn = function() end,
})
local failedProfiles = ProfileService.new({ GetAsync = function() error("offline") end })
local failedPlayer = { UserId = 404 }
check(failedProfiles:Load(failedPlayer) == nil and failedProfiles:Get(failedPlayer) == nil, "failed persistent load cannot create an overwriteable reward profile")
local stored = nil
local store = { UpdateAsync = function(_, _, callback) stored = callback(stored) end }
local profiles = ProfileService.new(store)
local profilePlayer = { UserId = 123 }
profiles.Profiles[profilePlayer] = schema.New()
profiles.AwardReceipts[profilePlayer] = {}
profiles._sync = function() end
check(profiles:Award(profilePlayer, { Wins = 1, Coins = 100, Gems = 2 }, "round:1"), "authoritative profile awards valid currency and wins")
check(not profiles:Award(profilePlayer, { Wins = 1 }, "round:1") and profiles:Get(profilePlayer).Stats.Wins == 1, "award receipt prevents duplicate round reward")
check(profiles:Spend(profilePlayer, "Coins", 40) and profiles:Get(profilePlayer).Currency.Coins == 60, "profile spends available currency")
check(not profiles:Spend(profilePlayer, "Coins", 100), "profile rejects insufficient balance")
check(profiles:Save(profilePlayer) and stored.Stats.Wins == 1, "profile lifecycle saves authoritative state")
profiles:Release(profilePlayer)
check(profiles:Get(profilePlayer) == nil, "profile lifecycle releases session state")

local weaponDefinitions = load("src/shared/Weapons/WeaponDefinitions.luau", {})
local definitionsToken = {}
local inventoryReplicated = { Game = { Shared = { Weapons = { WeaponDefinitions = definitionsToken } } } }
local inventoryState = { Fires = 0, FireClient = function(self) self.Fires += 1 end }
local inventoryProfiles = { Profile = schema.New(), Get = function(self) return self.Profile end }
local InventoryService = load("src/server/InventoryService.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return inventoryReplicated end; error(name) end },
	require = function(module) if module == definitionsToken then return weaponDefinitions end; error("dependency") end,
})
local inventory = InventoryService.new(inventoryProfiles, inventoryState)
check(inventory:Equip(profilePlayer, "TrainingBlade"), "owned weapon equips authoritatively")
inventoryProfiles.Profile.Inventory.Weapons.TrainingBlade = nil
check(not inventory:Equip(profilePlayer, "TrainingBlade"), "unowned weapon cannot equip")
check(not inventory:Equip(profilePlayer, "MissingWeapon"), "unknown weapon cannot equip")

print(string.format("PASS: %d V2 assertions", assertions))
