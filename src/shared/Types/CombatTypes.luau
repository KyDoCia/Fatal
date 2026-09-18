export type CombatantKind = "Player" | "NPC"
export type Combatant = {
	Id: string,
	Kind: CombatantKind,
	Player: Player?,
	Character: Model?,
	Humanoid: Humanoid?,
	RootPart: BasePart?,
	Alive: boolean,
}

export type ParryPhase = "Idle" | "Active" | "Recovery" | "Cooldown"

return {}
