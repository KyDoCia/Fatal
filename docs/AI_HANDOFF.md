# FATAL — AI Handoff

> Execution contract between reviewer/architect and Codex. Read `AGENTS.md`, this file, `docs/ARCHITECTURE.md`, then inspect the actual repository before changing code.

## Status
**COMBAT LAB LOCK — REJECTED / RECOVERY REQUIRED**

The latest presented result is NOT approved. Do not add features and do not self-approve this gate.

## Why it was rejected
The previous completion report described substantial static engineering but explicitly had no Roblox Studio runtime validation. More importantly, the delivered experience produced zero satisfaction in actual evaluation. Therefore static assertions, compile success, generated places, parameter tables and architectural sophistication are not evidence that the combat feels good.

The previous report also referenced local paths under `C:/Users/KyDoCia/Desktop/DeathBall2/...` while claiming to implement FATAL. This is unacceptable provenance ambiguity for a repository that was intentionally created clean. From this point forward, the Git repository `KyDoCia/Fatal` is the source of truth.

## New working rule: repository first
Do not begin another large rewrite from an old local DeathBall2 tree.

First reconcile your working copy with `KyDoCia/Fatal`:
1. Confirm the local Git remote points to `KyDoCia/Fatal`.
2. Fetch current `origin/main`.
3. Preserve useful uncommitted FATAL work deliberately; do not lose it and do not blindly overwrite main.
4. Rebase/merge/cherry-pick as appropriate so the implementation being tested actually exists in the FATAL repository history.
5. Commit and push the implementation to a dedicated branch based on current `origin/main`.
6. Do not claim completion while the important implementation exists only as an uncommitted local working tree.
7. Do not use or generate deliverables from `Desktop/DeathBall2` as the canonical FATAL project path. The canonical local checkout must be the FATAL repository.

If reconciliation is unsafe because local work conflicts with repository history, stop and report the exact Git state instead of improvising destructive commands.

## Product rule
**No feature work until the basic 1v1 is genuinely enjoyable in Studio.**

Frozen: inventory, lootboxes, shop, economy, DataStore progression, powers, abilities, dash, cosmetics, ranked, quests, battle pass, finishers, social systems, additional NPCs, final map art, cinematic polish and lobby expansion.

## This sprint has one objective
Make the smallest possible playable loop worthy of tuning:

`Player <-> Ball <-> TrainingOpponent`

Exactly:
- 1 Player;
- 1 R15 TrainingOpponent;
- 1 authoritative gameplay ball;
- one clean test arena;
- parry;
- redirect;
- rally;
- hit/elimination;
- fast deterministic reset.

Do not optimize for feature count or impressive report length.

## Preserve good engineering, remove speculative complexity
Inspect the implementation that actually reaches the FATAL branch. Preserve sound pieces such as continuous collision, server authority, shared Combatant rules and deterministic cleanup if they are correct.

However, do NOT treat previous tuning numbers as requirements. Values such as 11-stud parry range, 165-degree arc, 0.24-second active window, capsule dimensions, redirect ratios, turn rates and speed curves are hypotheses only. They may be changed or simplified when playtesting shows they feel bad.

Do not add more mathematical systems merely because they sound sophisticated. Every system in the hot gameplay path must solve an observed gameplay problem.

## Immediate technical checks
Before tuning feel, verify in the repository implementation:
- duplicate Player Combatant registration is actually fixed at the lifecycle root;
- round/lab preparation cannot re-enter while yielding;
- Player identity is registered once and rebound/reset between rounds rather than recreated incorrectly;
- exactly one TrainingOpponent exists;
- exactly one authoritative gameplay ball exists;
- reset is idempotent and does not accumulate connections/state;
- Player and NPC reach the same authoritative parry validation path;
- high-speed contact uses continuous/swept detection rather than `Touched` alone;
- no runtime bootstrap depends on stale DeathBall2 paths/assets/hierarchy.

## Gameplay philosophy
The test must be readable without spectacle.

A successful parry should feel:
- immediate on input;
- visually connected to the incoming ball;
- forgiving enough to feel fair but not automatic;
- forceful on redirect;
- deterministic enough that the player understands why success/failure occurred.

A failed parry should feel explainable. If the player visually believes they hit the timing but the server rejects it repeatedly, the current tuning/model is wrong even if the math is internally consistent.

Do not hide poor timing behind huge hitboxes. Do not hide poor redirect behind VFX. Do not hide lifecycle bugs behind guards.

## Minimal presentation only
During this recovery sprint:
- simple readable arena;
- readable ball core/trail;
- one clean weapon placeholder if required for animation readability;
- short parry feedback;
- short hit feedback;
- minimal target/rally UI;
- debug visuals available behind a development toggle, OFF by default for normal feel testing.

No visual-content sprint.

## Runtime is the gate
Static verification remains useful, but the next meaningful evidence must come from Roblox Studio.

Codex may execute whatever static tests are available, but if Codex cannot launch/play Roblox Studio, it must say `RUNTIME NOT TESTED` and stop short of declaring gameplay quality.

The human playtest is authoritative for feel.

## Required human playtest loop
Prepare the project so the tester can launch and immediately repeat this loop without waiting through product systems:
1. Player spawns.
2. One TrainingOpponent spawns.
3. One ball begins the duel quickly.
4. Player parries to NPC.
5. NPC can parry back.
6. Rally accelerates enough to expose timing/trajectory issues.
7. Miss causes a clear elimination.
8. Duel resets quickly.
9. Repeat many times without duplicate state or runtime errors.

## Tuning instrumentation
Keep diagnostics concise and useful. For each rejected/accepted parry in debug mode, expose the small set of facts needed to tune it: result/reason, distance, closing velocity or TTI when useful, current ball revision and relevant timing state.

Do not flood Output every frame.

Debug geometry should make hurt/parry regions inspectable when requested, but normal playtest mode must remain visually clean.

## Acceptance for this sprint
This sprint is NOT approved by Codex.

It is ready for human evaluation only when:
- the implementation is committed/pushed to the FATAL repository branch;
- project builds from that FATAL checkout;
- exactly one NPC and one gameplay ball are expected;
- no known duplicate lifecycle bug remains;
- normal test mode is clean and debug can be toggled separately;
- the tester has a simple command/workflow to sync/build/open the correct FATAL place;
- Codex clearly distinguishes static checks from Studio runtime.

The final quality gate remains human Studio playtesting.

## Next task
**Repository recovery + smallest playable Combat Lab.**

Work from the current `KyDoCia/Fatal` repository, reconcile the existing Combat Lab implementation into a dedicated branch based on current `origin/main`, audit it against the immediate technical checks above, simplify anything speculative that is not helping the core duel, and prepare a clean 1v1 build for human Studio testing.

Do NOT add a new feature. Do NOT start visual polish. Do NOT expand scope. Do NOT self-approve gameplay feel.

## Completion report — keep it short
Return only:

### Git
- canonical local repository path;
- remote URL/name confirmation;
- branch;
- commit SHA pushed;
- whether branch is based on current `origin/main`.

### Core loop
- one paragraph describing Player -> Ball -> NPC -> reset.

### Fixes
- root-cause fixes made, especially lifecycle/reentrancy/duplicate state.

### Tuning changed
- only values/algorithms actually changed and why.

### Verification
- static commands actually executed and results.
- `RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human test
- exact shortest steps to open/sync the correct FATAL project and test the duel.

### Known blockers
- real unresolved blockers only.

Stop after this report. Do not implement the next task.