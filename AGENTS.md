# FATAL agent guide

Build an original, premium Roblox competitive parry game.

Core principles:
- R15 first.
- Server-authoritative combat.
- One gameplay ball.
- Players and NPCs use the same Combatant abstraction.
- Client sends intent only.
- UI is data-driven and customizable.
- Gameplay collision is separate from visual architecture.
- Prefer exact canonical module paths over recursive discovery.
- Treat Roblox Studio runtime as final validation.

Vertical slice before expansion:
Lobby -> Countdown -> Ball -> Target -> Player/NPC Parry -> Rally -> Elimination -> Winner -> Cleanup -> Next Round.

Do not copy proprietary code, assets, UI, audio, animation, or maps from other games.

For implementation reports, distinguish static verification from real Studio runtime testing.
