# FATAL — AI Handoff

> Execution contract between reviewer/architect and Codex. Git is the source of truth.

## Status
**COMBAT LAB LOCK — V2 INTERACTION WORKS, GAME FEEL FAILED**

Do not add features. Do not merge to main. Continue from `codex/combat-core-v2` and preserve the simple V2 hot path unless an observed defect requires changing it.

Latest V2 candidate audited: `c12bfe9538885baa26463603eae4d3321d7034d4`.

## Human playtest — authoritative evidence
V2 improved one important thing: the Player can now actually parry the ball.

However the overall gameplay is still rejected. Specific observations:
1. TrainingOpponent does not parry with absolute reliability, so rallies end before the core loop can be evaluated properly.
2. The ball still LOOKS extremely large in Studio despite `CombatConfig.Ball.Radius = 0.85`; therefore the visual asset/part sizing pipeline must be audited instead of merely changing the config radius.
3. Player does not spawn/orient facing the duel/ball/opponent, adding unnecessary cognitive work immediately.
4. Too much information is presented/processable during the duel; normal gameplay must be visually near-empty.
5. Gameplay feels slow and weak: ball travel, redirect and rally escalation lack urgency/impact.

These are concrete playtest failures. Fix them directly. Do not add speculative systems.

## Audited V2 baseline
Current config at the audited candidate:
- Ball Radius: `0.85`
- BaseSpeed: `50`
- MaxSpeed: `200`
- SpeedPerRally: `7`
- HomingRate: `2.4`
- DefensiveRadius: `12`
- Cooldown: `0.32`
- NPC ReactionRadius: `11.5`
- NPC ReactionMin/Max: `0.03 / 0.06`
- NPC MissChance: `0.04`

Current `CombatCore:TryParry` is intentionally simple and should remain understandable: active -> alive -> target -> cooldown -> approaching -> range -> immediate redirect. Do not reintroduce the rejected armed-window/contact-confirm architecture.

## NEXT TASK — V2 FEEL PASS 1: FAST, CLEAN, RELIABLE DUEL

### 1. Continue on the V2 branch
Fetch `origin/main`, read this handoff, incorporate only the handoff update into `codex/combat-core-v2`, and continue there. Do not merge V2 into main.

### 2. TrainingOpponent must parry 100% for this test
For this specific Combat Lab phase, the NPC is an instrument, not an opponent.

Set its intentional miss chance to ZERO and make its decision timing deterministic/reliable enough that, when it is alive/targeted and the ball enters its valid defensive condition, it calls the SAME authoritative `CombatCore:TryParry` path and succeeds essentially every valid return.

Do not give it direct `Ball:Redirect` access. Do not create a second combat rule.

If it can still fail due to its decision polling skipping the valid range at high speed, fix the decision trigger robustly (for example using predicted crossing/continuous approach information) rather than giving the NPC a secret giant parry radius.

Goal: during this phase, only the human should normally break the rally. This gives us a stable training wall for evaluating Player feel.

### 3. Audit why the ball LOOKS huge
`Radius = 0.85` in config did not produce a visually compact projectile in the actual Studio playtest.

Trace the full visual pipeline:
- `assets/CombatBall.rbxm` dimensions;
- clone/spawn code;
- any `Size`, scale, mesh scale, adornment, glow or secondary sphere;
- whether config radius is applied as radius or diameter;
- any generated asset script that can overwrite dimensions;
- whether the built `Fatal.rbxlx` contains a stale oversized asset.

Fix the ROOT CAUSE.

Target visual read: roughly a small projectile/orb, clearly smaller than the avatar torso/head silhouette. Start around a visible diameter of ~1.2–1.6 studs unless the asset construction requires another coherent value.

Authoritative collision radius should remain explicit and coherent; do not hide a huge collision sphere inside a tiny visual.

### 4. Spawn/orient the duel correctly
At every duel start/reset:
- Player and TrainingOpponent spawn at deliberate opposing positions;
- both face each other horizontally;
- camera/player immediately has the duel in front of them;
- initial ball spawn/target is inside that readable forward field.

Do not require the human to turn around or search for the ball at round start.

Use a deterministic `lookAt`/yaw orientation based on the opponent position while preserving sensible Y/up orientation.

### 5. Remove cognitive noise
Normal gameplay (`CombatDebug = false`) should be nearly empty.

Keep at most:
- one SMALL rally counter;
- one subtle target cue only if necessary for clarity.

Remove/hide during normal Combat Lab play:
- giant FIGHT text;
- giant CRITICAL text;
- TTI numbers;
- debug boxes/volumes;
- labels floating over the character;
- redundant status text;
- any persistent instruction that competes with watching the ball.

The player's eyes should naturally track only: opponent, ball, weapon/character.

### 6. Make the duel faster and stronger
The current `50 + 7/rally` baseline is too weak according to playtest.

For Feel Pass 1, deliberately move toward a faster arcade cadence while keeping the first return readable.

Starting hypotheses to test statically/build around:
- BaseSpeed: approximately `70–80` studs/s;
- SpeedPerRally: approximately `10–14` studs/s;
- MaxSpeed: approximately `240–280` studs/s.

Choose coherent values in that range; centralize them.

Do not simply make the first ball lethal-fast. The intended curve is:
- first incoming ball: obvious/readable;
- first successful redirect: clearly stronger/faster than the incoming ball;
- rallies 2–5: rapidly become exciting;
- later rally: high pressure.

If a linear function cannot produce this feel cleanly, a tiny two-stage or multiplicative function is acceptable, but keep it understandable. Do not recreate a large tuning system.

### 7. Redirect must communicate FORCE
On Player parry, the ball should not feel like it gently changes destination.

Preserve immediate authoritative redirect, but make the outgoing event feel decisive:
- outgoing direction should establish immediately toward the other combatant;
- speed escalation applies immediately;
- visual trail can react instantly;
- optional tiny local camera/FOV impulse is acceptable;
- optional very short hit-stop-like presentation on the client is acceptable ONLY if it does not delay authority/input.

No giant VFX. No screen obstruction. We want kinetic force, not spectacle.

### 8. Keep Player parry simple
Do NOT make the Player parry harder in this sprint.

Keep the simple V2 semantics and approximately generous defensive radius unless testing/code inspection exposes a concrete bug. We already proved this version can connect; preserve that gain.

No frontal arc. No sword-tip collision. No active/recovery state machine. No TTI gate for the Player.

### 9. Camera/readability
Do not build a camera system. Only fix obvious readability issues.

At duel start, the default view must make opponent/ball direction obvious. On successful parry, a very small short-lived feedback impulse is allowed. No constant shake and no aggressive FOV animation.

### 10. Preserve engineering invariants
- exactly one Player combatant;
- exactly one TrainingOpponent;
- exactly one authoritative ball;
- server authoritative success;
- Player/NPC same `TryParry`;
- swept hurt collision;
- deterministic reset;
- no accumulated connections;
- `CombatDebug = false` by default.

## Required verification
Update focused tests only for changed invariants:
- NPC intentional miss chance is zero in Combat Lab;
- NPC can reliably trigger the shared parry path across representative ball speeds;
- ball asset/part visible size matches intended dimensions after build;
- duel spawn orientations face each other;
- normal UI does not instantiate/show rejected overlays;
- speed curve values are bounded by max;
- existing one-ball/reset/parry tests continue passing.

Static verification is NOT approval of feel.

## Human acceptance test
The next candidate is ready for human evaluation when:
1. Spawn/reset immediately points the Player into the duel.
2. The ball visually reads SMALL, not like a large black sphere beside the avatar.
3. NPC reliably returns every valid ball during training; rallies normally end because the Player misses.
4. Screen is clean enough that the ball is the primary information source.
5. First ball is readable but noticeably more energetic than the previous candidate.
6. Player parry immediately produces a stronger/faster return.
7. By rallies ~3–5 the exchange clearly feels faster and more exciting.
8. Player can still successfully parry with the simple V2 rule.
9. Miss/hit/reset remain coherent and fast.
10. No red runtime errors during the normal loop.

The human tester decides whether Feel Pass 1 passes.

## Frozen scope
No inventory, lootboxes, shop, economy, DataStore, powers, abilities, dash, cosmetics, ranked, quests, battle pass, finishers, social systems, additional NPCs, final map art, lobby expansion or cinematic polish.

## Completion report
Keep it short.

### Git
branch + pushed SHA.

### Ball visual root cause
Why `Radius = 0.85` still looked huge and exact fix.

### NPC reliability
How 100% training parry is achieved while still using shared `TryParry`.

### Orientation / UI
What changed to make the duel immediately readable and screen clean.

### Feel tuning
Only changed speed/redirect/camera values and rationale.

### Verification
Tests actually executed and results.
`RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human action
Open the correct V2 `Fatal.rbxlx` and test 10–20 rallies.

STOP. Do not add features and do not self-approve.