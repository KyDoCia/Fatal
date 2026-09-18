local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local NPCConfig = require(ReplicatedStorage.Game.Shared.Config.NPCConfig)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local NPCCombatController = {}
NPCCombatController.__index = NPCCombatController

function NPCCombatController.new(combatant, combat, ball, floor, random)
	return setmetatable({
		Combatant = combatant,
		Combat = combat,
		Ball = ball,
		Floor = floor,
		Random = random,
		TargetRevision = -1,
		PlannedAt = math.huge,
		Attempted = false,
		NextMoveAt = 0,
	}, NPCCombatController)
end

function NPCCombatController:_plan(now)
	local position, direction, speed = self.Ball:GetKinematics()
	local root = self.Combatant.RootPart
	local tti = TrajectoryMath.TimeToImpact(position, direction, speed, root.Position, root.AssemblyLinearVelocity, CombatConfig.Parry.Range)
	local tuning = NPCConfig.Normal
	local reaction = self.Random:NextNumber(tuning.ReactionTimeMin, tuning.ReactionTimeMax)
	local variance = self.Random:NextNumber(-tuning.TimingVariance, tuning.TimingVariance)
	local deliberateMiss = self.Random:NextNumber() < tuning.MistakeChance
	self.PlannedAt = now + math.max(reaction, tti + variance)
	if deliberateMiss then self.PlannedAt += CombatConfig.Parry.ActiveWindow + CombatConfig.Parry.Recovery end
	self.Attempted = false
end

function NPCCombatController:_move(now)
	if now < self.NextMoveAt then return end
	self.NextMoveAt = now + NPCConfig.Normal.MovementInterval
	local halfX = self.Floor.Size.X * 0.5 - 10
	local halfZ = self.Floor.Size.Z * 0.5 - 10
	local origin = self.Combatant.RootPart.Position
	local offset = Vector3.new(
		self.Random:NextNumber(-NPCConfig.Normal.MovementRadius, NPCConfig.Normal.MovementRadius),
		0,
		self.Random:NextNumber(-NPCConfig.Normal.MovementRadius, NPCConfig.Normal.MovementRadius)
	)
	local destination = origin + offset
	destination = Vector3.new(math.clamp(destination.X, -halfX, halfX), self.Floor.Position.Y + 3, math.clamp(destination.Z, -halfZ, halfZ))
	self.Combatant.Humanoid:MoveTo(destination)
end

function NPCCombatController:Update(now)
	if not self.Combatant.Alive then return end
	self:_move(now)
	if self.Ball:GetTarget() ~= self.Combatant then
		self.TargetRevision = -1
		self.PlannedAt = math.huge
		self.Attempted = false
		return
	end
	local revision = self.Ball:GetRevision()
	local ballPosition = self.Ball:GetPosition()
	local rootPosition = self.Combatant.RootPart.Position
	local flatBall = Vector3.new(ballPosition.X, rootPosition.Y, ballPosition.Z)
	if (flatBall - rootPosition).Magnitude > 0.1 then self.Combatant.RootPart.CFrame = CFrame.lookAt(rootPosition, flatBall) end
	if revision ~= self.TargetRevision then
		self.TargetRevision = revision
		self:_plan(now)
	end
	if not self.Attempted and now >= self.PlannedAt then
		self.Attempted = true
		self.Combat:TryParry(self.Combatant, { ClientTime = now, BallRevision = revision })
	end
end

return NPCCombatController
