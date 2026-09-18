# FATAL remote schemas

All gameplay mutation is server-owned. The client never supplies a target, hit, ball transform, damage, parry result, or winner.

## `Game.Remotes.Combat.ParryRequest`

Direction: client to server.

```luau
ParryRequest:FireServer(clientTimestamp: number, observedBallRevision: number)
```

The revision is an observed-state guard, never authority. The server resolves the sender's registered Combatant and validates round state, life state, current target, bounded timestamp compensation, cooldown, active window, current ball revision, frontal arc, distance, and closing velocity.

## `Game.Remotes.Combat.BallSnapshot`

Direction: server to all clients.

```luau
{
    State: "Inactive" | "Tracking",
    Ball: BasePart | false,
    Position: Vector3,
    CurrentDirection: Vector3,
    DesiredDirection: Vector3,
    Speed: number,
    TargetId: string,
    TargetCharacter: Model | false,
    RallyCount: number,
    Revision: number,
    ServerTime: number,
}
```

The referenced `Ball` is the replicated server instance. The client never creates a gameplay-ball clone.

## `Game.Remotes.Combat.CombatEffect`

Direction: server to one or all clients.

```luau
{ Kind: "ParryWindow", ActiveUntil: number, ReadyAt: number }
{ Kind: "ParrySuccess", CombatantId: string, Position: Vector3, RallyCount: number }
{ Kind: "WallBounce", Position: Vector3, Normal: Vector3, RallyCount: number }
{ Kind: "Elimination", CombatantId: string, Position: Vector3, RallyCount: number }
```

These payloads drive presentation only. Authoritative state remains in server services.

## `Game.Remotes.Round.RoundState`

Direction: server to all clients.

```luau
{
    State: "Waiting" | "Intermission" | "Starting" | "Playing" | "Ending",
    Deadline: number,
    Round: number,
    AliveCount: number,
    WinnerId: string,
    WinnerName: string,
    Participants: {
        { Id: string, Kind: "Player" | "NPC", DisplayName: string, Alive: boolean, Character: Model }
    },
    ServerTime: number,
}
```
