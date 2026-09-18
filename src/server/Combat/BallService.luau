local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local BallService = {}
BallService.__index = BallService

function BallService.new(combatants, combat, snapshotRemote, effectRemote, arena)
	local gameplay = arena:WaitForChild("Gameplay", 10)
	assert(gameplay and gameplay:IsA("Folder"), "FATAL arena missing Gameplay")
	local walls = gameplay:WaitForChild("Walls", 10)
	assert(walls and walls:IsA("Folder"), "FATAL arena missing Gameplay.Walls")
	local cast = RaycastParams.new()
	cast.FilterType = Enum.RaycastFilterType.Include
	cast.FilterDescendantsInstances = { walls }
	cast.RespectCanCollide = true
	return setmetatable({
		Combatants = combatants,
		Combat = combat,
		SnapshotRemote = snapshotRemote,
		EffectRemote = effectRemote,
		Gameplay = gameplay,
		CastParams = cast,
		Random = Random.new(),
		_ball = nil,
		State = "Inactive",
		Position = Vector3.zero,
		CurrentDirection = Vector3.zAxis,
		DesiredDirection = Vector3.zAxis,
		Speed = Config.Ball.BaseSpeed,
		CurrentTarget = nil,
		RallyCount = 0,
		Revision = 0,
		LastParriedRevision = -1,
		SnapshotClock = 0,
		AuditClock = 0,
	}, BallService)
end

function BallService:_taggedBalls()
	local found = {}
	for _, descendant in self.Gameplay:GetChildren() do
		if descendant:GetAttribute("FatalAuthoritativeBall") then table.insert(found, descendant) end
	end
	return found
end

function BallService:_assertBallCount(expected)
	local count = #self:_taggedBalls()
	assert(count == expected, string.format("FATAL authoritative ball invariant failed: expected %d, found %d", expected, count))
end

function BallService:_pickTarget(excludedId)
	local candidates = {}
	for _, combatant in self.Combatants:GetAlive() do
		if combatant.Id ~= excludedId then table.insert(candidates, combatant) end
	end
	if #candidates == 0 and excludedId then
		for _, combatant in self.Combatants:GetAlive() do table.insert(candidates, combatant) end
	end
	if #candidates == 0 then return nil end
	return candidates[1]
end

function BallService:_setTarget(combatant)
	self.CurrentTarget = combatant
	self.Revision += 1
	if Config.DebugCombat then print("[Fatal/Ball] target", combatant and combatant.Id or "none", "revision", self.Revision) end
end

function BallService:Spawn()
	assert(self._ball == nil, "FATAL attempted to spawn a second service-owned ball")
	self:_assertBallCount(0)
	local ball = ReplicatedStorage.Game.Assets.FatalBall:Clone()
	ball.Name = "FatalBall"
	ball:SetAttribute("FatalAuthoritativeBall", true)
	ball.CFrame = CFrame.new(self.Position)
	ball.Parent = self.Gameplay
	CollectionService:AddTag(ball, "BallCollision")
	self._ball = ball
	self:_assertBallCount(1)
	if Config.DebugCombat then print("[Fatal/Ball] spawn") end
	return ball
end

function BallService:Start()
	assert(self.State == "Inactive", "ball already active")
	local target = self:_pickTarget(nil)
	assert(target, "cannot start ball without a live combatant")
	self.Position = Vector3.new(0, Config.Ball.SpawnHeight, 0)
	self.CurrentDirection = (target.RootPart.Position - self.Position).Unit
	self.DesiredDirection = self.CurrentDirection
	self.Speed = Config.Ball.BaseSpeed
	self.RallyCount = 0
	self.LastParriedRevision = -1
	self.State = "Tracking"
	self:_setTarget(target)
	self:Spawn()
	self:Publish()
end

function BallService:Stop()
	self.State = "Inactive"
	self.CurrentTarget = nil
	self.Revision += 1
	if self._ball then self._ball:Destroy(); self._ball = nil end
	self:_assertBallCount(0)
	self:Publish()
	if Config.DebugCombat then print("[Fatal/Ball] cleanup") end
end

function BallService:IsTracking() return self.State == "Tracking" and self._ball ~= nil end
function BallService:GetTarget() return self.CurrentTarget end
function BallService:GetRevision() return self.Revision end
function BallService:GetPosition() return self.Position end
function BallService:GetSpeed() return self.Speed end
function BallService:GetRallyCount() return self.RallyCount end
function BallService:GetKinematics() return self.Position, self.CurrentDirection, self.Speed end

function BallService:Redirect(source, expectedRevision)
	if not self:IsTracking() or self.CurrentTarget ~= source then return false end
	if self.Revision ~= expectedRevision or self.LastParriedRevision == expectedRevision then return false end
	local nextTarget = self:_pickTarget(source.Id)
	if not nextTarget then return false end
	self.LastParriedRevision = expectedRevision
	self.RallyCount += 1
	self.Speed = Config.SpeedForRally(self.RallyCount)
	local rebound = -self.CurrentDirection
	local aimed = (nextTarget.RootPart.Position - self.Position).Unit
	self.CurrentDirection = aimed:Lerp(rebound, Config.Ball.RedirectMomentumRetention).Unit
	self.DesiredDirection = aimed
	self:_setTarget(nextTarget)
	return true
end

function BallService:_contactTarget(segment, wallFraction, now)
	local target = self.CurrentTarget
	if not target or not self.Combatants:IsAlive(target.Id) then return false end
	local fraction, closestDistance = TrajectoryMath.SweptSphereVsVerticalCapsuleTime(
		self.Position,
		segment,
		target.RootPart.Position,
		Config.HurtVolume.PlayerHitRadius,
		Config.HurtVolume.PlayerHitHeight,
		Config.Ball.Radius
	)
	if not fraction or fraction > wallFraction then return false end
	self.Position += segment * fraction
	if self.Combat:TryConfirm(target, now) then return true end
	if self.Combatants:SetAlive(target.Id, false, "BallHit") then
		if Config.DebugCombat or Config.CombatDebug then
			print(string.format("[HIT] target=%s speed=%.2f rally=%d closestDistance=%.3f revision=%d", target.Id, self.Speed, self.RallyCount, closestDistance or -1, self.Revision))
		end
		self.EffectRemote:FireAllClients({ Kind = "Elimination", CombatantId = target.Id, Position = self.Position, RallyCount = self.RallyCount })
	end
	self.CurrentTarget = nil
	self.State = "Resolved"
	self.Revision += 1
	return true
end

function BallService:_move(distance, now)
	local remaining = distance
	for _ = 1, Config.Ball.MaxCollisionsPerStep do
		if remaining <= 1e-4 or not self:IsTracking() then return end
		local segment = self.CurrentDirection * remaining
		local wall = workspace:Spherecast(self.Position, Config.Ball.Radius, segment, self.CastParams)
		local wallFraction = if wall then math.clamp(wall.Distance / remaining, 0, 1) else 1
		if self:_contactTarget(segment, wallFraction, now) then return end
		if not wall then self.Position += segment; return end
		local travelled = math.max(0, wall.Distance - Config.Ball.SurfaceOffset)
		self.Position += self.CurrentDirection * travelled
		self.CurrentDirection = TrajectoryMath.Reflect(self.CurrentDirection, wall.Normal)
		self.Position += self.CurrentDirection * Config.Ball.SurfaceOffset
		remaining = math.max(0, remaining - wall.Distance)
		self.EffectRemote:FireAllClients({ Kind = "WallBounce", Position = self.Position, Normal = wall.Normal, RallyCount = self.RallyCount })
	end
end

function BallService:Publish()
	local target = self.CurrentTarget
	self.SnapshotRemote:FireAllClients({
		State = self.State,
		Ball = self._ball or false,
		Position = self.Position,
		CurrentDirection = self.CurrentDirection,
		DesiredDirection = self.DesiredDirection,
		Speed = self.Speed,
		TargetId = target and target.Id or "",
		TargetCharacter = target and target.Character or false,
		RallyCount = self.RallyCount,
		Revision = self.Revision,
		ServerTime = workspace:GetServerTimeNow(),
	})
end

function BallService:Update(dt)
	if not self:IsTracking() then return end
	local now = workspace:GetServerTimeNow()
	if not self.CurrentTarget or not self.Combatants:IsAlive(self.CurrentTarget.Id) then self:_setTarget(self:_pickTarget(nil)) end
	if not self.CurrentTarget then self:Stop(); return end
	local boundedDt = math.min(dt, Config.Ball.MaxDeltaTime)
	local substeps = math.clamp(math.ceil(self.Speed * boundedDt / Config.Ball.MaxTravelPerSubstep), 1, Config.Ball.MaxSubsteps)
	local stepDt = boundedDt / substeps
	for _ = 1, substeps do
		if not self:IsTracking() or not self.CurrentTarget then break end
		local targetRoot = self.CurrentTarget.RootPart
		local distance = (targetRoot.Position - self.Position).Magnitude
		local leadTime = math.min(Config.Ball.MaxTargetLeadTime, distance / math.max(self.Speed, 1) * Config.Ball.TargetLeadScale)
		local predictedTarget = targetRoot.Position + targetRoot.AssemblyLinearVelocity * leadTime
		self.DesiredDirection = (predictedTarget - self.Position).Unit
		self.CurrentDirection = TrajectoryMath.RotateTowards(self.CurrentDirection, self.DesiredDirection, Config.TurnRateForSpeed(self.Speed) * stepDt)
		self:_move(self.Speed * stepDt, now)
	end
	if self._ball then self._ball.CFrame = CFrame.new(self.Position) end
	if not self:IsTracking() then return end
	self.SnapshotClock += dt
	if self.SnapshotClock >= Config.Ball.SnapshotInterval then self.SnapshotClock = 0; self:Publish() end
	self.AuditClock += dt
	if self.AuditClock >= 0.5 then self.AuditClock = 0; self:_assertBallCount(1) end
end

return BallService
