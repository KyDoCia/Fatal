local Config = {
	DebugCombat = false,
	CombatDebug = false,
	Ball = {
		Radius = 2.25,
		SpawnHeight = 6,
		BaseSpeed = 55,
		MaxSpeed = 270,
		RallyGrowth = 0.11,
		TurnRate = 3.8,
		HighSpeedTurnMultiplier = 0.32,
		RedirectMomentumRetention = 0.22,
		TargetLeadScale = 0.32,
		MaxTargetLeadTime = 0.22,
		SurfaceOffset = 0.12,
		MaxCollisionsPerStep = 3,
		MaxTravelPerSubstep = 2.5,
		MaxSubsteps = 12,
		MaxDeltaTime = 0.1,
		SnapshotInterval = 1 / 20,
	},
	HurtVolume = {
		PlayerHitRadius = 2.35,
		PlayerHitHeight = 5.8,
	},
	Parry = {
		Range = 11,
		ArcDegrees = 165,
		ActiveWindow = 0.24,
		InputBuffer = 0.07,
		Recovery = 0.16,
		Cooldown = 0.58,
		MaxLatencyCompensation = 0.11,
		TimestampTolerance = 0.5,
		ApproachEpsilon = 0.05,
	},
	Feedback = {
		TargetLeadTime = 2.2,
		DangerTime = 0.85,
		CriticalTime = 0.34,
	},
}

function Config.SpeedForRally(rallyCount)
	local rally = math.max(0, rallyCount)
	local progress = 1 - math.exp(-rally * Config.Ball.RallyGrowth)
	return math.min(Config.Ball.MaxSpeed, Config.Ball.BaseSpeed + (Config.Ball.MaxSpeed - Config.Ball.BaseSpeed) * progress)
end

function Config.TurnRateForSpeed(speed)
	local span = Config.Ball.MaxSpeed - Config.Ball.BaseSpeed
	local alpha = math.clamp((speed - Config.Ball.BaseSpeed) / span, 0, 1)
	return Config.Ball.TurnRate * (1 + (Config.Ball.HighSpeedTurnMultiplier - 1) * alpha)
end

return table.freeze(Config)
