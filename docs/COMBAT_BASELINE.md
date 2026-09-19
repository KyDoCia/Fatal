# Combat Baseline

This document freezes the combat behavior that passed the human Studio run test. It is a regression contract, not a declaration that FATAL is finished.

## Parry flow

`CombatInputController` turns MouseButton1 or `F` into one semantic `ParryIntent` containing the camera aim direction. The client starts `ParryAttempt` immediately. `CombatCore` validates duel activity, combatant life, current target, approach, defensive distance, buffer and cooldown. Only the server redirects the ball and emits `ParryConfirmed`. Without a corresponding confirmation, the short client lifecycle resolves as `ParryMiss`; miss presentation never changes gameplay or produces confirmed impact feedback.

## Trajectory

The validated `AimDirection` establishes the initial direction and proportional `CurveStrength` for a new trajectory leg. Steering converges smoothly toward an intercept. Terminal intercept takes authority near contact, after overshoot or when the ball stops approaching, preventing stable orbit and preserving swept collision against moving targets. Straight aim remains approximately straight; left, right and upward deviations remain reproducible.

## Momentum contract

A confirmed parry ends the old trajectory leg and starts the next leg atomically. It clears terminal, closest-approach and curve-progress state before applying the new direction. During a normal rally, both redirect and subsequent simulation preserve `OutgoingSpeed >= IncomingSpeed`, capped by `MaxSpeed`. There is no pending redirect, recovery state or intentional dead frame between legs.

## Authority boundary

The server decides ball state, trajectory, target, parry success, hit, elimination, duel result and economy rewards. The client sends input intent and owns interpolation, animation, VFX, audio hooks and camera presentation. Presentation events report authoritative results; they cannot create them.

## Animation boundary

Character animation sets expose Idle, Walk, Run, Jump and Fall with safe Roblox R15 fallback when an asset is absent. Weapon animation sets expose Equip, ParryAttempt, directional ParryHit and ParryMiss. Tracks are cached per character and cleaned on character removal or respawn. Animation never determines parry timing, collision, direction, speed or damage.

## Locked behavior

Do not rewrite the following without a reproducible Studio regression and a focused failing test:

- server-authoritative `TryParry` shared by Player and TrainingOpponent;
- one authoritative ball and swept collision;
- aim-authored curve, proportional CurveStrength and smooth convergence;
- terminal intercept, anti-orbit and moving-target interception;
- atomic trajectory legs and momentum continuity;
- target selection, duel lifecycle and reset cleanup;
- hit/elimination deduplication and reward receipts;
- the current R15 animation and presentation authority boundary.

Subjective feel values are not permanent invariants. Any future tuning requires a new human runtime evaluation.

## Customization contract

`WeaponDefinition`, `BallDefinition`, `ParryEffectDefinition` and `AnimationSet` are content and presentation over the common authoritative mechanic. A weapon is not parry authority. A ball model is not its gameplay hitbox. An effect is not a gameplay result. An animation is not gameplay timing. This separation must remain intact so customization cannot create a competitive advantage.

## Canonical validation

Build `Fatal.rbxlx` through `tests/verify.ps1`. The script regenerates source assets, compiles every Luau source, builds the place, verifies that every embedded script matches its canonical repository source, audits rejected legacy content and runs combat regressions. Human evaluation uses that generated place without Rojo live-sync.
