# Blueprint: Phase K — Touch-First In-Game CQB Blueprint Map Editor

> **Status:** Active Phase K Expansion Blueprint (pure game map authoring tool exporting `data/maps/*.json` compatible with `MapLoader` and `map_validation_harness.gd`).

## 1. Core Editor Experience (Portrait `1080×1920`, `CanvasLayer`)
Allows players to design, playtest, and share custom CQB game maps for Solo, 2-Player Co-op, and 2-Player PvP directly on Android:
- **Grid Canvas:** Uses `MapRenderer` + `MissionCamera` (pan/pinch zoom, floor switcher `F1`/`F2`/`F3`, snapping strictly to 16×16 px integer grid).
- **Bottom Tool Palette (Theme-Aware `StyleBoxFlat`):**
  - `WALL` (drag-to-paint segments; cycle material: `CONCRETE`, `DRY_WALL`, `ARMORED`)
  - `DOOR` (tap wall cell; cycle state: `CLOSED_UNLOCKED`, `LOCKED`, `BARRICADED`)
  - `STAIR` (link two floor cells for multi-floor raids)
  - `ZONES` (paint `INSERTION` with vehicle req, `EXTRACTION`, and PvP `DEFENDER` zones)
  - `UNITS` (place OpFor spawns with archetype & patrol waypoints, `HOSTAGE` spawns, `OBJECTIVE` markers, and `RF JAM` nodes)
  - `ERASE` / `UNDO` / `REDO` (command-stack undo up to 50 actions)

## 2. One-Tap Live Validation & Instant Playtest
- **`Validate` Button:** Runs the exact same 4 checks as `tests/map_validation_harness.gd` in-app (schema bounds, walkable spawns, `GridPathfinder` reachability from insertion to every objective & extraction, and `Visibility.compute_polygon()` sanity) and highlights any invalid cell in pulsing red.
- **`Playtest` Button:** Launches `PlanningRoot` directly with the unsaved map buffer; pressing `Back to Editor` restores the exact editor state.
- **Export / Import (`user://custom_maps/<map_id>.json`):** Saves standard `MapLoader` JSON files + clipboard/file share string so players can trade custom CQB maps or load them into 2-Player LAN lobbies.

## 3. Mandatory Headless Gate (`tests/map_editor_harness.gd`)
1. Paint walls/doors/zones/spawns via `MapEditorState` -> undo/redo roundtrip preserves exact state.
2. `MapEditorState.to_json()` -> `MapLoader.load_from_string()` roundtrip passes all 4 `map_validation_harness.gd` checks.
3. Invalid map (blocked objective with no door/path) is flagged cleanly by `MapEditorValidator.validate()`.
