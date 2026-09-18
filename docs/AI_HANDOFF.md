# FATAL — AI Handoff

> Execution contract between reviewer/architect and Codex. Git is the source of truth.

## Status
**COMBAT LAB LOCK — CURRENT COMBAT REJECTED / CLEAN CORE REWRITE AUTHORIZED**

The human Studio playtest has rejected the current combat system as a whole. This is no longer a tuning sprint.

Do not add product features. Do not merge the rejected combat implementation into `main`. Preserve repository history so rollback/comparison remains possible.

## Human evidence
Latest Studio evaluation:
- gameplay is still extremely poor;
- interacting/parrying the ball is not intuitive or satisfying;
- presentation around the combat is noisy and obstructive (`FIGHT`, `CRITICAL`, TTI/debug-like information dominate the screen);
- the ball still reads as oversized/heavy relative to the desired clean duel;
- incremental tuning is no longer desired.

The tester explicitly requests a complete combat-system rebuild.

## Decision
Stop patching the existing parry architecture.

The current chain built around armed `Active` state + later contact confirmation has accumulated too many interacting conditions before the basic interaction was proven. Do not preserve it merely because tests exist.

Keep only infrastructure that is independently useful and verified: canonical Rojo hierarchy, one-Player/one-NPC Combat Lab bootstrapping, R15 character binding, cleanup/lifecycle foundations, and generic utilities that do not dictate rejected combat behavior.

Replace the hot combat path with a deliberately smaller architecture.

## NEXT TASK — COMBAT CORE V2 FROM FIRST PRINCIPLES

Work on a NEW branch based on current `origin/main`, named approximately `codex/combat-core-v2`. Do not build V2 on top of the rejected combat branch. If useful infrastructure must be reused, port/cherry-pick only the minimal files or concepts deliberately after inspection.

### Goal
Create the smallest high-quality duel possible:

`Player -> incoming ball -> intuitive parry -> immediate redirect -> NPC -> return -> rally`

Exactly one Player, one TrainingOpponent, one ball.

### Delete complexity from the hot path
V2 must NOT start with the old multi-phase parry state machine.

Do not begin with:
- `Idle -> Active -> Recovery -> Cooldown` as the authority model;
- armed revision waiting for later contact;
- multiple overlapping timing gates;
- TTI as a required parry gate;
- sword mesh collision;
- client-authoritative success;
- giant invisible hitboxes;
- complex prediction;
- spectacle/UI compensating for weak mechanics.

Add complexity later only when a real playtest demonstrates the need.

### V2 parry semantics
Start from this simple server-authoritative rule:

When the targeted Player presses parry, the server evaluates the CURRENT authoritative ball state immediately.

Accept when all are true:
1. duel is active;
2. actor is alive and is the current target;
3. ball exists and is moving toward actor;
4. ball is inside a generous but explicit defensive radius;
5. parry is not on a simple cooldown.

If accepted, redirect the ball immediately in that same authoritative action and increment rally/revision.

No `arm now, confirm later when contact happens` in V2 baseline.

If the Player presses slightly before the ball enters range, it may fail initially. Do not solve that with a complex buffer until human testing shows one is necessary. We need to understand the raw interaction first.

### Defensive geometry
Use one simple defensive radius around a stable R15 reference point (HRP/torso-derived center) for V2 baseline.

No frontal arc in the first V2 candidate unless an objective exploit makes it necessary.

The player should not need to point the sword tip at the ball. Facing is presentation, not authority.

Initial hypothesis: defensive radius around 10–14 studs. Centralize it. This is intentionally forgiving for the first feel test.

### Ball visual/collision size
Make the ball visually compact.

Initial authoritative radius hypothesis: about 0.75–1.0 stud. Visual diameter should read roughly like a compact projectile, not a giant orb beside an R15 avatar.

Keep authoritative collision and visual size coherent. Do not hide a huge gameplay sphere inside a tiny visual.

### Hit semantics
Parry radius and hurt collision are separate.

For a missed parry, retain a small predictable R15 body hurt volume and continuous/swept ball collision so high-speed balls do not tunnel.

Do not use `Touched` as sole authority.

### Ball movement V2
Keep movement simple and readable:
- server authoritative;
- current target;
- position + velocity;
- bounded homing toward target;
- continuous collision;
- wall bounce only if it already works cleanly and does not complicate the duel.

Do not implement advanced target leading in the first candidate.

At low rally the trajectory should be easy to read.

### Redirect V2
On accepted parry:
- choose the other combatant in 1v1;
- set a strong outgoing direction toward that target;
- apply speed for the new rally;
- redirect immediately;
- replicate feedback.

The first V2 candidate may intentionally use a stronger/direct redirect than realistic momentum. Responsiveness and causality matter more than preserving the rejected momentum model.

### Rally V2
Use a tiny understandable speed function. No elaborate piecewise model.

Start approximately:
- base speed: 45–55 studs/s;
- small increase each successful exchange;
- cap initially around 180–220 studs/s for the first feel test.

The first 3–5 exchanges must be easy enough to learn the timing.

### Cooldown
Use only a simple anti-spam cooldown initially, roughly 0.25–0.4 seconds. Centralize it.

No recovery/active/buffer state machine until playtesting justifies it.

### NPC V2
Exactly one `TrainingOpponent` R15.

It uses the SAME server `TryParry` rule as the Player.

Its decision layer may call `TryParry` when the incoming ball crosses a reaction threshold. Give it enough imperfection to miss sometimes, but for the first candidate prioritize sustaining rallies so the human can test repeated returns.

No complex movement AI. Stationary or tiny repositioning is acceptable.

### Input
PC baseline:
- MouseButton1;
- F.

Client sends only parry intent. Local input may play a tiny immediate animation/feedback, but server decides success.

### UI — remove the noise
For V2 baseline remove/hide the giant combat overlays seen in the failed playtest.

Normal play should NOT show giant `FIGHT`, `CRITICAL`, TTI numbers, debug boxes, or large target text over the character.

Normal UI should be nearly empty:
- small rally counter at top if useful;
- optional subtle target cue only if truly necessary.

`CombatDebug = false` by default.

Debug information must never be part of the normal gameplay presentation.

### Weapon
Weapon is visual only. Keep one clean placeholder sword if needed, but do not let its mesh/hitbox determine parry success.

### Arena
Do not build a map. Use a clean flat test arena with enough contrast to see the ball.

### Reset/lifecycle
Reuse or rebuild the already-correct lifecycle principles:
- Player logical combatant registered once;
- one NPC;
- one ball;
- deterministic cleanup;
- quick reset after elimination;
- no accumulated connections/instances.

### Code architecture
V2 should be small enough that the entire hot path is easy to reason about.

Prefer a few focused modules over abstraction for its own sake. The reviewer should be able to trace:
`input -> server TryParry -> immediate validation -> redirect`
without jumping through a large state machine.

### Tests
Write/retain focused tests for invariants, not to justify feel:
- one authoritative ball;
- incoming-direction test;
- defensive-radius accept/reject;
- cooldown;
- immediate redirect;
- swept hurt collision;
- cleanup/reset;
- Player/NPC shared TryParry path.

Do not recreate dozens of tests for speculative mechanics that V2 does not contain.

### Runtime truth
If Roblox Studio is not actually run, report `RUNTIME NOT TESTED`.

Static compile/build is not gameplay validation.

## Human acceptance test for V2 candidate
The candidate is ready for human evaluation when:
1. Play immediately gives 1 Player, 1 NPC, 1 compact ball.
2. No giant `FIGHT`/`CRITICAL`/TTI overlays obstruct gameplay.
3. The first ball approaches slowly/readably.
4. Pressing F/click while the approaching ball is visibly within the defensive zone produces an immediate redirect.
5. The NPC can return it.
6. Several low-rally exchanges are realistically achievable.
7. Pressing obviously too early/out of range fails.
8. Missing produces a coherent body hit.
9. Reset is fast and clean.
10. Repeating does not duplicate Player/NPC/ball/state.

The human tester — not Codex — decides whether V2 is enjoyable enough to iterate.

## Frozen scope
No inventory, lootboxes, shop, economy, DataStore, powers, abilities, dash, cosmetics, ranked, quests, battle pass, finishers, social, additional NPCs, final map, lobby expansion or cinematic polish.

## Completion report
Keep it short:

### Git
new branch + pushed SHA + base main SHA.

### What was replaced
old hot-path pieces deliberately not carried into V2.

### V2 hot path
one concise trace from input to redirect.

### Current tuning
ball radius, defensive radius, base/max speed, speed growth, cooldown, NPC reaction values.

### Verification
commands/tests actually run and result.
`RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human test
shortest exact steps to open the V2 build and play.

STOP after this report. Do not add the next feature and do not self-approve V2.