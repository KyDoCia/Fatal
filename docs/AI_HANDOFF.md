# FATAL — AI Handoff

> Execution contract between reviewer/architect and Codex. Git is the source of truth.

## Status
**COMBAT LAB LOCK — HUMAN PLAYTEST FAILED / TARGETED FEEL FIX REQUIRED**

Do not add features. Do not merge `codex/combat-lab-recovery` into `main`. Do not perform visual/content work. The human tester cannot reliably make contact/parry the ball and reports that the ball is visibly too large and the gameplay is still very poor.

## Reviewed implementation
Working implementation branch: `codex/combat-lab-recovery`.
Latest human-test candidate reported by Codex: `91685f4e07abd3c1ea6ed0e5dbc43edaaeb6e00f`.

Architectural foundations previously audited should be preserved unless they directly cause the feel defect: persistent Player Combatant identity, one TrainingOpponent, one authoritative ball, shared Player/NPC combat path, swept collision, centralized tuning, deterministic cleanup and reentrancy protection.

## Human evidence — authoritative for this sprint
Baseline Studio feedback:
- tester can barely/never successfully hit or parry the incoming ball;
- ball appears much too large;
- gameplay feel is still unacceptable.

This is enough evidence to stop preserving the current parry tuning. The previous values were hypotheses and have failed the first human feel test.

## Diagnosis to investigate, not blindly assume
The current design arms an `Active` parry on input and may only confirm later when contact geometry reaches `TryConfirm`. That separation can make click-to-deflect feel disconnected or make a visually reasonable attempt fail because range/arc/window/approach/revision/contact timing do not overlap as expected.

The current ball radius of 2.25 studs is also visually/gameplay-wise oversized for this duel according to the tester. Reduce it substantially and keep visual radius aligned with authoritative collision radius unless there is an explicitly documented small readability offset.

## NEXT TASK — make the parry connect
This is a targeted gameplay correction sprint. Do not redesign the entire game.

### 1. Sync safely
Continue on `codex/combat-lab-recovery`. Fetch current `origin/main`, read this handoff, and bring the handoff change into the branch without merging implementation into main.

### 2. Reduce the ball size
Make the gameplay ball clearly smaller. Start around `Radius = 1.0–1.25` studs; choose one value based on the existing visual construction and keep authoritative collision/visual presentation coherent.

Do not compensate for a smaller visible ball by secretly keeping a giant collision sphere.

### 3. Fix the core parry interaction
The primary UX target is simple:

When the player presses parry at the visually correct moment while the targeted ball is approaching within a reasonable defensive zone, the ball should deflect immediately and predictably.

Audit the complete path:
`Input -> ParryRequest -> TryRequest -> armed state -> ball simulation/contact -> TryConfirm -> redirect`.

Instrument/reason through why a normal human attempt currently almost never succeeds.

Prefer simplifying the confirmation model if the delayed `Active -> later contact confirmation` architecture is causing disconnection. A valid solution may use a short server-authoritative temporal grace/buffer around a spatially valid approaching ball, but do not create autoparry and do not trust the client for success.

The successful visual deflection should occur effectively at the moment the player perceives the parry, not noticeably later after the input.

### 4. Make baseline timing intentionally learnable
This is a training duel. Tune the first rallies for learnability before difficulty.

Use human-friendly starting hypotheses, then centralize them:
- defensive distance/range large enough to react without requiring sword-tip precision;
- frontal arc generous enough that normal facing works;
- short but meaningful timing window;
- early rally ball speed slow enough to read;
- NPC must not immediately force an impossible return.

Do not require physical sword/ball mesh intersection. The weapon is presentation; authoritative parry is timing + approach + spatial validity.

### 5. Separate visible ball size from fair defensive opportunity
A smaller ball does NOT mean parry becomes pixel-perfect. Keep the ball visually compact while the parry defensive zone remains forgiving and mathematically explicit.

Hurt volume must remain fair: do not enlarge player hit detection to compensate for the smaller ball.

### 6. Immediate success feedback
On accepted parry, redirect/feedback must begin immediately enough that the player understands `my input caused that`.

Do not add spectacle. A small flash/trail response is enough. Fix causality before VFX.

### 7. NPC for testing, not winning
Keep exactly one TrainingOpponent. For this sprint, make it a useful rally partner rather than a difficult opponent. Its early reaction/timing should allow several exchanges so the Player can learn the mechanic and expose higher-speed behavior.

Do not give the NPC a separate easier combat rule; it still uses the same authoritative parry path. Only its decision timing may be tuned.

### 8. Debug the failed attempts
With `CombatDebug = true`, a failed attempt must tell us why in one concise record: phase, reason, distance, closing/TTI when useful, revision. No per-frame spam.

Pay special attention to whether human attempts are failing as `TOO_EARLY`, `TOO_LATE`, `OUT_OF_RANGE`, `OUTSIDE_ARC`, `NOT_APPROACHING`, or due to revision/contact sequencing.

### 9. Keep scope frozen
Do NOT implement inventory, lootboxes, shop, economy, abilities, powers, dash, cosmetics, ranked, quests, map art, lobby work, additional NPCs, cinematic polish, or any unrelated system.

## Required static checks
Preserve/run existing verification and add/update focused tests only where necessary for the corrected parry semantics and smaller ball. Static tests are not gameplay approval.

## Human acceptance test
Prepare a build where the tester can:
1. spawn against exactly one TrainingOpponent;
2. clearly see a smaller ball;
3. successfully parry the first incoming ball after a few intuitive attempts, without learning hidden timing rules;
4. immediately perceive the ball redirect on a successful input;
5. sustain several Player/NPC exchanges at low rally;
6. intentionally press clearly too early/late and observe failure;
7. miss the ball and receive a visually coherent hit;
8. reset quickly and repeat;
9. enable `CombatDebug` only when diagnosing a failure.

The sprint is NOT approved until the human tester says the basic interaction is materially better.

## Completion report
Keep it short:

### Git
branch + pushed SHA.

### Root cause
Why normal human parry attempts were failing in the previous candidate.

### Parry correction
Exact semantic/flow change; do not just list numbers.

### Tuning
Ball radius and only the combat/NPC values changed in this sprint.

### Verification
Commands/tests actually executed.
`RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human test
One-line instruction to open the correct FATAL build and test the first 5–10 rallies.

Then STOP. No next feature.