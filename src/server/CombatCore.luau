local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Game.Shared.Combat.CombatTypes)

local CombatCore = {}
CombatCore.__index = CombatCore

function CombatCore.new(registry, combatEvent)
	return setmetatable({ Registry = registry, Event = combatEvent, Ball = nil, Active = false, ReadyAt = {}, Pending = {} }, CombatCore)
end

function CombatCore:SetBall(ball) assert(not self.Ball, "ball already assigned"); self.Ball = ball end
function CombatCore:SetActive(active)
	self.Active = active
	if not active then table.clear(self.ReadyAt); table.clear(self.Pending) end
end

function CombatCore:_metrics(actor)
	local position, velocity = self.Ball:GetKinematics()
	local offset = actor.CenterPart.Position - position
	local distance = offset.Magnitude
	local approach = if distance < 1e-6 then velocity.Magnitude else velocity:Dot(offset.Unit)
	local contactDistance = Config.Hurt.BodyRadius + Config.Ball.Radius
	local contactMs = if approach > Config.Parry.ApproachEpsilon then math.max(0, distance - contactDistance) / approach * 1000 else math.huge
	return { Position = position, Speed = velocity.Magnitude, Distance = distance, Approach = approach, ContactMs = contactMs }
end

function CombatCore:_result(actor, accepted, reason, metrics, mode)
	if Config.Telemetry.Enabled then
		print(string.format("[COMBAT] state=Active actor=%s rally=%d result=%s reason=%s mode=%s distance=%.2f speed=%.2f hurtMs=%s revision=%d",
			actor and actor.Id or "none", self.Ball and self.Ball:GetRally() or -1,
			accepted and "ACCEPT" or "REJECT", reason, mode or "INPUT",
			metrics and metrics.Distance or -1, metrics and metrics.Speed or -1,
			metrics and metrics.ContactMs < math.huge and string.format("%.0f", metrics.ContactMs) or "INF",
			self.Ball and self.Ball:GetRevision() or -1))
	end
	return accepted, reason
end

local function validatedAim(value)
	if typeof(value) ~= "Vector3" or value.Magnitude < 1e-4 then return nil end
	if value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z then return nil end
	if math.abs(value.X) == math.huge or math.abs(value.Y) == math.huge or math.abs(value.Z) == math.huge then return nil end
	return value.Unit
end

function CombatCore:_redirect(actor, metrics, mode, now, aimDirection)
	if now < (self.ReadyAt[actor.Id] or 0) then return self:_result(actor, false, "COOLDOWN", metrics, mode) end
	if not self.Ball:Redirect(actor, validatedAim(aimDirection)) then return self:_result(actor, false, "REDIRECT_REJECTED", metrics, mode) end
	self.ReadyAt[actor.Id] = now + Config.Parry.Cooldown
	self.Pending[actor.Id] = nil
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.ParryConfirmed, {
		ActorId = actor.Id, Position = metrics.Position,
		Rally = self.Ball:GetRally(), Mode = mode,
	}))
	return self:_result(actor, true, "PARRIED", metrics, mode)
end

function CombatCore:TryParry(actor, aimDirection)
	if not self.Active or not self.Ball or not self.Ball:IsTracking() then return self:_result(actor, false, "INACTIVE") end
	if not self.Registry:IsAlive(actor) then return self:_result(actor, false, "DEAD") end
	if self.Ball:GetTarget() ~= actor then return self:_result(actor, false, "NOT_TARGET") end
	local now = workspace:GetServerTimeNow()
	local metrics = self:_metrics(actor)
	if metrics.Approach <= Config.Parry.ApproachEpsilon then return self:_result(actor, false, "NOT_APPROACHING", metrics) end
	if metrics.Distance <= Config.Parry.DefensiveRadius then return self:_redirect(actor, metrics, "IMMEDIATE", now, aimDirection) end
	if actor.Kind ~= "Player" then return self:_result(actor, false, "OUT_OF_RANGE", metrics) end
	local pending = self.Pending[actor.Id]
	if pending and now <= pending.ExpiresAt then return self:_result(actor, false, "PENDING", metrics) end
	local secondsToRange = (metrics.Distance - Config.Parry.DefensiveRadius) / metrics.Approach
	if secondsToRange > Config.Parry.EarlyBuffer then return self:_result(actor, false, "OUT_OF_RANGE", metrics) end
	self.Pending[actor.Id] = { Actor = actor, AimDirection = validatedAim(aimDirection), ExpiresAt = now + Config.Parry.EarlyBuffer, Revision = self.Ball:GetRevision() }
	return self:_result(actor, true, "BUFFERED", metrics, "PENDING")
end

function CombatCore:UpdatePending()
	if not self.Active or not self.Ball or not self.Ball:IsTracking() then table.clear(self.Pending); return end
	local now = workspace:GetServerTimeNow()
	for id, pending in self.Pending do
		local actor = pending.Actor
		if now > pending.ExpiresAt then
			self.Pending[id] = nil
			self:_result(actor, false, "BUFFER_EXPIRED", self:_metrics(actor), "BUFFERED")
		elseif not self.Registry:IsAlive(actor) or self.Ball:GetTarget() ~= actor or self.Ball:GetRevision() ~= pending.Revision then
			self.Pending[id] = nil
		else
			local metrics = self:_metrics(actor)
			if metrics.Approach <= Config.Parry.ApproachEpsilon then
				self.Pending[id] = nil
			elseif metrics.Distance <= Config.Parry.DefensiveRadius then
				self:_redirect(actor, metrics, "BUFFERED", now, pending.AimDirection)
			end
		end
	end
end

return CombatCore
