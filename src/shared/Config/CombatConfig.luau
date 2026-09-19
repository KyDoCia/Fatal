local Config = {
	Telemetry = { Enabled = false },
	Ball = {
		Radius = 1,
		LaunchOffset = 2,
		BaseSpeed = 28,
		MaxSpeed = 140,
		SpeedPerRally = 4,
		HomingRate = 2.4,
		MaxDeltaTime = 0.1,
		MaxTravelPerStep = 1.5,
		SnapshotInterval = 1 / 20,
	},
	Parry = {
		DefensiveRadius = 10,
		EarlyBuffer = 0.12,
		Cooldown = 0.1,
		IntentMinInterval = 0.025,
		ApproachEpsilon = 0.1,
	},
	Hurt = {
		BodyRadius = 1.8,
		BodyHeight = 5.4,
	},
	NPC = {
		ReactionRadius = 10,
	},
	Feedback = {
		CueStartMultiplier = 1.6,
		ParryFlashDuration = 0.11,
		ParryTrailLifetime = 0.22,
		HitFlashDuration = 0.15,
		CameraImpulse = 0.18,
	},
	Duel = {
		Intermission = 1,
		Countdown = 0.5,
		Ending = 1.2,
		CharacterTimeout = 8,
	},
	Rewards = {
		MinimumHumansForWin = 3,
		WinnerCoins = 100,
		WinnerGems = 0,
	},
}

function Config.SpeedForRally(rally)
	return math.min(Config.Ball.MaxSpeed, Config.Ball.BaseSpeed + math.max(0, rally) * Config.Ball.SpeedPerRally)
end

function Config.FirstApproachSeconds(separation)
	local travel = math.max(0, separation - Config.Ball.LaunchOffset - Config.Parry.DefensiveRadius)
	return travel / Config.Ball.BaseSpeed
end

function Config.ParryOpportunityMilliseconds(speed)
	local hurtContact = Config.Hurt.BodyRadius + Config.Ball.Radius
	return math.max(0, Config.Parry.DefensiveRadius - hurtContact) / speed * 1000
end

return table.freeze(Config)
