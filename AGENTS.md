# Standalone Battle UI Mock

This is a presentation and integration project, not a gameplay source of truth.

- Keep the same public snapshot vocabulary as `godot-latest`.
- Runtime data comes only from `data/mock_battle_snapshot.json` through `session/mock_game_session.gd`.
- Do not import production saves, authoritative combat services, or spreadsheet-derived balance data.
- `game/` is the composition shell, `features/` owns the battle screen, `shared/` owns reusable prefabs, and `session/` is the mock boundary.
- The complete UI layer (`game/`, `features/`, `shared/prefabs/`, `assets/artist_ui/`, and `assets/battle_ui/`) must remain byte-for-byte aligned with the current `godot-latest`, including scenes, controllers, presenters, adapters, registries, factories, prefabs, geometry, and resource references.
- Mock-only differences belong exclusively in `session/`, `core/`, `data/`, tests, and project documentation.
- Use ASCII file and node names. Chinese is allowed only in player-facing text and documentation.
- Changes here must never be copied back over production state or data files without a separate integration task.
