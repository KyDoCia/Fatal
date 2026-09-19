local CombatTypes = {}

CombatTypes.ProtocolVersion = 1

CombatTypes.DuelState = table.freeze({
	Waiting = "Waiting",
	Intermission = "Intermission",
	Countdown = "Countdown",
	Active = "Active",
	Ending = "Ending",
	Resetting = "Resetting",
})

CombatTypes.EventKind = table.freeze({
	DuelStateChanged = "DuelStateChanged",
	BallTargetChanged = "BallTargetChanged",
	ParryConfirmed = "ParryConfirmed",
	CombatantHit = "CombatantHit",
	CombatantEliminated = "CombatantEliminated",
	RallyChanged = "RallyChanged",
	RoundEnded = "RoundEnded",
})

function CombatTypes.Event(kind, payload)
	payload = payload or {}
	payload.Version = CombatTypes.ProtocolVersion
	payload.Kind = kind
	return payload
end

return table.freeze(CombatTypes)
