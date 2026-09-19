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
local combatTypes = load("src/shared/Combat/CombatTypes.luau", {})
local ballDefinitions = load("src/shared/Balls/BallDefinitions.luau", {})
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

local configToken, mathToken, typesToken = {}, {}, {}
local replicated = { Game = { Shared = { Config = { CombatConfig = configToken }, Combat = { CombatTypes = typesToken }, Util = { TrajectoryMath = mathToken } } } }
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
	GetAlive = function() return alive end,
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
check(ballCore.Velocity.Unit:Dot(directOpening) < 0.999, "authoritative launch begins with a deterministic readable curve")
local launchDistance = (ballCore.Position - first.CenterPart.Position).Magnitude
local actualSeparation = (first.CenterPart.Position - second.CenterPart.Position).Magnitude
check(math.abs(launchDistance - (actualSeparation - config.Ball.LaunchOffset)) < 1e-4 and math.abs((launchDistance - config.Parry.DefensiveRadius) / ballCore.Velocity.Magnitude - config.FirstApproachSeconds(actualSeparation)) < 1e-4, "actual first launch matches geometry-derived approach timing")
local stepObservations = 0
ballCore:Update(0.1, function() stepObservations += 1 end)
check(stepObservations >= 2, "ball exposes every bounded movement step to the deterministic NPC decision")
check(ballCore:Redirect(first) and ballCore:GetTarget() == second and ballCore:GetRally() == 1, "redirect changes target and increments rally immediately")
ballCore:Stop()
check(#ballCore:_ownedBalls() == 0, "V2 ball cleanup leaves no authoritative instance")

local rallyEvents = {}
local rallyRemote = { FireAllClients = function(_, payload) table.insert(rallyEvents, payload) end }
local rallyBall = BallCore.new(ballRegistry, remote, rallyRemote, gameplay)
rallyBall:Start(first)
for expected = 1, 130 do
	check(rallyBall:Redirect(rallyBall:GetTarget()) and rallyBall:GetRally() == expected, "long rally increments exactly once at exchange " .. expected)
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
