local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

roblox.implementMethod("Instance", "WaitForChild", function(instance, name)
	return instance:FindFirstChild(name)
end)

local assertions = 0
local function check(value, message)
	assert(value, message)
	assertions += 1
end

local function loadSource(path, environment)
	environment.Vector3 = environment.Vector3 or roblox.Vector3
	environment.CFrame = environment.CFrame or roblox.CFrame
	environment.Color3 = environment.Color3 or roblox.Color3
	environment.Enum = environment.Enum or roblox.Enum
	environment.Instance = environment.Instance or roblox.Instance
	return luau.load(fs.readFile(path), { environment = environment, debugName = path })()
end

local trajectory = loadSource("src/shared/Util/TrajectoryMath.luau", {})
local reflected = trajectory.Reflect(roblox.Vector3.new(1, 0, 0), roblox.Vector3.new(-1, 0, 0))
check(reflected:Dot(roblox.Vector3.new(-1, 0, 0)) > 0.999, "reflection follows surface normal")
local turned = trajectory.RotateTowards(roblox.Vector3.xAxis, roblox.Vector3.zAxis, 0.2)
check(math.abs(math.acos(turned:Dot(roblox.Vector3.xAxis)) - 0.2) < 1e-4, "turn interpolation respects angular limit")
check(math.abs(trajectory.SegmentSphereTime(roblox.Vector3.new(-20, 0, 0), roblox.Vector3.new(40, 0, 0), roblox.Vector3.zero, 2) - 0.45) < 1e-6, "swept collision detects high-speed crossing")
check(trajectory.SegmentSphereTime(roblox.Vector3.new(-20, 4, 0), roblox.Vector3.new(40, 0, 0), roblox.Vector3.zero, 2) == nil, "swept collision rejects miss")
local capsuleHit = trajectory.SweptSphereVsVerticalCapsuleTime(roblox.Vector3.new(-30, 0, 0), roblox.Vector3.new(60, 0, 0), roblox.Vector3.zero, 2.35, 5.8, 1.1)
check(capsuleHit ~= nil and capsuleHit > 0 and capsuleHit < 1, "swept ball detects R15 capsule continuously")
check(trajectory.SweptSphereVsVerticalCapsuleTime(roblox.Vector3.new(-30, 10, 0), roblox.Vector3.new(60, 0, 0), roblox.Vector3.zero, 2.35, 5.8, 1.1) == nil, "swept capsule rejects vertical miss")
check(trajectory.IsWithinArc(roblox.Vector3.xAxis, roblox.Vector3.zero, roblox.Vector3.new(10, 0, 0), 165), "front point is inside parry arc")
check(not trajectory.IsWithinArc(roblox.Vector3.xAxis, roblox.Vector3.zero, roblox.Vector3.new(-10, 0, 0), 165), "rear point is outside parry arc")
check(math.abs(trajectory.ClosingSpeed(roblox.Vector3.new(-20, 0, 0), roblox.Vector3.xAxis, 100, roblox.Vector3.zero, roblox.Vector3.zero) - 100) < 1e-6, "closing velocity projects relative velocity toward target")
check(trajectory.ClosingSpeed(roblox.Vector3.new(-20, 0, 0), roblox.Vector3.zAxis, 100, roblox.Vector3.zero, roblox.Vector3.zero) == 0, "lateral travel has zero closing velocity")
check(math.abs(trajectory.TimeToImpact(roblox.Vector3.new(-20, 0, 0), roblox.Vector3.xAxis, 10, roblox.Vector3.zero, roblox.Vector3.zero, 5) - 1.5) < 1e-6, "TTI uses distance to contact over closing velocity")
for _, speed in { 50, 100, 150, 200, 250, 300 } do
	local dt = 1 / 30
	local start = roblox.Vector3.new(-10, 0, 0)
	local detected = false
	for _ = 1, 30 do
		local delta = roblox.Vector3.xAxis * speed * dt
		if trajectory.SweptSphereVsVerticalCapsuleTime(start, delta, roblox.Vector3.zero, 2.35, 5.8, 1.1) then detected = true; break end
		start += delta
	end
	check(detected, "continuous hurt volume prevents tunneling at " .. speed .. " studs/s")
end
local fpsHitPositions = {}
for _, fps in { 30, 60, 120, 144 } do
	local dt = 1 / fps
	local position = roblox.Vector3.new(-20, 0, 0)
	for _ = 1, fps do
		local delta = roblox.Vector3.xAxis * 100 * dt
		local fraction = trajectory.SweptSphereVsVerticalCapsuleTime(position, delta, roblox.Vector3.zero, 2.35, 5.8, 1.1)
		if fraction then fpsHitPositions[fps] = (position + delta * fraction).X; break end
		position += delta
	end
	check(fpsHitPositions[fps] ~= nil, "sweep hits at " .. fps .. " FPS")
end
check(math.abs(fpsHitPositions[30] - fpsHitPositions[144]) < 1e-4, "continuous hit position is frame-rate invariant")

local combatConfig = loadSource("src/shared/Config/CombatConfig.luau", {})
check(combatConfig.Ball.Radius == 1.1 and combatConfig.Parry.Range > combatConfig.Ball.Radius * 10, "compact ball keeps an explicit forgiving defensive zone")
local speed0 = combatConfig.SpeedForRally(0)
local speed4 = combatConfig.SpeedForRally(4)
local speed12 = combatConfig.SpeedForRally(12)
local speed40 = combatConfig.SpeedForRally(40)
check(speed0 < speed4 and speed4 < speed12 and speed12 < speed40 and speed40 < combatConfig.Ball.MaxSpeed, "rally curve grows and tapers")
check(combatConfig.TurnRateForSpeed(combatConfig.Ball.MaxSpeed) < combatConfig.TurnRateForSpeed(combatConfig.Ball.BaseSpeed), "high-speed turn rate is lower")

local clientState = loadSource("src/client/ClientState.luau", {})
check(clientState.Round.State == "Waiting" and type(clientState.Round.Participants) == "table", "client round defaults are valid")
check(clientState.Ball.State == "Inactive" and clientState.Ball.TargetId == "" and clientState.Ball.Ball == false, "client ball defaults are valid")
check(clientState.Combat.Phase == "Idle" and clientState.Combat.ReadyAt == 0, "client combat defaults are valid")

local characterUtil = loadSource("src/shared/Util/CharacterUtil.luau", {})
local function r15(name)
	local model = roblox.Instance.new("Model")
	model.Name = name
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.RigType = roblox.Enum.HumanoidRigType.R15
	humanoid.Health = 100
	humanoid.Parent = model
	for _, partName in { "HumanoidRootPart", "UpperTorso", "RightHand" } do
		local part = roblox.Instance.new("Part")
		part.Name = partName
		part.Parent = model
	end
	return model
end
check(characterUtil.Resolve(r15("R15Contract")) ~= nil, "character helper resolves required R15 parts")

local replicatedToken = { Game = { Shared = { Util = { CharacterUtil = {} } } } }
local gameStub = { GetService = function(_, name) if name == "ReplicatedStorage" then return replicatedToken end; error(name) end }
local deathSignal = { Connect = function() return { Disconnect = function() end } end }
local fakeCharacter = { Name = "UnitNPC", Parent = true, GetAttribute = function(_, name) return if name == "CombatantId" then "N:test" else nil end }
local fakeHumanoid = { Health = 100, Died = deathSignal }
local fakeRoot = { Parent = true }
local characterStub = { Resolve = function(character)
	if character ~= fakeCharacter then return nil end
	return { Character = fakeCharacter, Humanoid = fakeHumanoid, RootPart = fakeRoot }
end }
local Combatants = loadSource("src/server/Combat/CombatantService.luau", {
	game = gameStub,
	Instance = { new = function(className)
		assert(className == "BindableEvent")
		return { Fire = function() end, Destroy = function() end }
	end },
	require = function(module) if module == replicatedToken.Game.Shared.Util.CharacterUtil then return characterStub end; error("unknown dependency") end,
})
local registry = Combatants.new()
local npc = registry:RegisterNPC(fakeCharacter)
check(npc.Kind == "NPC" and not registry:IsAlive(npc.Id), "NPC identity registers separately from round life")
check(registry:SetAlive(npc.Id, true, "prepare") and registry:IsAlive(npc.Id), "round preparation activates a bound NPC")
check(not pcall(function() registry:RegisterNPC(fakeCharacter) end), "duplicate NPC registration fails clearly")
check(registry:SetAlive(npc.Id, false, "unit") and not registry:IsAlive(npc.Id), "Combatant authority owns elimination")
check(not registry:SetAlive(npc.Id, false, "duplicate"), "double elimination is rejected")
check(registry:Unregister(npc.Id) and registry:Get(npc.Id) == nil, "Combatant unregister cleans registry")
fakeHumanoid.Health = 100
local lifecyclePlayer = { UserId = 99, Name = "LifecyclePlayer" }
local persistentPlayer = registry:RegisterPlayer(lifecyclePlayer)
check(not registry:IsAlive(persistentPlayer.Id) and registry:GetByPlayer(lifecyclePlayer) == persistentPlayer, "PlayerAdded creates one persistent inactive identity")
check(not pcall(function() registry:RegisterPlayer(lifecyclePlayer) end), "duplicate Player registration fails instead of hiding lifecycle bug")
registry:BindCharacter(persistentPlayer, fakeCharacter)
check(registry:SetAlive(persistentPlayer.Id, true, "round-one") and registry:IsAlive(persistentPlayer.Id), "round preparation binds and activates existing Player combatant")
check(registry:Unregister(persistentPlayer.Id), "PlayerRemoving unregisters persistent identity")

local combatTokens = { CombatConfig = {}, TrajectoryMath = {} }
local replicatedCombat = { Game = { Shared = { Config = { CombatConfig = combatTokens.CombatConfig }, Util = { TrajectoryMath = combatTokens.TrajectoryMath } } } }
local now = 20
local combatant = { Id = "P:7", Kind = "Player", Player = {}, Alive = true, RootPart = { Position = roblox.Vector3.zero, AssemblyLinearVelocity = roblox.Vector3.zero, CFrame = roblox.CFrame.lookAt(roblox.Vector3.zero, roblox.Vector3.xAxis) } }
local combatantsStub = {
	Get = function(_, id) return if id == combatant.Id then combatant else nil end,
	IsAlive = function(_, id) return id == combatant.Id and combatant.Alive end,
}
local redirects = 0
local ballStub = {
	IsTracking = function() return true end,
	GetTarget = function() return combatant end,
	GetRevision = function() return 4 end,
	GetPosition = function() return roblox.Vector3.new(8, 0, 0) end,
	GetSpeed = function() return 60 end,
	GetRallyCount = function() return redirects end,
	GetKinematics = function() return roblox.Vector3.new(8, 0, 0), roblox.Vector3.new(-1, 0, 0), 60 end,
	Redirect = function(_, _, revision) if revision ~= 4 or redirects > 0 then return false end; redirects += 1; return true end,
}
local effects = { Calls = 0, FireAllClients = function(self) self.Calls += 1 end, FireClient = function(self) self.Calls += 1 end }
local Combat = loadSource("src/server/Combat/CombatService.luau", {
	game = { GetService = function(_, name) if name == "ReplicatedStorage" then return replicatedCombat end; error(name) end },
	workspace = { GetServerTimeNow = function() return now end },
	require = function(module)
		if module == combatTokens.CombatConfig then return combatConfig end
		if module == combatTokens.TrajectoryMath then return trajectory end
		error("unknown combat dependency")
	end,
})
local combat = Combat.new(combatantsStub, effects)
combat:SetBall(ballStub)
combat:SetPlaying(true)
local immediateSuccess, immediateReason = combat:TryParry(combatant, { ClientTime = now, BallRevision = 4 })
check(immediateSuccess and immediateReason == "PARRIED", "valid in-range intent redirects immediately")
check(redirects == 1 and combat:GetParryPhase(combatant.Id, now) == "Recovery", "parry confirms atomically and enters recovery")
check(not combat:TryParry(combatant, { ClientTime = now, BallRevision = 4 }), "same revision cannot produce two parries")
now += combatConfig.Parry.Cooldown + 0.01
check(combat:GetParryPhase(combatant.Id, now) == "Idle", "parry state returns to Idle after cooldown")
check(not combat:TryParry(combatant, { ClientTime = now, BallRevision = 3 }), "stale observed ball revision is rejected")

local bufferedPosition = roblox.Vector3.new(combatConfig.Parry.Range + combatConfig.Ball.BaseSpeed * 0.1, 0, 0)
local bufferedRevision = 9
local bufferedRedirects = 0
local bufferedCombatant = { Id = "P:8", Kind = "Player", Player = {}, Alive = true, RootPart = combatant.RootPart }
local bufferedCombatants = {
	Get = function(_, id) return if id == bufferedCombatant.Id then bufferedCombatant else nil end,
	IsAlive = function(_, id) return id == bufferedCombatant.Id and bufferedCombatant.Alive end,
}
local bufferedBall = {
	IsTracking = function() return true end,
	GetTarget = function() return bufferedCombatant end,
	GetRevision = function() return bufferedRevision end,
	GetPosition = function() return bufferedPosition end,
	GetSpeed = function() return combatConfig.Ball.BaseSpeed end,
	GetRallyCount = function() return bufferedRedirects end,
	GetKinematics = function() return bufferedPosition, roblox.Vector3.new(-1, 0, 0), combatConfig.Ball.BaseSpeed end,
	Redirect = function(_, _, revision)
		if revision ~= bufferedRevision or bufferedRedirects > 0 then return false end
		bufferedRedirects += 1
		return true
	end,
}
local bufferedCombat = Combat.new(bufferedCombatants, effects)
bufferedCombat:SetBall(bufferedBall)
bufferedCombat:SetPlaying(true)
local armed, armedReason = bufferedCombat:TryParry(bufferedCombatant, { ClientTime = now, BallRevision = bufferedRevision })
check(armed and armedReason == "ARMED" and bufferedRedirects == 0, "slightly early intent arms a short server-authoritative buffer")
bufferedPosition = roblox.Vector3.new(combatConfig.Parry.Range - 0.1, 0, 0)
now += 0.1
check(bufferedCombat:TryConfirm(bufferedCombatant, now) and bufferedRedirects == 1, "buffer confirms as soon as the approaching ball enters defensive range")

local place = roblox.deserializePlace(fs.readFile("Fatal.rbxlx"))
local actualGame = place:GetService("ReplicatedStorage").Game
local ballConfigToken, mathToken = {}, {}
local ballReplicated = { Game = { Shared = { Config = { CombatConfig = ballConfigToken }, Util = { TrajectoryMath = mathToken } }, Assets = { FatalBall = actualGame.Assets.FatalBall } } }
local collectionStub = { AddTag = function() end }
local liveA = { Id = "P:a", RootPart = { Position = roblox.Vector3.new(-25, 7, 0), AssemblyLinearVelocity = roblox.Vector3.zero }, Alive = true }
local liveB = { Id = "N:b", RootPart = { Position = roblox.Vector3.new(25, 7, 0), AssemblyLinearVelocity = roblox.Vector3.zero }, Alive = true }
local aliveList = { liveA, liveB }
local ballCombatants = {
	GetAlive = function() return aliveList end,
	IsAlive = function(_, id) return id == liveA.Id or id == liveB.Id end,
	SetAlive = function() return true end,
}
local snapshots = {}
local Ball = loadSource("src/server/Combat/BallService.luau", {
	game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then return ballReplicated end
		if name == "CollectionService" then return collectionStub end
		error(name)
	end },
	workspace = { GetServerTimeNow = function() return now end, Spherecast = function() return nil end },
	RaycastParams = { new = function() return {} end },
	Random = { new = function() return { NextInteger = function() return 1 end } end },
	require = function(module) if module == ballConfigToken then return combatConfig elseif module == mathToken then return trajectory end; error("ball dependency") end,
})
local arena = place:GetService("Workspace").Game.Arena
local confirmationChecks = 0
local ballCombat = { TryConfirm = function() confirmationChecks += 1; return false end }
local snapshotRemote = { FireAllClients = function(_, payload) table.insert(snapshots, payload) end }
local effectRemote = { FireAllClients = function() end }
local ballService = Ball.new(ballCombatants, ballCombat, snapshotRemote, effectRemote, arena)
ballService:Start()
check(#ballService:_taggedBalls() == 1 and ballService._ball ~= nil, "round start creates exactly one authoritative ball")
ballService:Update(0.01)
check(confirmationChecks > 0, "ball simulation rechecks an armed parry before lethal contact")
check(not pcall(function() ballService:Spawn() end), "duplicate ball guard fails clearly")
local source = ballService:GetTarget()
check(ballService:Redirect(source, ballService:GetRevision()), "valid redirect succeeds")
check(ballService:GetTarget() ~= source and ballService:GetRallyCount() == 1 and ballService:GetSpeed() > combatConfig.Ball.BaseSpeed, "redirect selects another live target and advances rally")
check(not ballService:Redirect(source, ballService.LastParriedRevision), "same ball revision cannot redirect twice")
ballService:Stop()
check(#ballService:_taggedBalls() == 0 and snapshots[#snapshots].State == "Inactive", "ball cleanup leaves zero authoritative balls")

local roundConfig = loadSource("src/shared/Config/RoundConfig.luau", {})
check(roundConfig.CombatLab and roundConfig.StudioNPCCount == 1 and roundConfig.EndingDuration == 1.5, "Combat Lab config enforces one NPC and rapid reset")
local roundTokens = { Round = {}, Combat = {}, Character = {} }
local fakePlayer = { Name = "Tester" }
local playersStub = { GetPlayers = function() return { fakePlayer } end }
local runStub = { IsStudio = function() return true end }
local roundGame = { Game = { Shared = { Config = { RoundConfig = roundTokens.Round, CombatConfig = roundTokens.Combat }, Util = { CharacterUtil = roundTokens.Character } } } }
local Round = loadSource("src/server/Rounds/RoundService.luau", {
	game = { GetService = function(_, name)
		if name == "Players" then return playersStub elseif name == "RunService" then return runStub elseif name == "ReplicatedStorage" then return roundGame end
		error(name)
	end },
	workspace = { GetServerTimeNow = function() return now end },
	task = { spawn = function(callback) callback() end },
	require = function(module)
		if module == roundTokens.Round then return roundConfig elseif module == roundTokens.Combat then return combatConfig elseif module == roundTokens.Character then return characterUtil end
		error("round dependency")
	end,
})
local roundAlive = {
	{ Id = "P:7", RootPart = { Position = roblox.Vector3.zero } },
	{ Id = "N:1", RootPart = { Position = roblox.Vector3.zero } },
}
local roundBall = { Starts = 0, Stops = 0, Start = function(self) self.Starts += 1 end, Stop = function(self) self.Stops += 1 end, Update = function() end }
local roundCombat = { SetPlaying = function() end }
local roundCombatants = {
	GetAlive = function() return roundAlive end,
	Clear = function() end,
	AliveChanged = { Event = { Connect = function() return { Disconnect = function() end } end } },
}
local roundNPCs = { Clear = function() end, Update = function() end }
local roundRemote = { FireAllClients = function() end }
local rounds = Round.new({ Combatants = roundCombatants, Combat = roundCombat, Ball = roundBall, NPCs = roundNPCs, Weapons = {}, Remote = roundRemote, Arena = { Gameplay = { KillBounds = { Position = roblox.Vector3.new(0, -30, 0) } } } })
rounds._prepare = function() return true end
rounds._cleanup = function() rounds.Cleanups = (rounds.Cleanups or 0) + 1 end
rounds:Update(0.1)
check(rounds.State == "Starting", "Combat Lab prepares directly into short start")
now = rounds.Deadline; rounds:Update(0.1)
check(rounds.State == "Playing" and roundBall.Starts == 1, "countdown spawns one ball and starts play")
roundAlive = { roundAlive[1] }; rounds:Update(0.1)
check(rounds.State == "Ending" and roundBall.Stops >= 1 and rounds.WinnerId == "P:7" and rounds.WinnerName == "P:7", "last alive wins and ball stops immediately")
now = rounds.Deadline; rounds:Update(0.1)
check(rounds.State == "Starting" and rounds.Cleanups == 1, "Combat Lab reset cleans and immediately prepares next attempt")
roundAlive = {
	{ Id = "P:7", RootPart = { Position = roblox.Vector3.zero } },
	{ Id = "N:2", RootPart = { Position = roblox.Vector3.zero } },
}; now = rounds.Deadline; rounds:Update(0.1)
check(rounds.State == "Playing" and roundBall.Starts == 2, "second round starts without accumulated state")

print(string.format("PASS: %d static assertions", assertions))
