# FATAL

FATAL is an original Roblox competitive parry game focused on precision, momentum, escalation, and impact.

## Current phase: Combat Lab

The active Studio slice is intentionally reduced to one Player, one R15 `TrainingOpponent`, one authoritative ball, a neutral 120×120 test arena, and a 1.5 second reset. The purpose is repeated measurement of parry geometry, continuous hit detection, homing, redirect, rally, lifecycle, and latency tolerance.

Static verification never substitutes for Roblox Studio runtime testing.

## Architecture goals

- R15-only character support
- Server-authoritative combat
- One authoritative gameplay ball
- Shared Combatant abstraction for Players and NPCs
- Client sends intent and an observed ball revision only
- Gameplay collision independent from visual geometry
- Exact canonical module paths
- Runtime-first validation in Roblox Studio

## Build and static verification

Install the tools declared in `aftman.toml`, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/verify.ps1
```

This regenerates Combat Lab assets, compiles Luau, builds `Fatal.rbxlx`, audits the serialized hierarchy, and runs the mathematical and lifecycle suite.

## Runtime playtest

Open the generated `Fatal.rbxlx` in Roblox Studio and test with one player. With `RoundConfig.CombatLab = true`, Studio creates exactly one R15 opponent and begins after a 0.45 second start delay.

When using live Rojo sync, sync the complete project while Play is stopped, then start the session. Roblox copies direct `StarterGui` children into `PlayerGui` on the character's first spawn.

Validate:

1. Exactly one `TrainingOpponent` and one ball.
2. Player and NPC alternate as targets and use the same parry pipeline.
3. Frontal, early, late and stale-revision rejection behavior.
4. Rally speed, target leading, high-speed sweep and wall bounce.
5. Elimination followed by a clean reset in 1.5 seconds.
6. Repeat at least 20 times without duplicated Combatants, NPCs, balls or connections.
7. Test 0/50/100/150 ms using Studio Network Emulation and inspect both Outputs.

Set `CombatConfig.CombatDebug = true` for client-only geometry and metrics. Set `CombatConfig.DebugCombat = true` for one-line `[PARRY]` and `[HIT]` server diagnostics. Both default to `false`.

Remote payloads are documented in `docs/REMOTE_SCHEMAS.md`.
