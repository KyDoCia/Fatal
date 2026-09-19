# FATAL — AI Handoff

> Git is the source of truth. Roblox Studio runtime is the authority for gameplay quality.

## Status

**COMBAT BASELINE — HUMAN RUNTIME PASS**

The latest human run test approved the current functional baseline: parry hit/miss, continuous redirect momentum, aim-controlled curve and CurveStrength, terminal intercept, anti-orbit, swept collision, targeting, TrainingOpponent, rounds, multiplayer foundation, R15 animation foundation, Wins, Coins, Gems and profiles.

FATAL is not finished. This checkpoint freezes working combat before the next development cycle.

## Active gate

Stability freeze. Do not change combat feel, tuning, trajectory, parry timing or architecture without a reproducible runtime defect. Read `docs/COMBAT_BASELINE.md` before touching combat.

## Approved baseline

- One server-authoritative gameplay ball.
- Player and TrainingOpponent share `CombatCore:TryParry`.
- Aim-controlled smooth curve with proportional CurveStrength.
- Terminal intercept, anti-orbit, moving-target interception and swept collision.
- Atomic trajectory legs with no intentional redirect delay.
- Outgoing momentum never drops below incoming momentum during a normal rally, up to MaxSpeed.
- Explicit authoritative duel lifecycle and semantic combat events.
- Parry/hit/miss presentation and R15 animation foundation remain client-side.
- Clean canonical runtime without rejected legacy UI/debug systems.
- Existing Win eligibility, reward deduplication, Coins/Gems and profile behavior.

## Verification contract

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tests/verify.ps1`. It must compile sources, regenerate and build `Fatal.rbxlx`, compare embedded scripts with repository sources, audit the place and pass the invariant suite. Human tests must open the generated `Fatal.rbxlx` without Rojo live-sync. Static verification is never runtime validation.

## Next macro phase — COMBAT FEEL V1

**NOT IMPLEMENTED. Do not begin without a new explicit handoff.**

Future goals are a stronger final presentation for the basic sword, final animations, directional slash, shockwave, parry impact, ball reaction, trail, audio, camera response and rally intensity. Preserve the authority and gameplay contracts in `docs/COMBAT_BASELINE.md`.

After Combat Feel V1, the planned sequence is:

1. Content foundation: complete inventory-facing Weapons, Balls, Effects, AnimationSets and equip/unequip behavior.
2. Crates/economy content: loot tables, rarity, opening presentation, server-authoritative grants and existing currency integration.

These phases are planning context only. They are not authorized by this handoff.

## Prohibited during freeze

No new UI, inventory rewrite, crates, shop, content variants, powers, abilities, dash, ranked, quests, battle pass, maps, lobby, matchmaking, curve model, parry system, broad refactor or subjective tuning.
