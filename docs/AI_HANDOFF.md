# FATAL — AI Handoff

> Execution contract between reviewer/architect and Codex. Git is the source of truth.

## Status
**COMBAT LAB LOCK — IMPLEMENTATION AUDITED / RUNTIME FEEL GATE ACTIVE**

Do not add features. Do not merge `codex/combat-lab-recovery` into `main` yet. Do not self-approve gameplay feel.

## Reviewed candidate
Branch: `codex/combat-lab-recovery`
Candidate commit: `d28227fe1bb270590aa76b1af9a2e5fa40c73b2f`
Base reviewed: `origin/main` at `3de88142044ac557071fa3d82fc7966d68baddff`

The reviewer inspected the actual branch implementation, including `BallService`, `CombatService`, `CombatantService`, `RoundService` and combat configuration. Repository recovery is complete enough to leave the recovery phase. The next blocker is no longer repository provenance; it is real gameplay/runtime feel.

## Audit findings to preserve
The candidate contains several foundations worth preserving unless Studio evidence proves otherwise:
- Player registration identity is separated from round character binding/reset.
- `RoundService` has a reentrancy guard around its update path.
- Combat Lab is reduced to the Player / TrainingOpponent duel.
- Ball ownership is centralized and duplicate authoritative-ball creation is guarded.
- Player and NPC share the authoritative combat/parry service path.
- Hit detection is based on swept/continuous geometry rather than `Touched` alone.
- Cleanup paths explicitly stop the ball, clear NPCs and reset participant state.
- Combat tuning is centralized rather than scattered through gameplay modules.

These are architectural foundations, not proof that the game feels good.

## Important audit concern: parry feel
The current parry model is deliberately NOT approved yet.

Current implementation accepts an input into an `Active` state, records an armed ball revision, and may confirm the parry later through `TryConfirm` when the ball reaches valid contact geometry. Therefore perceived timing is produced by the interaction of:
- `Range`;
- `ArcDegrees`;
- `ActiveWindow`;
- `InputBuffer`;
- latency compensation;
- closing speed;
- ball revision;
- later contact/confirmation.

This can be a valid architecture, but it can also create a disconnected feeling where the player's click and the visible deflection do not feel like the same event. Studio playtesting must decide this. Do not add more timing machinery before testing it.

Current values such as `Range = 11`, `ArcDegrees = 165`, `ActiveWindow = 0.24`, `InputBuffer = 0.07`, `Cooldown = 0.58`, ball radius `2.25`, hurt radius `2.35`, `BaseSpeed = 55`, `MaxSpeed = 270` and `RallyGrowth = 0.11` remain hypotheses only.

## Product rule
**No new feature until Player <-> Ball <-> TrainingOpponent is genuinely satisfying.**

Frozen: inventory, lootboxes, shop, economy, DataStore progression, powers, abilities, dash, cosmetics, ranked, quests, battle pass, finishers, social systems, additional NPCs, final map art, cinematic polish and lobby expansion.

## NEXT TASK — runtime feel validation build
Do NOT redesign the combat again from static reasoning.

Prepare the existing candidate for the shortest possible HUMAN Studio tuning session.

### 1. Synchronize safely
Start from `codex/combat-lab-recovery` at candidate commit `d28227fe1bb270590aa76b1af9a2e5fa40c73b2f`.
Fetch `origin/main` and read this updated handoff. Bring only this handoff change into the working branch as appropriate. Do not merge the implementation into main.

### 2. Do not broaden implementation
Do not add systems. Do not rewrite BallService/CombatService merely to appear productive. Only make changes required to make the runtime test reliable, immediate and observable.

### 3. Make normal playtest clean
Default Studio playtest must show exactly:
- one Player;
- one `TrainingOpponent` R15;
- one gameplay ball;
- minimal readable arena;
- minimal combat UI/feedback;
- fast restart after a miss.

Debug geometry/logging must be OFF by default but easy to enable with one config toggle.

### 4. Make tuning observable
When `CombatDebug = true`, ensure one parry attempt can be understood without per-frame spam. The tester needs concise evidence for:
- ACCEPT/REJECT;
- rejection reason;
- distance;
- TTI/closing speed when applicable;
- ball revision;
- current parry phase.

If these already work correctly, preserve them rather than rewriting.

### 5. Do not tune blindly
Do not change parry range/window/arc, hurt volume, speed curve, turn rate, redirect momentum or NPC timing unless required to fix an objective runtime defect discovered while preparing the test.

The human tester will provide observations such as:
- parry feels early/late;
- click-to-deflect feels disconnected;
- hit feels larger/smaller than visual body;
- ball curves unnaturally;
- redirect lacks force;
- rally accelerates too slowly/quickly;
- NPC feels impossible/trivial;
- reset breaks after repetitions.

Those observations will drive the next tuning commit.

### 6. Runtime truth
If you cannot actually launch Roblox Studio, state `RUNTIME NOT TESTED`. Static verification does not become runtime evidence.

## Human test protocol
The build should make this easy:

1. Open the canonical FATAL checkout/`Fatal.rbxlx` in Roblox Studio.
2. Press Play.
3. Confirm exactly one TrainingOpponent and one ball.
4. Play at least 10–20 duel resets at normal network conditions.
5. Judge only: input response, visible parry timing, hit fairness, trajectory, redirect force, rally pacing, NPC timing, reset reliability.
6. If something feels wrong, enable `CombatDebug` and reproduce it; capture the rejection reason/metrics rather than guessing.
7. Only after baseline feel is understandable should latency emulation at 50/100/150 ms be attempted.

## Acceptance
This gate cannot be approved by Codex.

It advances only after human Studio feedback confirms either:
A. the baseline duel feels good enough to tune incrementally, or
B. specific reproducible feel defects are identified with enough evidence for a targeted tuning/fix sprint.

## Completion report
Keep it extremely short:

### Git
branch + pushed SHA.

### Test readiness
exactly what the human should open and whether debug defaults OFF.

### Changes
only changes actually necessary after reading this handoff; `none` is acceptable.

### Verification
static commands actually run and result.
`RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human action
one-line instruction to start the duel.

Then STOP. Do not propose or implement another feature.