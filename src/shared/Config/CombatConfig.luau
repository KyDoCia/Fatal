local Config = {
	CombatDebug = false,
	Ball = {
		Radius = 0.85,
		SpawnHeight = 5,
		BaseSpeed = 50,
		MaxSpeed = 200,
		SpeedPerRally = 7,
		HomingRate = 2.4,
		MaxDeltaTime = 0.1,
		MaxTravelPerStep = 1.5,
		SnapshotInterval = 1 / 20,
	},
	Parry = {
		DefensiveRadius = 12,
		Cooldown = 0.32,
		ApproachEpsilon = 0.1,
	},
	Hurt = {
		BodyRadius = 1.8,
		BodyHeight = 5.4,
	},
	NPC = {
		ThinkInterval = 0.025,
		ReactionRadius = 11.5,
		ReactionMin = 0.03,
		ReactionMax = 0.06,
		MissChance = 0.04,
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
