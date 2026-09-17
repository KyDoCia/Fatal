# FATAL agent guide

Build an original, premium Roblox competitive parry game.

## Mandatory reading order
Before making changes, read:
1. `AGENTS.md`
2. `docs/AI_HANDOFF.md`
3. `docs/ARCHITECTURE.md`
4. `README.md`
5. Relevant source/tests for the assigned task

`docs/AI_HANDOFF.md` is the current execution contract. Do not implement work beyond its active gate unless the handoff explicitly authorizes it.

## Core principles
- R15 first.
- Server-authoritative combat.
- Exactly one authoritative gameplay ball.
- Players and NPCs use the same Combatant abstraction and combat rules.
- Client sends intent only.
- UI is data-driven and customizable.
- Gameplay collision is separate from visual architecture.
- Prefer exact canonical module paths over recursive discovery.
- Treat Roblox Studio runtime as final validation.
- Never describe static verification as runtime validation.
- Fix root causes; do not hide lifecycle/schema bugs behind silent guards.

## Current product rule: COMBAT LAB LOCK
No new feature work is allowed until the 1v1 Player vs TrainingOpponent combat loop is excellent and explicitly approved after Studio playtesting.

While this lock is active, do NOT expand inventory, lootboxes, shop, currency, DataStore, abilities, powers, dash, cosmetics, rarity, ranked, quests, battle pass, finishers, social systems, lobby complexity, final-map art, or additional NPCs.

The active priority is only: ball simulation, targeting, parry timing, hurt/parry geometry, continuous collision, redirect, rally, latency tolerance, deterministic lifecycle/cleanup, one training NPC, minimal readable feedback, and debugging/tuning instrumentation.

## Handoff protocol
At the beginning of a Codex task:
- Read `docs/AI_HANDOFF.md` and obey `Status`, `Active gate`, `Blocking issues`, `Acceptance tests`, and `Next task`.
- Inspect the repository state instead of trusting an old report.
- Do not silently broaden scope.

At the end of a Codex task:
- Do not rewrite `docs/AI_HANDOFF.md` to approve your own work.
- Report exact files changed and tests actually executed.
- State exactly `RUNTIME TESTED: ...` only if Roblox Studio was genuinely run, otherwise state `RUNTIME NOT TESTED`.
- Provide root causes for bugs rather than only describing patches.
- Stop after the assigned task. Do not implement the proposed next phase.

The reviewer/architect updates `docs/AI_HANDOFF.md` after reviewing repository changes and real playtest evidence.

## Originality
Do not copy proprietary code, assets, UI, audio, animation, maps, or other protected content from Blade Ball, Death Ball, or other games. Genre mechanics may be studied, but FATAL must use original implementation and presentation.
