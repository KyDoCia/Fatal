local State = {
	Round = {
		State = "Waiting",
		Deadline = 0,
		Round = 0,
		AliveCount = 0,
		WinnerId = "",
		WinnerName = "",
		Participants = {},
		ServerTime = 0,
	},
	Ball = {
		State = "Inactive",
		Ball = false,
		Position = Vector3.zero,
		CurrentDirection = Vector3.zAxis,
		DesiredDirection = Vector3.zAxis,
		Speed = 0,
		TargetId = "",
		TargetCharacter = false,
		RallyCount = 0,
		Revision = 0,
		ServerTime = 0,
	},
	Combat = {
		Phase = "Idle",
		ActiveUntil = 0,
		ReadyAt = 0,
		IsTarget = false,
		Threat = "SAFE",
		TimeToImpact = math.huge,
	},
	RoundChanged = Instance.new("BindableEvent"),
	BallChanged = Instance.new("BindableEvent"),
	CombatChanged = Instance.new("BindableEvent"),
}

return State
