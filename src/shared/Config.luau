--!strict

local Config = {
	MinimumPlayers = 2,
	LobbyDuration = 10,
	CountdownDuration = 3,
	IntermissionDuration = 5,

	Ball = {
		BaseSpeed = 42,
		SpeedPerParry = 4,
		MaxSpeed = 180,
		SpawnHeight = 6,
	},

	Parry = {
		Cooldown = 0.35,
		MaxDistance = 18,
		FacingDotMinimum = -0.15,
	},
}

return table.freeze(Config)
