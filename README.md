# FATAL

FATAL is an original Roblox competitive parry game focused on precision, momentum, escalation, and impact.

## Vision

One miss is enough.

The core experience is built around a single escalating threat: a lethal ball that acquires targets, accelerates through rallies, ricochets through the arena, and can only be survived through precise timing.

## Current phase

Foundation only. The project is intentionally starting clean before combat, progression, and content expansion.

## Architecture goals

- R15-first character support
- Server-authoritative combat and rewards
- One authoritative gameplay ball
- Shared Combatant abstraction for players and NPCs
- Data-driven/customizable UI
- Rojo-friendly canonical hierarchy
- Runtime-first validation in Roblox Studio
- PC, mobile, and console considered from the start

## Vertical-slice gate

`Lobby -> Countdown -> Ball -> Target -> Parry -> Rally -> Elimination -> Winner -> Cleanup -> Next Round`

The project should not expand into large progression systems until this loop can complete repeatedly with zero red Output errors and no duplicated authoritative instances.
