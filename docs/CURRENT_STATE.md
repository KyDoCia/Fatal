# FATAL Current State

## Baseline

Foundation branch establishes the first playable vertical-slice architecture. Runtime behavior is not yet owner-confirmed in Roblox Studio.

## Implemented

- Canonical Rojo mapping for shared/server/client roots.
- Shared gameplay configuration and domain types.
- Server-authoritative Combatant registry.
- One authoritative gameplay ball.
- Server-owned targeting, elimination, rally speed escalation and parry validation.
- Round state machine: Lobby -> Countdown -> Active -> Winner -> Cleanup.
- Client sends parry intent only.
- PC (`F`), console (`R2`) and touch action binding.

## Intentionally not implemented yet

- NPC combatants.
- Ricochet/arena collision behavior.
- Prediction/latency compensation.
- Rich VFX/audio/camera feedback.
- Rewards, persistence, progression, abilities or monetization.
- Production UI beyond Roblox touch action support.

## Runtime gate

Before merge, validate in Roblox Studio with at least two players:

1. Rojo sync produces exactly one `ReplicatedStorage.Game`, one `ServerScriptService.Game` and one `StarterPlayerScripts.Game` root.
2. Round transitions Lobby -> Countdown -> Active.
3. Exactly one `GameplayBall` exists during Active.
4. Ball targets a living combatant and eliminates on contact.
5. Targeted player can parry with F/touch/controller and the ball retargets.
6. Rally speed increases across successful parries without duplicating the ball.
7. One player remains, Winner is reached, ball is removed, and a new round can start.
8. No red Output errors across two consecutive rounds.

## Next decision after runtime gate

Do not add progression. First evaluate combat feel: parry timing, targeting readability, ball acceleration, latency behavior and whether the core loop is satisfying enough to justify deeper systems.
