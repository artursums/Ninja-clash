# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6 (pinned 2026-02-12; see `docs/engine-reference/godot/VERSION.md`)
- **Language**: GDScript (primary). C++ via GDExtension only for proven performance-critical paths. C# not enabled in v1.
- **Rendering**: Forward+ renderer (default). For Steam Deck battery-life testing, evaluate Compatibility renderer in alpha.
- **Physics**: GodotPhysics2D (2D only — Four Clans uses no 3D). Jolt 3D default in Godot 4.6 does not apply to this project.

## Naming Conventions

- **Classes**: PascalCase (e.g., `ShurikenProjectile`, `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`, `shuriken_count`)
- **Signals/Events**: snake_case past tense (e.g., `shuriken_thrown`, `player_eliminated`)
- **Files**: snake_case matching primary class (e.g., `shuriken_projectile.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `ShurikenProjectile.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_SHURIKENS`, `DODGE_I_FRAMES`)

## Performance Budgets

- **Target Framerate**: 60 fps locked. Couch PvP demands consistency over peak.
- **Frame Budget**: 16.6 ms total. Reserve ~12 ms for game logic + rendering, ~4 ms physics/input headroom.
- **Draw Calls**: < 200 per frame (2D pixel-art game; plenty of headroom).
- **Memory Ceiling**: < 1 GB RAM (modest target; Steam Deck friendly).

## Testing

- **Framework**: GUT (Godot Unit Test) — recommended; the de-facto standard for GDScript projects.
- **Minimum Coverage**: TBD — set after the first system is implemented.
- **Required Tests**: Balance formulas (shuriken physics, dodge i-frames), gameplay systems (round flow, retrieval), networking (when added in v2+).

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet. Likely first addition: GUT (testing).]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use `/architecture-decision` to create one. First likely ADR: input/state separation to permit future online multiplayer (per game-concept.md risk #5).]
