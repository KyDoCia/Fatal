# FATAL — Combat Spec V1

Status: design contract before implementation.

## Product thesis

FATAL is not Blade Ball with more effects and not Death Ball with different abilities.

The fantasy is a lethal exchange of force. The ball is the shared threat, but the player's mastery is expressed through timing, positioning, aim, composure, movement and control of momentum.

Every successful exchange should feel heavier, faster and more dangerous than the previous one.

## Non-negotiable feel

- Parry must feel like the player struck the ball, not clicked a remote.
- The ball must preserve readable momentum and direction.
- Speed escalation must increase tension without becoming visually random.
- A great player must be distinguishable from an average player before progression or paid content exists.
- Deaths must feel attributable: the player should understand why they lost.
- Camera, animation, audio and VFX support gameplay information first and spectacle second.

## Core exchange

The authoritative ball owns a phase instead of merely chasing a target:

`Acquire -> Commit -> Threat -> Contact/Parry -> Redirect -> Escalate`

Acquire selects a legal target. Commit establishes a trajectory. Threat is the readable reaction window. Contact resolves failure. Parry resolves a valid defensive strike. Redirect creates the next attack. Escalate increases pressure while preserving readability.

## Ball model

The gameplay ball is server authoritative, but presentation may be client-smoothed/predicted.

The server owns:
- logical position/trajectory;
- target;
- speed and rally;
- phase;
- contact resolution;
- accepted parry timestamp;
- redirect result.

The client owns only presentation and input intent.

Do not base production combat on an Anchored Part moved directly toward the target every Heartbeat. The visual ball is a representation of authoritative combat state, not the state itself.

## Trajectory

A committed attack has an origin, target snapshot, travel direction, speed and controlled steering budget.

The ball may correct toward a moving target, but cannot rotate infinitely. High-speed attacks therefore remain readable and positioning matters.

Redirects preserve incoming momentum as an input. They are not fresh teleports or arbitrary new homing lines.

## Parry

A parry is a timed defensive strike with server validation.

Validation considers at minimum:
- player alive and eligible;
- player is the threatened target unless a future mechanic explicitly permits interception;
- current ball phase permits parry;
- temporal/spatial contact window;
- server-side cooldown/state;
- latency compensation bounded by a strict maximum rewind.

A successful parry produces a redirect, not merely `target = randomPlayer`.

## Redirect / skill expression

Default redirect selection uses player intent.

Desktop: camera/aim direction contributes to target scoring.
Controller/mobile: camera direction plus assisted target scoring keeps parity without choosing blindly.

Candidate scoring can consider angular alignment, distance, visibility and legal target state.

A player who deliberately reads the arena should be able to influence who receives the next attack. Assistance must never make aim meaningless.

## Perfect timing

The parry window has an inner precision band.

A normal parry survives and redirects.
A precision parry grants a combat advantage such as stronger redirect authority and a controlled momentum bonus.

The precision band must never become mandatory for ordinary survival at normal latency.

Exact timings are tuning values, not hard-coded design truth, and require Studio playtests.

## Escalation

Rally increases danger through a curve, not an unlimited linear `base + n` formula.

Escalation can influence:
- travel speed;
- redirect sharpness budget;
- audiovisual intensity;
- camera impulse;
- trail persistence;
- precision reward.

Readability is a hard ceiling. If the ball becomes impossible to parse, the escalation model failed even if mathematically fair.

## Movement relationship

Movement is part of defense. Position changes approach angle, available reaction information and redirect options.

FATAL should not reward permanent running away. Arena constraints and ball steering must force engagement while leaving meaningful micro-positioning.

## Camera

Camera feedback is stateful and local.

When the local player becomes the committed target, framing subtly tightens and threat readability increases. On parry, impulse follows the strike/redirect vector. Precision parry may receive a stronger but short impulse.

No sustained shake that harms aim. No cinematic camera that steals control during live combat.

## Feedback hierarchy

The player must be able to identify, in order:
1. whether they are targeted;
2. where the ball is;
3. when impact is approaching;
4. whether the parry succeeded;
5. where the ball was redirected;
6. how dangerous the current rally is.

VFX that obscures these signals is a defect.

## Elimination

Contact resolution is authoritative and deterministic enough to audit.

The elimination presentation may be spectacular, but gameplay death is resolved first. Kill feedback should expose the decisive exchange rather than hiding it behind effects.

## Networking

Client sends compact intent: parry press plus the minimum aim/input context required for redirect validation.

Never accept from the client:
- hit confirmation;
- ball position;
- chosen arbitrary target without validation;
- rally/speed mutation;
- cooldown completion;
- elimination result.

Server keeps enough recent authoritative state for bounded latency validation. Compensation is capped so high latency cannot manufacture an oversized parry window.

## Competitive invariants

- Same gameplay rules across PC, console and mobile; input assistance may differ only to preserve practical parity.
- Cosmetics cannot change gameplay collision or timing.
- Progression cannot sell larger parry windows or superior ball authority.
- One authoritative gameplay ball unless a future mode explicitly defines another invariant.
- Server can reconstruct why a parry or elimination was accepted.

## First playable proof

The next implementation is not a full game. It must prove one exchange feels excellent.

Required proof:
- two or more combatants;
- authoritative phase-based ball simulation;
- readable target acquisition;
- deterministic contact;
- validated normal parry;
- precision timing band;
- aim-influenced redirect;
- rally escalation curve;
- local target/parry camera feedback;
- minimal diagnostic HUD for phase, speed, rally and validation reason;
- two consecutive rounds with zero red runtime errors.

## Explicitly deferred

Abilities, economy, crates, trading, quests, battle pass, ranked, clans, persistence, elaborate lobby, large map production and content volume.

None of these are allowed to hide a mediocre exchange.

## Gate

Implementation advances only when repeated Studio playtests answer yes to all three:

1. Is the incoming attack readable?
2. Does pressing parry feel physically connected to the redirect?
3. Can a skilled player demonstrate intentional control that a beginner cannot?

If any answer is no, tune or redesign combat before expansion.
