# FATAL — AI Handoff

> This file is the execution contract between the architect/reviewer and Codex. Codex reads it before implementation. Codex must not mark its own work approved or advance the gate. The reviewer updates this file after repository review and Studio evidence.

## Status
**COMBAT LAB LOCK — ACTIVE**

No new product features until the core 1v1 is explicitly approved after Roblox Studio playtesting.

## Product objective
FATAL is currently a combat laboratory, not a content-complete game.

The only experience that matters in this gate is:

`1 Player -> 1 TrainingOpponent (R15) -> 1 authoritative ball -> target -> parry -> redirect -> rally -> hit/elimination -> fast clean reset -> repeat`

The loop should be good enough to play repeatedly for several minutes because the interaction itself feels precise, responsive, readable and satisfying — not because VFX hides weak mechanics.

## Active gate
### Combat Lab Quality Gate
Focus only on:
- deterministic Combatant lifecycle;
- exactly one Player and one TrainingOpponent participating;
- exactly one authoritative gameplay ball;
- server-authoritative parry validation;
- continuous/swept collision at high ball speeds;
- separate hurt volume and parry volume/window;
- approach direction and parry arc validation;
- stable ball simulation across frame rates;
- momentum-aware homing and redirect;
- rally/speed progression;
- bounded latency tolerance and stale-request protection;
- NPC using the same `CombatService:TryParry` path as a Player;
- idempotent cleanup/reset;
- minimal clean HUD/camera/VFX;
- strong debug instrumentation for tuning.

## Blocking runtime issue
Latest real Studio evidence showed:

`ServerScriptService.Game.Combat.CombatantService:17: duplicate combatant id: P:<UserId>`

Observed stack:
- `CombatantService:_register`
- `CombatantService:RegisterPlayer`
- `RoundService:_readyPlayer`
- `RoundService:_prepare`
- `RoundService:Update`
- `GameServer`

This is a blocker.

### Required root-cause rule
Do not merely ignore duplicate registration.

Registration and round preparation must be separate lifecycle concepts.

Expected direction:
- `PlayerAdded -> RegisterPlayer` once for server membership;
- round preparation retrieves/rebinds/resets the existing Combatant;
- respawn updates character references without creating a second logical Player Combatant;
- `PlayerRemoving -> Unregister`;
- TrainingOpponent is registered once for its lifetime and unregistered when destroyed.

Codex must inspect the actual current lifecycle and implement the correct solution rather than blindly matching this sketch.

## Combat Lab mode
Provide a development configuration such as `CombatLab = true`.

When enabled in Studio:
1. Player becomes ready.
2. Exactly one R15 `TrainingOpponent` exists.
3. Exactly one gameplay ball exists while combat is active.
4. Combat begins quickly without a long lobby/intermission.
5. On elimination, cleanup occurs.
6. After a short reset (~1.5s is a starting point), the same test loop can run again.
7. Repeating the loop must not accumulate Combatants, NPCs, balls, connections, callbacks, or stale state.

## Test arena
Keep the arena deliberately simple during this gate:
- flat readable floor;
- simple collision walls;
- roughly 100–140 studs across;
- Player/NPC initial separation roughly 35–50 studs;
- no decorative geometry that obscures collision or trajectory.

Gameplay quality is the purpose of this arena.

## Ball invariants
- Server owns gameplay truth.
- Exactly one authoritative gameplay ball during active Combat Lab combat.
- Zero stale authoritative balls after cleanup.
- Ball state should expose concepts equivalent to position, velocity/current direction, desired direction, speed, target, rally count, and revision.
- Do not use `Touched` as the sole hit authority.
- Movement and collision must not depend materially on client FPS.

### Continuous collision
Use swept/continuous collision from previous to next simulated position, including the ball radius. High-speed tests must not tunnel through the target.

Test at minimum the mathematical behavior around 50, 100, 150, 200, 250 and 300 studs/s.

## Hurt geometry
Hurt detection and parry detection are different systems.

For R15 competitive consistency, use a predictable mathematical body volume (for example a capsule/cylinder-style approximation around torso/root) rather than per-limb physics as gameplay authority.

Centralize tuning values such as:
- ball radius;
- player hit radius;
- player hit height.

The chosen model and values must be documented in the implementation report.

## Parry geometry and timing
Parry validation should account for:
- participant alive/eligible;
- current target;
- round/lab state;
- ball revision;
- cooldown/state machine;
- proximity;
- ball approaching the defender;
- a coherent frontal defensive arc;
- timing/window/buffer;
- bounded latency tolerance.

Starting tuning targets (not immutable requirements):
- range: ~10–12 studs;
- defensive arc: ~150–180 degrees;
- input buffer: ~0.06–0.08s;
- maximum bounded latency compensation: ~0.10–0.12s.

Do not make physical sword contact the gameplay authority. Animation represents the action; server mathematics decides success.

## Parry state
Prefer an explicit state model equivalent to:
`Idle -> Active -> Recovery -> Cooldown -> Idle`

Avoid contradictory boolean state spread across modules.

## Ball revision / stale requests
Every meaningful redirect/parry state change must invalidate stale parry attempts through a revision/token or equivalent mechanism. A delayed request must not parry a ball state that has already been redirected.

## Homing and redirect
The ball must not snap its direction directly to `HumanoidRootPart` every frame.

Maintain current and desired direction, with bounded convergence. At higher speed, avoid impossible-looking curvature. Limited target-velocity leading may be used, but do not create perfect predictive aimbot behavior.

On successful parry, the redirect should feel forceful: establish the new target/direction strongly, then let normal homing continue while retaining coherent momentum.

## Rally
Speed progression should be centralized and non-linear rather than an unbounded constant increment.

Desired feel:
- rally 0–3: controlled/readable;
- 4–8: clearly fast;
- 9–14: very fast;
- 15+: extreme but still deterministic.

A starting max-speed exploration range around 240–280 studs/s is acceptable, but tuning must be based on playtesting rather than treating these numbers as final.

## TrainingOpponent
Exactly one NPC during this gate.

It must:
- be R15;
- use the Combatant abstraction;
- become the real ball target;
- use the same server combat rules as the Player;
- call an internal authoritative path such as `CombatService:TryParry`, never fake a redirect and never use a client RemoteEvent;
- use TTI/closing velocity/reaction delay/timing variance rather than a perfect distance trigger;
- be capable of both successful parries and believable mistakes;
- use only minimal movement/short repositioning during this gate.

For 1v1 targeting, a successful Player parry targets the NPC and a successful NPC parry targets the Player. Preserve an API that can later support more Combatants without adding them now.

## TTI / approach
For threat estimation, account for closing velocity rather than using only `distance / speed`.

Conceptually:
- derive vector to target/contact volume;
- project ball velocity toward it;
- if closing speed is non-positive, the ball is not directly approaching;
- use distance-to-contact / closing speed for approximate TTI.

TTI can inform NPC decisions, UI and debugging. It is not a substitute for authoritative swept hit detection.

## Minimal presentation
Do not hide mechanics behind spectacle.

During this gate:
- clean ball core + readable trail;
- short parry flash/ring;
- short hit feedback;
- base FOV around 70;
- small parry FOV punch;
- very light critical-target feedback;
- minimal HUD: rally and discreet target state; optional TTI in debug.

No cinematic polish sprint yet.

## Required debug instrumentation
Provide a `CombatDebug` development toggle.

When enabled, make the combat math inspectable where practical:
- ball radius;
- hurt volume;
- parry range/arc;
- current target;
- velocity vector;
- closing velocity;
- TTI;
- rally count;
- ball revision;
- parry state.

Parry attempts should produce one controlled diagnostic record with a standardized reason such as:
`NOT_TARGET`, `DEAD`, `COOLDOWN`, `TOO_EARLY`, `TOO_LATE`, `OUT_OF_RANGE`, `OUTSIDE_ARC`, `NOT_APPROACHING`, `STALE_REVISION`, `ACCEPTED`.

Do not log per-frame spam.

## Required automated/static tests
Add or maintain focused tests for:
1. swept/segment collision math;
2. ball vs hurt-volume collision;
3. parry arc;
4. closing velocity;
5. TTI;
6. wall reflection;
7. high-speed collision/tunneling;
8. ball revision/stale attempt;
9. duplicate parry protection;
10. parry state transitions;
11. Combatant registration lifecycle;
12. Combat Lab cleanup/reset;
13. trajectory/hit behavior across representative 30/60/120/144 FPS timesteps.

Static tests are necessary but never substitute for Studio runtime testing.

## Studio acceptance tests
The reviewer/user will run these after implementation:

A. Enter Combat Lab and see exactly one TrainingOpponent.
B. Exactly one gameplay ball exists.
C. Ball targets the Player correctly.
D. Player parry responds immediately and redirects to NPC.
E. NPC can parry through the same combat rules.
F. A rally can continue repeatedly and speed grows predictably.
G. Lateral movement does not produce obviously incorrect hits.
H. Clearly early parry is rejected appropriately.
I. Clearly late parry is rejected appropriately.
J. Invalid rear/out-of-arc parry is rejected appropriately.
K. Visual contact and authoritative hit remain coherent.
L. High-speed ball does not tunnel through a target.
M. Wall bounce remains deterministic and readable.
N. Elimination triggers a fast clean reset.
O. Repeat at least 20 resets without duplicate Combatants/NPCs/balls/connections.
P. Roblox Studio Output contains zero red runtime errors during the normal loop.
Q. Later latency tuning will be checked under 0/50/100/150ms network conditions; do not claim this is validated unless actually tested.

## Explicitly frozen scope
Until this gate is approved, do not implement or expand:
- inventory;
- lootboxes;
- shop;
- currency/economy;
- DataStore progression;
- abilities/powers;
- dash;
- skins/rarities;
- ranked;
- quests;
- battle pass;
- finishers;
- social systems;
- complex lobby;
- final arena art;
- additional NPCs;
- cinematic polish intended to mask core feel problems.

Existing unrelated code does not need destructive deletion merely to satisfy this list, but it must not distract from or interfere with Combat Lab.

## Next task
**Fix the duplicate Player Combatant lifecycle bug first, then implement/refine the Combat Lab described above. Do not advance beyond this gate.**

Before coding, inspect the current repository implementation and identify the real root cause of duplicate registration. Preserve good existing work where compatible rather than rewriting blindly.

## Codex completion report contract
When this task is complete, report:

### Duplicate Combatant
Exact root cause and lifecycle correction.

### Combat Lab
How it starts, resets and guarantees one NPC/one ball.

### Hit Detection
Exact mathematical model and continuous collision approach.

### Hurt Volume
Shape/dimensions/current tuning.

### Parry Volume
Range, arc, timing, approach validation and state model.

### Ball Simulation
Timestep/substep strategy and high-speed behavior.

### Redirect / Homing
Current algorithm and tuning points.

### Latency
What is implemented versus what still requires Studio network emulation.

### TrainingOpponent
Reaction/decision model and confirmation that it uses the shared combat path.

### Debug
How to enable it and interpret rejection reasons/geometry.

### Tests
Only tests actually executed, with results.

### Runtime
Write exactly one:
- `RUNTIME TESTED: <how and evidence>`
- `RUNTIME NOT TESTED`

### Files changed
Exact list.

### Current tuning
Central parameters and values.

### Known problems
Real unresolved problems only.

Stop there. Do not implement a next feature or self-approve the Combat Lab gate.
