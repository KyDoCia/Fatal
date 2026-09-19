local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

roblox.implementMethod("Instance", "WaitForChild", function(instance, name) return instance:FindFirstChild(name) end)

local assertions = 0
local function check(value, message) assert(value, message); assertions += 1 end
local function load(path, environment)
	environment.Vector3 = environment.Vector3 or roblox.Vector3
	environment.CFrame = environment.CFrame or roblox.CFrame
	return luau.load(fs.readFile(path), { environment = environment, debugName = path })()
end

local config = load("src/shared/Config/CombatConfig.luau", {})
check(config.Ball.Radius == 1 and config.Parry.DefensiveRadius == 10, "V3 readable ball and defensive radius are explicit")
check(config.SpeedForRally(0) == 28 and config.SpeedForRally(3) == 40 and config.SpeedForRally(100) == 140, "V3 rally speed is linear and capped")
check(math.abs(config.FirstApproachSeconds(40) - 1) < 1e-6, "first ball derives one second of reading time from actual separation")
check(math.abs(config.ParryOpportunityMilliseconds(config.SpeedForRally(0)) - 257.142857) < 0.01, "rally zero has a learnable defensive opportunity")
check(config.ParryOpportunityMilliseconds(config.SpeedForRally(3)) >= 180 and config.ParryOpportunityMilliseconds(config.SpeedForRally(6)) > 138, "defensive opportunity shrinks progressively")
check(config.NPC.MissChance == 0 and config.NPC.ReactionDelay == 0, "Combat Lab NPC has deterministic zero-miss reaction")

local trajectory = load("src/shared/Util/TrajectoryMath.luau", {})
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

local configToken, mathToken = {}, {}
local replicated = { Game = { Shared = { Config = { CombatConfig = configToken }, Util = { TrajectoryMath = mathToken } } } }
local now = 10
local actor = { Id = "P:1", Kind = "Player", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local registry = { IsAlive = function(_, subject) return subject and subject.Alive end }
local position = roblox.Vector3.new(10, 0, 0)
local velocity = roblox.Vector3.new(-50, 0, 0)
local redirects = 0
local ball = {
	IsTracking = function() return true end,
	GetTarget = function() return actor end,
	GetRevision = function() return 3 end,
	GetRally = function() return redirects end,
	GetKinematics = function() return position, velocity end,
	Redirect = function() redirects += 1; return true end,
}
local firedEvents = {}
local events = { FireAllClients = function(_, payload) table.insert(firedEvents, payload) end }
local CombatCore = load("src/server/CombatCore.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return replicated end; error(name) end },
	workspace = { GetServerTimeNow = function() return now end },
	require = function(module) if module == configToken then return config elseif module == mathToken then return trajectory end; error("dependency") end,
})
local combat = CombatCore.new(registry, events)
combat:SetBall(ball)
combat:SetActive(true)
local accepted, reason = combat:TryParry(actor)
check(accepted and reason == "PARRIED" and redirects == 1, "in-range incoming intent redirects immediately")
check(#firedEvents == 1 and firedEvents[1].Kind == "ParryConfirmed" and firedEvents[1].Mode == "IMMEDIATE", "immediate success fires one authoritative hit-confirm")
check(not combat:TryParry(actor), "simple cooldown rejects immediate repeat")

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
local outgoing = fresh(player, 8, 1)
local okDirection, reasonDirection = outgoing:TryParry(player)
check(not okDirection and reasonDirection == "NOT_APPROACHING", "current outgoing ball cannot be parried")
local npc = { Id = "N:TrainingOpponent", Kind = "NPC", Alive = true, CenterPart = { Position = roblox.Vector3.zero } }
local shared = fresh(npc, 8, -1)
local npcAccepted = shared:TryParry(npc)
check(npcAccepted, "Player and NPC share the same TryParry path")

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
for index, speed in { 28, 52, 140 } do
	now += 0.2
	npcRevision += 1
	npcPosition = roblox.Vector3.new(9.9, 0, 0)
	npcVelocity = roblox.Vector3.new(-speed, 0, 0)
	trainer:Update()
	check(npcRedirects == index, "TrainingOpponent uses shared TryParry reliably at " .. speed .. " studs/s")
end

local place = roblox.deserializePlace(fs.readFile("Fatal.rbxlx"))
local actualGame = place:GetService("ReplicatedStorage").Game
local ballConfigToken, ballMathToken = {}, {}
local ballReplicated = { Game = { Shared = { Config = { CombatConfig = ballConfigToken }, Util = { TrajectoryMath = ballMathToken } }, Assets = { CombatBall = actualGame.Assets.CombatBall } } }
local gameplay = place:GetService("Workspace").Game.Arena.Gameplay
local first = { Id = "P:first", Alive = true, CenterPart = { Position = roblox.Vector3.new(-20, 4, 0) }, RootPart = { Position = roblox.Vector3.new(-20, 3, 0) } }
local second = { Id = "N:second", Alive = true, CenterPart = { Position = roblox.Vector3.new(20, 4, 0) }, RootPart = { Position = roblox.Vector3.new(20, 3, 0) } }
local alive = { first, second }
local ballRegistry = {
	GetAlive = function() return alive end,
	IsAlive = function(_, subject) return subject and subject.Alive end,
	SetAlive = function(_, subject, value) subject.Alive = value; return true end,
}
local BallCore = load("src/server/BallCore.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return ballReplicated end; error(name) end },
	require = function(module) if module == ballConfigToken then return config elseif module == ballMathToken then return trajectory end; error("dependency") end,
})
local remote = { FireAllClients = function() end }
local ballCore = BallCore.new(ballRegistry, remote, remote, gameplay)
ballCore:Start(first)
check(#ballCore:_ownedBalls() == 1, "exactly one authoritative V2 ball spawns")
check((ballCore.Part.Size - roblox.Vector3.one * config.Ball.Radius * 2).Magnitude < 1e-4, "spawned ball visual matches authoritative diameter")
local launchDistance = (ballCore.Position - first.CenterPart.Position).Magnitude
check(math.abs(launchDistance - 38) < 1e-4 and math.abs((launchDistance - config.Parry.DefensiveRadius) / ballCore.Velocity.Magnitude - 1) < 1e-4, "actual first launch provides one second before the defensive zone")
local stepObservations = 0
ballCore:Update(0.1, function() stepObservations += 1 end)
check(stepObservations >= 2, "ball exposes every bounded movement step to the deterministic NPC decision")
check(ballCore:Redirect(first) and ballCore:GetTarget() == second and ballCore:GetRally() == 1, "redirect changes target and increments rally immediately")
ballCore:Stop()
check(#ballCore:_ownedBalls() == 0, "V2 ball cleanup leaves no authoritative instance")

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
check(#hitEvents == 1 and hitEvents[1].Kind == "BodyHit" and hitEvents[1].TargetId == second.Id, "body contact fires one authoritative hit-confirm")
hitBall:Update(0.1)
check(#hitEvents == 1, "resolved body contact cannot fire twice")
hitBall:Stop()
check(#hitBall:_ownedBalls() == 0, "body hit cleanup removes the authoritative ball")

local duelConfigToken, characterToken = {}, {}
local fakePlayer = { Name = "Tester" }
local players = { GetPlayers = function() return { fakePlayer } end }
local duelReplicated = { Game = { Shared = { Config = { CombatConfig = duelConfigToken }, Util = { CharacterUtil = characterToken } } } }
local DuelService = load("src/server/DuelService.luau", {
	game = { GetService = function(_, name)
		if name == "Players" then return players elseif name == "ReplicatedStorage" then return duelReplicated end
		error(name)
	end },
	workspace = { GetServerTimeNow = function() return now end },
	require = function(module) if module == duelConfigToken then return config elseif module == characterToken then return {} end; error("dependency") end,
})
local duelPlayer = { Id = "P:duel", Alive = true }
local duelNPC = { Id = "N:duel", Alive = true }
local duelAlive = { duelPlayer, duelNPC }
local duelRegistry = {
	GetByPlayer = function() return duelPlayer end,
	IsAlive = function(_, subject) return subject and subject.Alive end,
	GetAlive = function() return duelAlive end,
	SetAlive = function(_, subject, value) subject.Alive = value; return true end,
}
local duelBall = { Starts = 0, Stops = 0, Start = function(self) self.Starts += 1 end, Stop = function(self) self.Stops += 1 end, Update = function() end }
local duelCombat = { SetActive = function() end }
local duelOpponent = { Combatant = duelNPC, Clears = 0, Clear = function(self) self.Clears += 1 end, Update = function() end }
local spawnFolder = { GetChildren = function() return { { Name = "Spawn01" }, { Name = "Spawn02" } } end }
local gameplayStub = { WaitForChild = function(_, name) assert(name == "SpawnPoints"); return spawnFolder end }
local duel = DuelService.new(duelRegistry, duelCombat, duelBall, duelOpponent, gameplayStub)
local preparations = 0
duel._prepare = function(self) preparations += 1; self.State = "Starting"; self.Deadline = now + config.Round.Countdown; return true end
duel:Update(0.01)
check(duel.State == "Starting" and preparations == 1, "duel prepares one Player and one NPC")
now = duel.Deadline
duel:Update(0.01)
check(duel.State == "Playing" and duelBall.Starts == 1, "duel starts exactly one ball")
duelAlive = { duelPlayer }
duel:Update(0.01)
check(duel.State == "Ending" and duelBall.Stops >= 1, "elimination stops the ball deterministically")
now = duel.Deadline
duel:Update(0.01)
duel:Update(0.01)
check(duel.State == "Starting" and preparations == 2 and duelOpponent.Clears >= 1, "duel resets and re-enters without accumulated state")

print(string.format("PASS: %d V2 assertions", assertions))
