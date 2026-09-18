local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local CombatCore = {}
CombatCore.__index = CombatCore

function CombatCore.new(registry, combatEvent)
	return setmetatable({ Registry = registry, Event = combatEvent, Ball = nil, Active = false, ReadyAt = {} }, CombatCore)
end

function CombatCore:SetBall(ball) assert(not self.Ball, "ball already assigned"); self.Ball = ball end
function CombatCore:SetActive(active) self.Active = active; if not active then table.clear(self.ReadyAt) end end

function CombatCore:_result(actor, accepted, reason, distance, approach)
	if Config.CombatDebug then
		print(string.format("[V2/PARRY] actor=%s result=%s reason=%s distance=%.2f approach=%.2f revision=%d",
			actor and actor.Id or "none", accepted and "ACCEPT" or "REJECT", reason, distance or -1, approach or -1,
			self.Ball and self.Ball:GetRevision() or -1))
	end
	return accepted, reason
end

function CombatCore:TryParry(actor)
	if not self.Active or not self.Ball or not self.Ball:IsTracking() then return self:_result(actor, false, "INACTIVE") end
	if not self.Registry:IsAlive(actor) then return self:_result(actor, false, "DEAD") end
	if self.Ball:GetTarget() ~= actor then return self:_result(actor, false, "NOT_TARGET") end
	local now = workspace:GetServerTimeNow()
	if now < (self.ReadyAt[actor.Id] or 0) then return self:_result(actor, false, "COOLDOWN") end
	self.ReadyAt[actor.Id] = now + Config.Parry.Cooldown
	local position, velocity = self.Ball:GetKinematics()
	local center = actor.CenterPart.Position
	local offset = center - position
	local distance = offset.Magnitude
	local approach = if distance < 1e-6 then velocity.Magnitude else velocity:Dot(offset.Unit)
	if approach <= Config.Parry.ApproachEpsilon then return self:_result(actor, false, "NOT_APPROACHING", distance, approach) end
	if distance > Config.Parry.DefensiveRadius then return self:_result(actor, false, "OUT_OF_RANGE", distance, approach) end
	if not self.Ball:Redirect(actor) then return self:_result(actor, false, "REDIRECT_REJECTED", distance, approach) end
	self.Event:FireAllClients({ Kind = "Parry", ActorId = actor.Id, Position = position, Rally = self.Ball:GetRally() })
	return self:_result(actor, true, "PARRIED", distance, approach)
end

return CombatCore
