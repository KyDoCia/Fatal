# FATAL — AI Handoff

> Git is the source of truth. Human Studio playtest is the authority for gameplay quality.

## STATUS
**V2 FEEL PASS 1 — HARD REJECTED**

Latest tested candidate: `codex/combat-core-v2` @ `a2c35a79a4bea84ff21560923369b3c612126e4f`.

The candidate is mechanically more functional than earlier versions, but the human Studio test still rates the experience at effectively zero quality/gameplay satisfaction.

Do not merge it to `main`. Do not add features. Do not attempt to rescue this by adding more HUD, VFX, camera systems, state machines or tuning tables.

## VISUAL EVIDENCE FROM STUDIO
The latest screenshot still shows exactly the kind of presentation the handoff prohibited:
- giant `FIGHT` overlay;
- `CRITICAL` text;
- floating `0.12` timing/TTI-like information;
- a large rectangular debug/target region around the avatar;
- red floor/target geometry and a large glowing red marker competing with the ball;
- the ball still visually reads much larger/heavier than the intended compact projectile;
- the screen's attention hierarchy is wrong: UI/debug/markers dominate instead of ball -> opponent -> player action.

Therefore either the normal/debug separation is still broken OR the built `Fatal.rbxlx` still contains stale scripts/UI from the rejected implementation. Treat this as a build/provenance failure until proven otherwise.

## DECISION
Before changing game feel again, make the runtime candidate CLEAN and MINIMAL.

The next build must contain only the V2 duel presentation we intend to evaluate. If old UI/scripts are surviving because Rojo/build output preserves stale instances, fix the build pipeline/root place rather than hiding them at runtime.

## NEXT TASK — V2 CLEAN ROOM RUNTIME

Continue on `codex/combat-core-v2`, but rebuild the playable runtime candidate from a clean canonical place/tree.

### 1. Prove what is producing the rejected overlays
Search the ENTIRE repository and generated place pipeline for the runtime producers of:
- `FIGHT`;
- `CRITICAL`;
- TTI/timing number labels such as the visible `0.12`;
- target/debug rectangles;
- red target floor boxes;
- large red glowing ground marker;
- any old CombatDebug/Threat/TargetIndicator/CombatGui systems.

Do not assume `CombatDebug = false` is sufficient. Identify the exact Instance/script/module responsible for each visible element.

If any producer exists only inside a stale base `.rbxlx`, remove it from the canonical base/build path.

### 2. Clean canonical build
`Fatal.rbxlx` must be produced from a clean V2 source of truth, not by overlaying V2 onto a contaminated old place that retains rejected scripts/UI.

Audit `default.project.json`, build scripts, generated assets and base-place behavior.

After build, inspect/audit the resulting place and assert that rejected legacy names/scripts/UI are absent.

Do not merely disable them. For the V2 Combat Lab candidate they should not exist in the built runtime unless they are explicitly development-only and guaranteed not to instantiate in normal play.

### 3. Normal runtime presentation = almost nothing
For this candidate normal gameplay should show only:
- Roblox CoreGui;
- a SMALL rally counter.

Nothing else persistent.

No FIGHT.
No CRITICAL.
No TTI.
No target boxes.
No floor target markers.
No glowing ground marker.
No debug geometry.
No labels above/beside characters.
No instructions during the duel.

The ball itself is the targeting information for this 1v1 test.

### 4. Ball must be visually tiny and unambiguous
The screenshot still reads the black ball as too large.

For this clean-room candidate, reduce visible diameter aggressively to about `1.0–1.2 studs` (radius `0.5–0.6`) and verify the ACTUAL built Part/Mesh dimensions in `Fatal.rbxlx`.

Collision radius must be coherent with the visual ball. Player defensive parry radius remains separate and forgiving.

Remove excessive dark/glossy visual mass if it makes the projectile read larger than its geometry. Keep a simple high-contrast core and restrained trail.

### 5. Strip combat feedback to causality only
No cinematic feedback pass.

Successful parry may have only:
- immediate direction reversal/redirect;
- immediate speed change;
- tiny trail pulse;
- one subtle short sound/flash if already available and clean.

Temporarily REMOVE the FOV punch if it adds noise. We first need to judge trajectory/timing alone.

### 6. Duel framing
Player and NPC must be placed in a simple straight readable lane at reset and face each other.

For the first clean-room candidate:
- keep both mostly stationary;
- choose a consistent separation suitable for the speed;
- spawn the ball on the line between them;
- first target and trajectory must be obvious immediately.

No floor markers are needed to communicate target.

### 7. Training NPC = deterministic wall
NPC must return every valid incoming ball. Keep `MissChance = 0`.

If it fails at any supported speed, fix its continuous crossing/decision logic while still routing through the same authoritative `TryParry` as Player.

### 8. Combat speed: fast but readable
Do NOT add another complicated curve.

Keep the current concept approximately `70 + 12*rally`, capped near `260`, unless code inspection reveals a concrete problem.

The clean-room test is intended to isolate whether trajectory + timing + immediate redirect are enjoyable once visual contamination is gone.

### 9. Parry input remains simple
Do not regress the one improvement already observed: Player can now parry.

Keep immediate server evaluation:
`input -> target/alive -> approaching -> defensive radius -> cooldown -> redirect`.

No active window state machine, no TTI gate, no frontal arc, no sword mesh authority.

### 10. Add build-audit assertions
The verification must fail if the built `Fatal.rbxlx` contains known rejected legacy presentation.

Audit at least:
- no `FIGHT` text outside tests/docs;
- no `CRITICAL` text outside tests/docs;
- no runtime TTI label/controller;
- no legacy target/debug GUI scripts;
- exactly one gameplay ball source;
- actual built ball dimensions match the intended diameter;
- only expected V2 client/server scripts are present in the Combat Lab runtime tree.

The purpose is to prevent us from ever again playtesting a contaminated/stale build while believing it is the new candidate.

## HUMAN ACCEPTANCE — CLEAN ROOM
The next candidate is ready to show the human only when:
1. Screen contains CoreGui + small rally counter and nothing else persistent.
2. Ball is visibly compact (~1.0–1.2 stud diameter).
3. Player starts facing NPC; NPC faces Player.
4. Ball path is immediately obvious.
5. Player can parry using the simple V2 rule.
6. NPC returns every valid shot.
7. Successful parry visibly causes the ball to leave immediately and faster.
8. No old overlays/markers/debug geometry appear at any point.
9. Reset returns to the same clean state.
10. No red runtime errors.

This does NOT approve gameplay feel. It only creates a trustworthy minimal candidate from which gameplay can finally be judged.

## FROZEN
No inventory, lootboxes, lobby expansion, powers, abilities, dash, cosmetics, economy, DataStore, ranked, quests, battle pass, finishers, social systems, additional NPCs, map art or cinematic polish.

## COMPLETION REPORT
Keep it short:

### Git
branch + pushed SHA.

### Contamination root cause
Exact source of FIGHT/CRITICAL/0.12/boxes/red marker and why they survived previous builds.

### Clean build
How `Fatal.rbxlx` is now guaranteed to contain only intended V2 runtime systems.

### Ball
Actual built visual dimensions + authoritative radius.

### Runtime tree
Expected normal UI/scripts remaining.

### Verification
Exact commands/results. `RUNTIME TESTED: ...` or `RUNTIME NOT TESTED`.

### Human action
Open canonical `Fatal.rbxlx` and play.

STOP. Do not self-approve gameplay and do not add anything else.