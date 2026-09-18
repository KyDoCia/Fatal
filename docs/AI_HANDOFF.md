# FATAL — AI Handoff

> Git is the source of truth. Human Studio playtest is the authority for gameplay quality.

## STATUS
**COMBAT CORE V2 — GAMEPLAY REJECTED / HIT-CONFIRM LOOP REQUIRED**

The clean/minimal runtime exposed the real gameplay problem instead of solving it.

Latest human evidence:
- ball is now too small;
- ball is extremely fast;
- human perceives effectively zero realistic chance to parry;
- there is no satisfying/legible hit-confirm system;
- overall gameplay remains rejected.

Do not add product features. Do not merge to main. Do not add complexity to hide the failure.

## WHAT WE LEARNED
Previous iterations oscillated between extremes:
- oversized/slow/noisy;
- then tiny/fast/empty.

This means we have been tuning isolated parameters rather than designing a coherent perception-action loop.

The next task is NOT `make ball bigger` or `make speed slower` independently. Design the complete loop:

`SEE incoming threat -> ANTICIPATE contact -> PRESS parry -> RECEIVE immediate hit-confirm -> UNDERSTAND redirect -> PREPARE next return`.

Every number and visual in the next candidate must serve this loop.

## NEXT TASK — COMBAT FEEL V3: READ -> PARRY -> HIT-CONFIRM

Continue on `codex/combat-core-v2` unless the branch has become unsafe. Preserve the simple server-authoritative TryParry architecture and clean runtime. Do not resurrect old overlays/state machines.

### 1. Establish readable duel timing from distance, not arbitrary speed
Audit actual Player/NPC spawn separation and calculate travel time.

For the FIRST incoming ball, target approximately `0.9–1.15 seconds` of readable travel from launch to the Player's defensive zone.

Do not pick BaseSpeed in isolation. Compute it from actual launch distance so the human receives roughly this reaction budget.

After successful parries, accelerate progressively, but do not jump immediately from readable to impossible.

Target feel envelope for early rally:
- initial approach: learnable;
- rally 1: clearly faster but comfortable;
- rally 2–3: engaging;
- rally 4–6: demanding;
- later: high pressure.

Keep the speed function small and understandable. Tune from desired travel time at the actual arena separation.

### 2. Ball visual size = readable, not giant and not tiny
The previous candidate was too large; the latest clean candidate is too small.

Choose a middle visual diameter approximately `1.8–2.2 studs` as the next hypothesis.

Do NOT make authoritative hurt collision equally huge. Visual readability, hurt collision and defensive parry radius are separate concepts.

Use a high-contrast ball core with a restrained trail so motion direction is legible. Avoid a featureless black sphere that disappears against dark backgrounds.

### 3. Introduce a real HIT-CONFIRM system
A successful parry must be unmistakable within a fraction of a second without covering the screen.

Implement a compact `ParryConfirmed` feedback event from the authoritative success path.

On confirmed Player parry, combine a few synchronized micro-feedback elements:
- immediate ball direction change;
- brief ball brightness/core flash;
- trail pulse/stretch for roughly 0.08–0.15s;
- short clean impact/parry sound hook;
- very small camera impulse or FOV kick, optional and subtle;
- weapon/parry animation hook if available, but never make animation timing authoritative.

The feedback must begin on confirmed success and clearly communicate `I hit that`.

No giant text. No CRITICAL. No hitmarker covering the center. No long animation lock.

### 4. Add a readable PRE-CONTACT cue, not an answer button
The player currently has effectively zero chance to judge the moment at high speed.

For the current target only, add one subtle world-space cue that intensifies as the ball enters the parry opportunity region. Prefer the ball itself changing slightly (core brightness/trail intensity) rather than UI text.

The cue should answer `danger is entering my defensive zone`, not `press now automatically`.

No countdown number, TTI label, FIGHT text, giant target marker or floor marker.

### 5. Player parry forgiveness
Keep immediate server evaluation, but add ONE simple form of temporal forgiveness if necessary for human input/network timing.

Preferred baseline: a small early input buffer around `0.10–0.14s` ONLY when the Player is the current target and the ball is approaching. If Player presses just before the ball enters defensive range, remember the intent briefly and consume it immediately when the ball crosses the valid defensive radius.

This must remain simple:
- one pending timestamp/expiry;
- one consume opportunity;
- clear after success, target change, expiry, death or reset.

Do not rebuild the old multi-phase Active/Recovery/TryConfirm architecture.

The normal in-range press must still redirect immediately.

### 6. Defensive radius should create a time window, not a random distance
Derive/inspect the effective parry window in milliseconds at representative speeds.

For early rallies, target roughly `180–280ms` of practical opportunity between entering the defensive region and body impact. Adjust defensive radius/body geometry/speed coherently to achieve a learnable window.

At higher rallies this naturally shrinks, creating skill progression.

Report the approximate window at rally 0, 3 and 6 using actual configured geometry/speeds.

### 7. Hurt semantics
Missing the parry must produce a clear hit result.

On authoritative body hit:
- ball visibly reaches/intersects the coherent hurt volume;
- short hit flash/sound hook;
- elimination/state change occurs immediately;
- ball stops/cleans up rather than visually passing through;
- quick reset.

This is the `system of hits` currently missing from the experience.

Do not rely on Roblox `Touched` alone; keep swept collision.

### 8. TrainingOpponent remains a rally wall
NPC continues to return every valid shot for this testing phase through the SAME authoritative TryParry path.

Its job is to expose Player timing repeatedly. No intentional misses.

### 9. Keep screen clean
Normal runtime remains:
- CoreGui;
- small rally counter;
- ball/world-space micro-cues only.

No old overlays or debug presentation.

### 10. Instrument perception timing for debug only
With a development toggle, log/inspect:
- actual distance at Player input;
- ball speed;
- estimated milliseconds until hurt contact;
- whether immediate or buffered parry succeeded;
- reason for failure.

No per-frame spam and nothing visible in normal play.

## REQUIRED TESTS
Focus only on this loop:
- first-ball travel time derived from actual separation;
- effective defensive opportunity at representative speeds;
- immediate in-range parry;
- early-buffer consume and expiry;
- buffer cleared on target/reset/death;
- confirmed parry feedback event fires exactly once;
- body hit fires exactly once and stops/cleans ball;
- NPC shared-path reliability;
- no rejected legacy UI in built place.

Static tests do not approve feel.

## HUMAN ACCEPTANCE
The next candidate is worth evaluating only if:
1. Ball is easy to visually track without looking huge.
2. First incoming ball gives about one second to read its approach.
3. Human can intentionally parry several early returns, not by luck.
4. Successful parry gives immediate unmistakable micro hit-confirm.
5. Slightly early input can be rescued by the small buffer; very early input still fails.
6. Missing produces a clear body hit/elimination instead of ambiguity.
7. NPC returns every valid ball.
8. Rally becomes progressively demanding instead of instantly impossible.
9. Screen remains clean.
10. No runtime errors.

The human tester decides pass/fail.

## FROZEN
No inventory, lootboxes, lobby expansion, powers, abilities, dash, cosmetics, economy, DataStore, ranked, quests, battle pass, finishers, social systems, additional NPCs, final map art or cinematic polish.

## COMPLETION REPORT
Keep it short:

### Git
branch + pushed SHA.

### Perception loop
actual separation, first-ball speed and resulting travel time.

### Ball readability
actual visible diameter/core/trail changes.

### Parry opportunity
radius + approximate milliseconds at rally 0/3/6 + early-buffer duration.

### Hit-confirm
exact authoritative event and client micro-feedback.

### Miss/hit
how body hit is detected/presented/cleaned.

### Verification
commands/results; `RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human action
open canonical `Fatal.rbxlx` and play 10–20 exchanges.

STOP. Do not add unrelated features or self-approve.