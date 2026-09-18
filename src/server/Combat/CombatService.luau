local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local CombatService = {}
CombatService.__index = CombatService

function CombatService.new(combatants, effectRemote)
	return setmetatable({ Combatants = combatants, EffectRemote = effectRemote, Ball = nil, Playing = false, ParryStates = {} }, CombatService)
end

function CombatService:SetBall(ball) assert(self.Ball == nil, "CombatService ball already assigned"); self.Ball = ball end
function CombatService:SetPlaying(playing) self.Playing = playing; if not playing then table.clear(self.ParryStates) end end

function CombatService:_state(id)
	local state = self.ParryStates[id]
	if not state then
		state = {
			Phase = "Idle",
			ActiveUntil = 0,
			RecoveryUntil = 0,
			ReadyAt = 0,
			ArmedRevision = -1,
			ServerReceiveTime = 0,
			ClientReportedTime = 0,
			LatencyCompensation = 0,
		}
		self.ParryStates[id] = state
	end
	return state
end

function CombatService:_advancePhase(state, now)
	if state.Phase == "Active" and now > state.ActiveUntil then state.Phase = "Recovery"; state.RecoveryUntil = state.ActiveUntil + Config.Parry.Recovery end
	if state.Phase == "Recovery" and now >= state.RecoveryUntil then state.Phase = "Cooldown" end
	if state.Phase == "Cooldown" and now >= state.ReadyAt then state.Phase = "Idle" end
end

function CombatService:GetParryPhase(id, now)
	local state = self:_state(id)
	self:_advancePhase(state, now or workspace:GetServerTimeNow())
	return state.Phase
end

function CombatService:_metrics(combatant)
	local position, direction, speed = self.Ball:GetKinematics()
	local root = combatant.RootPart
	local distance = (position - root.Position).Magnitude
	local closing = TrajectoryMath.ClosingSpeed(position, direction, speed, root.Position, root.AssemblyLinearVelocity)
	local tti = TrajectoryMath.TimeToImpact(position, direction, speed, root.Position, root.AssemblyLinearVelocity, Config.Ball.Radius + Config.HurtVolume.PlayerHitRadius)
	local inArc, arcDot = TrajectoryMath.IsWithinArc(root.CFrame.LookVector, root.Position, position, Config.Parry.ArcDegrees)
	return { Distance = distance, Closing = closing, TTI = tti, InArc = inArc, ArcDot = arcDot }
end

function CombatService:_log(combatant, accepted, reason, metrics, revision)
	if not (Config.DebugCombat or Config.CombatDebug) then return end
	local state = combatant and self.ParryStates[combatant.Id]
	local phase = state and state.Phase or "Idle"
	print(string.format("[PARRY] actor=%s result=%s reason=%s distance=%.2f tti=%s closing=%.2f revision=%d phase=%s",
		combatant and combatant.Kind or "Unknown", accepted and "ACCEPT" or "REJECT", reason,
		metrics and metrics.Distance or -1, metrics and metrics.TTI < math.huge and string.format("%.3f", metrics.TTI) or "INF",
		metrics and metrics.Closing or -1, revision or -1, phase))
end

function CombatService:_reject(combatant, reason, metrics, revision)
	self:_log(combatant, false, reason, metrics, revision)
	return false, reason
end

function CombatService:_endAttempt(state, now)
	state.Phase = "Recovery"
	state.RecoveryUntil = now + Config.Parry.Recovery
	state.ReadyAt = math.max(state.ReadyAt, now + Config.Parry.Recovery)
end

function CombatService:TryConfirm(combatant, now)
	local state = self:_state(combatant.Id)
	if state.Phase ~= "Active" then self:_advancePhase(state, now); return false end
	if now > state.ActiveUntil then
		local metrics = if self.Combatants:IsAlive(combatant.Id) and self.Ball:GetTarget() == combatant then self:_metrics(combatant) else nil
		local reason = if metrics and metrics.Closing > Config.Parry.ApproachEpsilon and metrics.Distance > Config.Parry.Range then "TOO_EARLY" else "TOO_LATE"
		self:_log(combatant, false, reason, metrics, state.ArmedRevision)
		self:_endAttempt(state, now)
		return false
	end
	if not self.Combatants:IsAlive(combatant.Id) then
		self:_log(combatant, false, "DEAD", nil, state.ArmedRevision)
		self:_endAttempt(state, now)
		return false
	end
	if self.Ball:GetTarget() ~= combatant then
		self:_log(combatant, false, "NOT_TARGET", nil, state.ArmedRevision)
		self:_endAttempt(state, now)
		return false
	end
	if self.Ball:GetRevision() ~= state.ArmedRevision then
		self:_log(combatant, false, "STALE_REVISION", nil, self.Ball:GetRevision())
		self:_endAttempt(state, now)
		return false
	end
	local metrics = self:_metrics(combatant)
	if metrics.Closing <= Config.Parry.ApproachEpsilon then
		self:_log(combatant, false, "TOO_LATE", metrics, state.ArmedRevision)
		self:_endAttempt(state, now)
		return false
	end
	if not metrics.InArc then
		self:_log(combatant, false, "OUTSIDE_ARC", metrics, state.ArmedRevision)
		self:_endAttempt(state, now)
		return false
	end
	if metrics.Distance > Config.Parry.Range then return false end
	if not self.Ball:Redirect(combatant, state.ArmedRevision) then
		self:_log(combatant, false, "STALE_REVISION", metrics, self.Ball:GetRevision())
		self:_endAttempt(state, now)
		return false
	end
	self:_log(combatant, true, "PARRIED", metrics, state.ArmedRevision)
	self:_endAttempt(state, now)
	self.EffectRemote:FireAllClients({ Kind = "ParrySuccess", CombatantId = combatant.Id, Position = self.Ball:GetPosition(), RallyCount = self.Ball:GetRallyCount() })
	return true
end

-- context is client-observed data only. It limits stale requests; it never grants a hit.
function CombatService:TryParry(subject, context)
	local combatant = if type(subject) == "string" then self.Combatants:Get(subject) else subject
	if not combatant then return self:_reject(nil, "DEAD", nil, -1) end
	if not self.Playing or not self.Ball or not self.Ball:IsTracking() then return self:_reject(combatant, "TOO_EARLY", nil, -1) end
	if not self.Combatants:IsAlive(combatant.Id) then return self:_reject(combatant, "DEAD", nil, self.Ball:GetRevision()) end
	if self.Ball:GetTarget() ~= combatant then return self:_reject(combatant, "NOT_TARGET", nil, self.Ball:GetRevision()) end
	local now = workspace:GetServerTimeNow()
	local reportedTime = if type(context) == "table" then context.ClientTime else context
	local observedRevision = if type(context) == "table" then context.BallRevision else self.Ball:GetRevision()
	if combatant.Kind == "Player" and (type(reportedTime) ~= "number" or math.abs(now - reportedTime) > Config.Parry.TimestampTolerance) then
		return self:_reject(combatant, "TOO_LATE", nil, self.Ball:GetRevision())
	end
	if type(observedRevision) ~= "number" or observedRevision ~= self.Ball:GetRevision() then return self:_reject(combatant, "STALE_REVISION", nil, self.Ball:GetRevision()) end
	local state = self:_state(combatant.Id)
	self:_advancePhase(state, now)
	if now < state.ReadyAt or state.Phase ~= "Idle" then return self:_reject(combatant, "COOLDOWN", nil, observedRevision) end
	local metrics = self:_metrics(combatant)
	if metrics.Closing <= Config.Parry.ApproachEpsilon then return self:_reject(combatant, metrics.Distance <= Config.Parry.Range and "TOO_LATE" or "NOT_APPROACHING", metrics, observedRevision) end
	if not metrics.InArc then return self:_reject(combatant, "OUTSIDE_ARC", metrics, observedRevision) end
	local compensation = if combatant.Kind == "Player" then math.clamp(now - reportedTime, 0, Config.Parry.MaxLatencyCompensation) else 0
	local maximumReach = Config.Parry.Range + metrics.Closing * (Config.Parry.InputBuffer + Config.Parry.MaxLatencyCompensation)
	if metrics.Distance > maximumReach then return self:_reject(combatant, "OUT_OF_RANGE", metrics, observedRevision) end
	local bufferedReach = Config.Parry.Range + metrics.Closing * (Config.Parry.InputBuffer + compensation)
	if metrics.Distance > bufferedReach then return self:_reject(combatant, "TOO_EARLY", metrics, observedRevision) end
	state.Phase = "Active"
	state.ServerReceiveTime = now
	state.ClientReportedTime = reportedTime or now
	state.LatencyCompensation = compensation
	state.ActiveUntil = now + Config.Parry.ActiveWindow + compensation
	state.ReadyAt = now + Config.Parry.Cooldown
	state.ArmedRevision = observedRevision
	if combatant.Player then self.EffectRemote:FireClient(combatant.Player, { Kind = "ParryWindow", ActiveUntil = state.ActiveUntil, ReadyAt = state.ReadyAt }) end
	if self:TryConfirm(combatant, now) then return true, "PARRIED" end
	return true, "ARMED"
end

return CombatService
