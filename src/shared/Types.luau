--!strict

export type RoundState = "Lobby" | "Countdown" | "Active" | "Winner" | "Cleanup"

export type Combatant = {
	Id: string,
	Model: Model,
	Root: BasePart,
	Alive: boolean,
	IsPlayer: boolean,
	Player: Player?,
}

export type BallState = {
	TargetId: string?,
	Speed: number,
	Rally: number,
	Active: boolean,
}

return nil
