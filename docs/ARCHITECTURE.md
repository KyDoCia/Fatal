# FATAL Architecture

Canonical roots:

- ReplicatedStorage/Game
- ServerScriptService/Game
- StarterPlayer/StarterPlayerScripts/Game

Core rules:

- R15 only.
- One authoritative gameplay ball.
- Server-authoritative combat and rewards.
- Players and NPCs share a Combatant abstraction.
- Client sends intent; server validates and mutates gameplay state.
- UI remains data-driven and customizable.
- Gameplay collision is separated from visual arena geometry.
- Static tests never substitute for Roblox Studio runtime validation.

Vertical slice gate:

Lobby -> Countdown -> Ball -> Target -> Parry -> Rally -> Elimination -> Winner -> Cleanup -> Next Round
