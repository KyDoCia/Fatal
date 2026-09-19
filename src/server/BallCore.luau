local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)
local CombatTypes = require(ReplicatedStorage.Game.Shared.Combat.CombatTypes)
local BallDefinitions = require(ReplicatedStorage.Game.Shared.Balls.BallDefinitions)

local BallCore = {}
BallCore.__index = BallCore

function BallCore.new(registry, snapshotRemote, combatEvent, gameplay, targetSelector)
	return setmetatable({
		Registry = registry, Snapshot = snapshotRemote, Event = combatEvent, Gameplay = gameplay,
		Part = nil, State = "Inactive", Position = Vector3.zero, Velocity = Vector3.zero,
		TargetSelector = targetSelector, Definition = BallDefinitions.StandardBall,
		Target = nil, Rally = 0, Revision = 0, SnapshotClock = 0,
	}, BallCore)
end

function BallCore:_ownedBalls()
	local found = {}
	for _, child in self.Gameplay:GetChildren() do if child:GetAttribute("FatalV2Ball") then table.insert(found, child) end end
	return found
end

function BallCore:_assertCount(expected)
	assert(#self:_ownedBalls() == expected, string.format("V2 ball invariant: expected %d", expected))
end

function BallCore:SelectTargetAfter(source)
	if self.TargetSelector then return self.TargetSelector.Select(self.Registry, source) end
	for _, combatant in self.Registry:GetAlive() do if combatant ~= source then return combatant end end
end

function BallCore:_launchDirection(target)
	local desired = (target.CenterPart.Position - self.Position).Unit
	local lateral = Vector3.yAxis:Cross(desired)
	if lateral.Magnitude < 1e-4 then lateral = Vector3.xAxis else lateral = lateral.Unit end
	local sign = if self.Revision % 2 == 0 then 1 else -1
	return (desired + lateral * Config.Ball.CurveDeflection * sign).Unit
end

function BallCore:Start(preferredTarget)
	assert(self.State == "Inactive" and not self.Part, "ball already active")
	self:_assertCount(0)
	local target = preferredTarget or self.Registry:GetAlive()[1]
	assert(target, "ball requires target")
	local source = self:SelectTargetAfter(target)
	if source then
		local launchDirection = (target.CenterPart.Position - source.CenterPart.Position).Unit
		self.Position = source.CenterPart.Position + launchDirection * Config.Ball.LaunchOffset
	else
		self.Position = target.CenterPart.Position + Vector3.new(0, 0, Config.Parry.DefensiveRadius + 1)
	end
	self.Target = target
	self.Rally = 0
	self.Revision += 1
	self.Velocity = self:_launchDirection(target) * Config.Ball.BaseSpeed
	local part = ReplicatedStorage.Game.Assets[self.Definition.AssetName]:Clone()
	part.Name = "CombatBallV2"
	part.Size = Vector3.one * Config.Ball.Radius * 2
	part.CFrame = CFrame.new(self.Position)
	part:SetAttribute("FatalV2Ball", true)
	part.Parent = self.Gameplay
	self.Part = part
	self.State = "Tracking"
	self:_assertCount(1)
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.BallTargetChanged, { TargetId = target.Id, Revision = self.Revision }))
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.RallyChanged, { Rally = 0 }))
	self:Publish()
end

function BallCore:Stop()
	local hadTarget = self.Target ~= nil
	self.State = "Inactive"
	self.Target = nil
	self.Velocity = Vector3.zero
	self.Revision += 1
	if self.Part then self.Part:Destroy(); self.Part = nil end
	self:_assertCount(0)
	if hadTarget then self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.BallTargetChanged, { TargetId = "", Revision = self.Revision })) end
	self:Publish()
end

function BallCore:IsTracking() return self.State == "Tracking" and self.Part ~= nil end
function BallCore:GetTarget() return self.Target end
function BallCore:GetRevision() return self.Revision end
function BallCore:GetRally() return self.Rally end
function BallCore:GetKinematics() return self.Position, self.Velocity end

function BallCore:Redirect(source)
	if not self:IsTracking() or self.Target ~= source then return false end
	local target = self:SelectTargetAfter(source)
	if not target then return false end
	self.Rally += 1
	self.Revision += 1
	self.Target = target
	local speed = Config.SpeedForRally(self.Rally)
	self.Velocity = self:_launchDirection(target) * speed
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.BallTargetChanged, { TargetId = target.Id, Revision = self.Revision }))
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.RallyChanged, { Rally = self.Rally }))
	self:Publish()
	return true
end

function BallCore:_hit(segment)
	local target = self.Target
	if not self.Registry:IsAlive(target) then return false end
	local fraction = TrajectoryMath.SweptSphereVsVerticalCapsuleTime(
		self.Position, segment, target.RootPart.Position,
		Config.Hurt.BodyRadius, Config.Hurt.BodyHeight, Config.Ball.Radius
	)
	if not fraction then return false end
	self.Position += segment * fraction
	self.Registry:SetAlive(target, false)
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.CombatantHit, {
		TargetId = target.Id, Position = self.Position, Rally = self.Rally,
	}))
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.CombatantEliminated, {
		CombatantId = target.Id, Rally = self.Rally,
	}))
	if Config.Telemetry.Enabled then
		print(string.format("[COMBAT] state=Active result=HIT target=%s rally=%d speed=%.2f", target.Id, self.Rally, self.Velocity.Magnitude))
	end
	self.State = "Resolved"
	self.Target = nil
	self.Revision += 1
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.BallTargetChanged, { TargetId = "", Revision = self.Revision }))
	self:Publish()
	return true
end

function BallCore:Update(dt, beforeStep)
	if not self:IsTracking() then return end
	if not self.Registry:IsAlive(self.Target) then
		local target = self:SelectTargetAfter(nil)
		if not target then self.State = "Resolved"; self.Target = nil; return end
		self.Target = target
		self.Revision += 1
		self.Velocity = (target.CenterPart.Position - self.Position).Unit * Config.SpeedForRally(self.Rally)
		self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.BallTargetChanged, { TargetId = target.Id, Revision = self.Revision }))
	end
	local bounded = math.min(dt, Config.Ball.MaxDeltaTime)
	local steps = math.max(1, math.ceil(self.Velocity.Magnitude * bounded / Config.Ball.MaxTravelPerStep))
	local stepDt = bounded / steps
	for _ = 1, steps do
		if not self:IsTracking() or not self.Target then break end
		if beforeStep then beforeStep() end
		if not self:IsTracking() or not self.Target then break end
		local desired = (self.Target.CenterPart.Position - self.Position).Unit
		local direction = TrajectoryMath.RotateTowards(self.Velocity.Unit, desired, Config.Ball.HomingRate * stepDt)
		self.Velocity = direction * Config.SpeedForRally(self.Rally)
		local segment = self.Velocity * stepDt
		if self:_hit(segment) then break end
		self.Position += segment
	end
	if self.Part then self.Part.CFrame = CFrame.new(self.Position) end
	self.SnapshotClock += dt
	if self.SnapshotClock >= Config.Ball.SnapshotInterval then self.SnapshotClock = 0; self:Publish() end
end

function BallCore:Publish()
	self.Snapshot:FireAllClients({
		State = self.State, Ball = self.Part or false, Position = self.Position, Velocity = self.Velocity,
		TargetId = self.Target and self.Target.Id or "", Rally = self.Rally, Revision = self.Revision,
	})
end

return BallCore
