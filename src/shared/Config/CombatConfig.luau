local Config = {
	CombatDebug = false,
	Ball = {
		Radius = 0.55,
		SpawnHeight = 5,
		BaseSpeed = 70,
		MaxSpeed = 260,
		SpeedPerRally = 12,
		HomingRate = 2.4,
		MaxDeltaTime = 0.1,
		MaxTravelPerStep = 1.5,
		SnapshotInterval = 1 / 20,
	},
	Parry = {
		DefensiveRadius = 12,
		Cooldown = 0.1,
		ApproachEpsilon = 0.1,
	},
	Hurt = {
		BodyRadius = 1.8,
		BodyHeight = 5.4,
	},
	NPC = {
		ReactionRadius = 12,
		ReactionDelay = 0,
		MissChance = 0,
	},
	Round = {
		Countdown = 0.5,
		Ending = 1.2,
		CharacterTimeout = 8,
	},
}

function Config.SpeedForRally(rally)
	return math.min(Config.Ball.MaxSpeed, Config.Ball.BaseSpeed + math.max(0, rally) * Config.Ball.SpeedPerRally)
end

return table.freeze(Config)
