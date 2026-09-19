# FATAL — AI Handoff

> Git is the source of truth. Human Studio playtest is the authority for gameplay quality.

## STATUS
**RUNTIME BREAKTHROUGH CONFIRMED — FOUNDATION SPRINT AUTHORIZED**

The latest clean runtime test produced the first clear positive signal: the test loop ran successfully in Studio and sustained a very high rally (`RALLY 130` observed). This proves the fundamental exchange loop can now remain alive long enough to evaluate and develop.

This is NOT gameplay approval. The visible runtime is still prototype-grade and the project urgently needs structure, readability, impact, and maintainable foundations.

User constraint: Codex budget is limited (~40% remaining). Optimize for leverage and avoid broad feature work or speculative rewrites.

## DECISION
Stop restarting combat from scratch.

We now have evidence that the core exchange can run. Preserve the working runtime behavior and convert the prototype into a strong combat foundation with the minimum code necessary.

Do not spend this sprint on inventory, lootboxes, progression, powers, cosmetics, final map art or product systems.

## NEXT TASK — FOUNDATION SPRINT: COMBAT VERTICAL SLICE

Continue on `codex/combat-core-v2`. Fetch `origin/main`, read this handoff, and incorporate the handoff update without merging implementation into main.

The sprint has four priorities, in this order:

1. **Combat correctness and state model**
2. **Player readability and hit/parry feedback**
3. **R15 weapon/animation integration seam**
4. **Architecture for future systems without implementing them**

### 1. Freeze the working exchange as a regression baseline
Before refactoring, capture the currently working behavior in focused tests/invariants:
- exactly one authoritative ball;
- exactly one Player + one TrainingOpponent in Combat Lab;
- shared server-authoritative parry path;
- NPC can sustain long rallies deterministically in training mode;
- rally count increments exactly once per confirmed parry;
- one confirmed parry cannot double-redirect;
- one body hit cannot double-eliminate;
- reset cannot duplicate connections/ball/NPC;
- current clean build remains free of rejected legacy UI.

Do not encode subjective feel values as permanent tests. Test invariants, not arbitrary tuning.

### 2. Establish explicit combat states
The runtime should expose a small authoritative duel state model, not scattered booleans.

Use a compact enum/state concept approximately:
`Waiting -> Countdown -> Active -> Eliminated/Ending -> Resetting`

Do NOT rebuild the old parry Active/Recovery state machine. This state model is for the DUEL lifecycle only.

Transitions must be centralized and observable. Ball simulation/parry/hit must reject actions outside `Active`.

### 3. Formalize combat events
Create/clean a minimal event contract between server and client. Prefer a single clear combat event channel or a very small set of remotes.

Required semantic events:
- `DuelStateChanged`
- `BallTargetChanged`
- `ParryConfirmed`
- `CombatantHit`
- `RallyChanged`

Payloads should be minimal and versionable. Do not stream redundant per-frame gameplay state through remotes.

Server remains authoritative. Client events are presentation signals, never proof of success.

### 4. Build a real hit/parry feedback layer
The working loop currently proves mechanics but not quality.

On `ParryConfirmed`, client presentation should have synchronized micro-feedback:
- immediate readable ball redirect;
- short high-contrast ball/core flash;
- trail pulse/stretch;
- clean impact/parry sound hook;
- short weapon animation hook;
- subtle camera impulse (small, no constant shake).

On `CombatantHit`:
- brief victim/world hit flash;
- distinct hit sound hook;
- ball visibly terminates/locks at impact instead of ambiguously passing through;
- duel state advances once;
- quick clean reset.

No giant text, no CRITICAL/TTI overlays, no screen-filling effects.

### 5. Improve ball readability without re-breaking timing
Do not radically change the now-working timing in the same sprint.

Keep current proven travel behavior unless there is a correctness defect. Improve visual tracking instead:
- compact but readable core;
- high contrast against both sky and dark floor;
- restrained trail showing direction;
- target-only subtle intensity increase near defensive range if already architecturally clean.

Ball visual size, hurt radius and Player defensive radius remain separate concepts.

### 6. R15 weapon integration seam
The game is R15 and future weapons must not require rewriting combat.

Create a clean `WeaponDefinition`/`WeaponPresentation` boundary (names may differ) where a weapon can provide:
- model/asset reference;
- grip/attachment metadata;
- idle/equip/parry animation IDs or hooks;
- parry sound/VFX presentation metadata.

IMPORTANT: weapon mesh/hitbox must NOT determine authoritative parry success. Weapons are presentation/identity over the combat mechanic.

Implement only ONE placeholder/test weapon through this seam. Do not build inventory or multiple weapons.

### 7. Input abstraction
Keep PC inputs working, but route intent through a tiny input/action layer so mobile/console can be added later without touching CombatCore.

Current baseline may remain MouseButton1 + F. The server receives only semantic `ParryIntent`.

Do not implement mobile/console UI in this sprint.

### 8. Central tuning schema
Consolidate gameplay tuning into one clear config with grouped concepts:
- Ball movement;
- Parry opportunity/forgiveness;
- Rally progression;
- NPC training behavior;
- Feedback intensity/durations;
- Duel/reset timing.

Remove dead/rejected knobs from previous architectures. Every remaining tuning field must be read by runtime or deliberately documented as reserved.

### 9. Observability without visual pollution
Add a development-only compact telemetry path that can report per parry/hit:
- rally;
- speed;
- distance at input;
- immediate vs buffered result if buffer exists;
- reject reason;
- hit target;
- duel state.

No per-frame spam. No debug UI in normal runtime. One toggle, OFF by default.

### 10. Future architecture — interfaces only
Prepare obvious extension points, but DO NOT implement their systems:
- `WeaponService` / weapon definitions;
- `Combatant` abstraction capable of Player/NPC;
- `Round/DuelService` lifecycle;
- presentation events suitable for future abilities/cosmetics;
- target-selection function that can later support >2 combatants.

Do not create empty enterprise abstractions or dozens of placeholder modules. Add a seam only when the current vertical slice already touches that responsibility.

### 11. Project structure target
Keep the hot path easy to trace. A reasonable shape is approximately:

`src/shared/Config/CombatConfig`
`src/shared/Combat/CombatTypes`
`src/shared/Weapons/WeaponDefinitions`
`src/server/Combat/CombatCore`
`src/server/Combat/BallService`
`src/server/Combat/CombatantService`
`src/server/Combat/TrainingOpponent`
`src/server/Duel/DuelService`
`src/server/Weapons/WeaponService`
`src/client/Input/CombatInputController`
`src/client/Combat/CombatPresentationController`
`src/client/Weapons/WeaponPresentationController`

Do NOT churn filenames merely to match this example. Refactor only when it materially improves ownership/dependencies.

### 12. Performance and networking
Keep one authoritative simulation path. No per-ball/per-NPC heartbeat connections if a centralized update already exists.

Avoid remote spam. Presentation should interpolate locally where appropriate; server sends semantic events/snapshots only as needed.

Do not prematurely optimize beyond obvious hot-path issues.

## DEFINITION OF DONE
This sprint is complete when:
1. Current long-rally capability is preserved.
2. Duel lifecycle has explicit centralized states.
3. Parry/hit/rally/target/state presentation events have clear contracts.
4. Player gets unmistakable but clean parry and hit feedback.
5. One R15 placeholder weapon runs through a reusable presentation seam.
6. Input intent is decoupled from keyboard/mouse specifics.
7. Tuning is centralized and dead knobs removed.
8. Debug telemetry is useful and OFF by default.
9. Clean build verification prevents legacy contamination.
10. No inventory/lootbox/power/product scope entered.

## VERIFICATION
Run existing compile/build/audit tests plus focused invariants added above.

If Studio runtime cannot be executed, state `RUNTIME NOT TESTED`. Do not infer feel from tests.

Preserve the canonical `Fatal.rbxlx` build workflow. Human test must be performed with the generated place and without Rojo live-sync unless explicitly testing the Rojo workflow.

## COMPLETION REPORT
Keep it compact to save budget.

### Git
branch + pushed SHA.

### Foundation
state model + event contract + module ownership changes.

### Combat feedback
parry/hit presentation implemented.

### Weapon seam
one placeholder R15 weapon and integration boundary.

### Regression
long-rally/invariant results.

### Verification
commands/results + `RUNTIME TESTED` or `RUNTIME NOT TESTED`.

### Human test
shortest exact Studio test procedure.

### Next recommendation
ONE highest-leverage next step only.

Then STOP. Do not implement the recommendation.