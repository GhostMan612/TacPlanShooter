# CHANGELOG.md — Work Log
Newest first. One entry per work session.

---

## Session 20 — 2026-11-25 — Repo sync & Headless CI green fix

- Audited local/remote `main` (`55f3fbe`) and inspected GitHub Actions run `45555806041` (`Headless CI`): all 12 test suites passed functionally, while 2 post-run log checks tripped CI:
  - Added `is_inside_tree()` guard in [`scripts/audio/tactical_audio.gd`](../scripts/audio/tactical_audio.gd) `_play_path()` so unit tests instantiating `TacticalAudio` outside the `SceneTree` (`ui_audio_smoke.gd`) do not emit `ERROR: Playback can only happen when a node is inside the scene tree`.
  - Changed `grep -vE` to case-insensitive `grep -viE` in [`tools/ci_gate.sh`](../tools/ci_gate.sh) so Godot 4.0.4's capitalized shutdown notice `ERROR: Resources still in use at exit` is filtered identically to lowercase variants.

## Session 19 — 2026-11-24 — Touch UX de-clunking, Multi-Floor Stair Links (OP-05..OP-10), TacticalVfx & Translucent Replay AAR

- Recorded hands-on user verdict on BLU `B160V` (`CP-080`/`CP-090` `"yes, works well, a little clunky but it's the first try"`) and eliminated every root cause of first-try planning clunkiness:
  - **Freehand wall-graze auto-repair (`RoutePlanner.repair_freehand_waypoints`):** strips grazed intermediate corner walls during freehand thumb strokes and snaps grazed multi-cell endpoints to adjacent walkable cells while preserving strict `RoutePlanner.plan()` checks (`route_plan_blocked` PASS).
  - **Responsive touch + `DRAW`/`TAP` mode (`PlanningController`, `PlanningRoot`):** tuned long-press to `0.28 s` (`HOLD_SLOP_PX = 24.0`), added routing blip + haptic pulse (`16 ms`), added full-width top-bar `< MENU` / `DRAW|TAP` / `F1/N` controls, and compacted `_node_menu` (`NODE_BUTTON_PX = 56`, `CLEAR NODE` + `DONE`) cleanly above the `720x1612` map.
- **Multi-floor simulation & campaign missions (`OP-05`–`OP-10`, `CP-073`):**
  - Extended `GreyboxMap`, `MapLoader`, `AgentCommand.USE_STAIRS`, `SimOperative`, `SimEntity`, `SimWorld`, `CombatSystem`, `AiCoordinator`, `MapRenderer`, `FogLayer`, `TacticalOverlay`, and `CampaignScreen.describe()` for `1..3` floors and bidirectional `stair_links`, keeping Floor-0 `map_validation_harness` `EXPECTED_SOLIDS` exact across all 10 campaign maps.
  - Wired automatic stair ascension when ending a leg on a cyan stair tile (`F1 -> F2`) while preserving mid-corridor traversal past reverse stair cells.
- **Live combat VFX & translucent replay AAR (`TacticalVfx`, `AarScreen`, `MissionGrading`, `ProgressionSave`):**
  - Replaced `TacticalVfx` stubs with procedural MSAA-free muzzle flashes, tracers, breach shockwaves, flashbang blooms, tear-gas clouds, and acoustic rings; made `AarScreen` translucent (`alpha = 0.72 -> 0.16` on scrub), added Grade (`S`/`A`/`B`/`F`) + `+RP`, `NEXT OPERATION`, and `ProgressionSave` campaign persistence; hid HUD chrome while `AarScreen` is active.
- Verified static hygiene (`HYGIENE_COMMENTS = 0`), passed all 12 headless Godot 4.0 gates (`parse_all` 92 scripts / 13 scenes `failures=0`, expanded `scene_smoke` `failures=0`, `determinism_harness` `failures=0`), and verified `OP-05: Penthouse Lock` `F1 -> F2` routing, `F2` firefight (`TacticalVfx` tracers/rings + `FogLayer`), `OPERATION COMPLETE (GRADE S · +75 RP)`, and `CampaignScreen` (`10` ops) live on the BLU `B160V`.

## Session 18 — 2026-11-24 — BLU B160V Android 14 hardware verification, 720x1612 HUD layout fix & WAV header fix

- Verified Route A ARM64 debug APK (`builds\TacPlan-debug.apk`, `apksigner verify` v1/v2/v3 PASS, 10 campaign maps `op01..op10` + 14 WAV assets) live on physical handset BLU `B160V` (`7040016025040287`, Android 14 API 34, `arm64-v8a`, GPU `PowerVR Rogue GE8300`, `720x1612` portrait):
  - Verified `SplashScreen` -> `TitleScreen` (`[TacPlan] screen=title buttons=7`), `SettingsScreen` live `Night-Ops NVG` (`theme=2`) <-> `Dark Tactical` (`theme=0`) switch, `OP-01` Planning, long-press route drawing (`[PLAN] op 0 route committed: 14 waypoints, 43 px baked`) + 3x `PipLoupe`, live 60 Hz execution + `FogLayer` (`fog_mask.gdshader` live cone + 50% visited memory), `AarScreen` (`OPERATION COMPLETE`, `TIMELINE`, `ReplayScrubber` scrubbed to `SCRUB TICK 98 / 197`), and `MapEditorScreen` (`[TacPlan] screen=map_editor w=16 h=12`).
  - Measured SurfaceFlinger frame intervals on `SurfaceView[com.tacplan.game/com.godot.game.GodotApp](BLAST)#1602`: `refresh_ms=16.67`, `samples=126`, `avg_ms=33.13`, `median_ms=33.67`, `p95_ms=50.52`, `min_ms=16.60`, `max_ms=50.74`; device logcat clean (`0` `godot:W`/`godot:E`/`AndroidRuntime:E` errors).
- Fixed two `720x1612` portrait layout issues found on device in [`scripts/planning/planning_root.gd`](../scripts/planning/planning_root.gd):
  - Added `_center_camera_if_short(map_px)` and `0.86` zoom margin so the `OP-01` board clears the top status bar and keeps `01..12` MGRS labels unclipped.
  - Compacted bottom `ActionBar` (`font_size=24`, `clip_text=true`, `separation=8`, `W:A..W:D` / `GO:A..GO:D`, stretch ratios `1.6` / `1.35`) so all 6 buttons fit within `720px` width.
- Fixed [`tools/gen_placeholder_audio.ps1`](../tools/gen_placeholder_audio.ps1) to write valid 16-bit mono PCM headers (`blockAlign=2`, `bitsPerSample=16`, non-zero integer samples) and regenerated the 14 tracked `assets/audio/sfx_ui_*.wav` files (`WAV_import_errors=0` on export).

## Session 17 — 2026-11-24 — Post-merge integration fixes, PipLoupe, CP-071 replay scrubbing & M9 Audio

- Fixed `.github/workflows/headless-ci.yml` Import Pass 2 missing `run:` block and byte-size class-cache verification (`> 1000` bytes).
- Fixed `SimWorld` (`check_mission()`, `_has_spawns_at()`, fatal-funnel tracking in `_step_move()` + snapshot/restore), `MapLoader` (`chokepoints` loading), and added `[5, 2]` doorway chokepoint to `data/maps/op01_glass_house.json`.
- Rewrote `scripts/audio/tactical_audio.gd` without colliding `class_name`, fixed `EventBus` bridging from `PlanningRoot._physics_process()`, ambient bus ducking/unducking, low-pass heartbeat filter on damage, and seeded randomized radio squelch/UI blips.
- Finished planning & UI stack: created `scripts/planning/pip_loupe.gd` (`PipLoupe` 3x magnifier during routing), fixed `PropsPlacement` (`MultiMeshInstance2D` + `QuadMesh` + vertex colors), fixed `RadialMenu` (`position`, thumb sizing, CQS routing via `_select_go_code`), fixed `PlanningController` tap coordinates + tap-to-cell A* helper, and restored `PlanningRoot._on_execute_pressed()` + `_maybe_aar()`.
- Completed **CP-071** timeline & replay scrubbing in `AarScreen` (`ReplayScrubber` HSlider + journal event formatting) and `PlanningRoot.scrub_replay_to_tick()`, verified by expanded `tests/scene_smoke.gd` and `tests/ui_audio_smoke.gd`.
- Rebuilt local class cache (`79` classes) and passed all 12 Godot 4.0 headless gates (`parse_all` 92 scripts / 13 scenes `failures=0`, boot smoke, `scene_smoke` `failures=0`, `aaa_ai_harness` 6/6, `determinism_harness`, `meta_progression_harness`, `ui_polish_audit`, `map_validation_harness`, `ui_audio_smoke`, `map_editor_harness`, `fog_layer_harness`, `simclock_probe`) + `0` hygiene failures.

## Session 13 — 2026-11-24 — FULL ACCESS + FULL ALLOW grant (user-directed)

### Files
- `RULES.md` — §1.1 (external dirs writable), §1.2 (secrets advisory-only), §1.3 (git discipline allow), §2 (builds user-granted extended); all user denies → FULL ALLOW.
- `AGENTS.md` — Hard boundaries flipped: FULL ACCESS (no denies); NEVER-build-binaries → user-granted binary builds (direct Godot export + Android Studio Gradle).

## Session 16 — 2026-11-24 — Phase L: AAA Tactical CPU & GOAP Squad AI (+ CI _init() fix)

- Implemented pure autoload-free 60 Hz deterministic AI modules under `scripts/sim/ai/`:
  - `influence_map.gd` (`InfluenceMap`): integer-grid danger/LOF cone heatmap, hard-cover/peek/grenade-landing evaluators, smoke masking, and threat-weighted deterministic A* (`find_tactical_path`).
  - `goap_actions.gd` & `goap_planner.gd` (`GoapActions`, `GoapPlanner`): staggered 12-tick 26-bit GOAP planner covering Flush Cover, Bounding Overwatch (`F_BOUNDED`), Tactical Reload, Anti-Drone Counter, Breach Counter, and Suppress LKP.
  - `squad_tactics.gd` (`SquadTactics`): doorway L-crossfire placement, friendly LOF block checks, bounding overwatch role assignment/swapping, telegraphed `ai_callout` journal/feed events, and fair `RECRUIT`/`VETERAN`/`TIER_ONE` doctrines.
  - `cpu_commander.gd` (`CpuCommander`): tick-0 `GreyboxMap` topology analyzer, automated `CommandQueue` preplans with crossfire anchors, patrols, barricaded doors, RF jammers, and `alpha`/`bravo` go-codes, plus live `step_commander` adaptation.
- Integrated into `enemy_ai.gd`, `ai_coordinator.gd`, `combat_system.gd`, and `sim_world.gd` with full snapshot/restore and `state_hash()` determinism coverage.
- Fixed SceneTree `_init()` initialization across `tests/{determinism_harness,meta_progression_harness,ui_polish_audit,map_validation_harness,ui_audio_smoke,map_editor_harness}.gd`, added `tests/aaa_ai_harness.gd`, and hardened `.github/workflows/headless-ci.yml` class-cache polling + `AAA AI harness` gate.
- All 12 local Godot 4.0 headless gates passed (`parse_all` 89 scripts / 13 scenes `failures=0`, boot smoke, `scene_smoke`, `aaa_ai_harness` 6/6 PASS, `determinism_harness` `failures=0`, `meta_progression_harness`, `ui_polish_audit`, `map_validation_harness`, `ui_audio_smoke`, `map_editor_harness`, `fog_layer_harness`, `simclock_probe`) plus static hygiene audit (`0` failures).

## Session 15 — 2026-11-24 — Integrate planning overlays

- Resolved [PR #4](https://github.com/GhostMan612/TacPlanShooter/pull/4) with the mission, replay, and fog changes on `main`.
- Squad tokens show callsigns, selection, and exact movement. Live contacts use registered simulation actors and the existing fog polygons. Contacts keep their last observed position after leaving sight and clear on reset.
- Fog uses the active palette and transparent alpha masks. Change-driven updates and GPU visited memory are preserved.
- Godot 4.0.4 headless gates pass, including planning scene checks for token movement, contact transitions, and reset. Physical Android appearance and timing remain open.

## Session 14 — 2026-11-24 — Code audit remediation

- Published the [audit of `77c064b`](../docs/TacPlanShooter_Code_Audit_77c064b.md) and a credential-free Android export preset. Route A verification compared the signed ARM64 APK contents against all ten source maps.
- Reset now starts from the original map. Snapshots and hashes cover pending commands, overrides, and live subsystem state. Enemy detection uses registered actors. Zero-health operatives stop moving.
- D-MISSION-01 adds a ground-floor checkpoint-and-exit loop with an on-screen result and retry. Maps without ground-floor goals are labeled practice. CP-071 still requires timeline and replay scrubbing.
- D-PLAN-01 adds go-code waits to route cells and compiles door interactions into the plan. Invalid routes keep execution gated until redrawn.
- Map Editor restores complete cell state on undo and redo, rejects malformed imports before replacing edits, and preserves edit history across Playtest.
- Fog caches wall geometry and unchanged observer masks. Visited polygons are composited on the GPU, and live mask nodes are reused. Handset frame time still requires measurement.

## Session 13 — 2026-11-24 — UI/UX audit + remediation steps 1–2 (PR #1)

### Audit
- Full UI/UX + feature audit → `blueprints/WO-UI-UX-AUDIT-REMEDIATION.md` (findings + 7-step plan with gates).
- Headless CI had never passed (54 failed / 4 cancelled); harness steps silently exited and import-log parse errors were never gated. Earlier "PASS" claims in handoff docs were not CI-verified.

### Files (PR #1, branch `ccr-686be8a5-60lcmh`)
- `scripts/ui/theme_manager.gd` — RefCounted; static `palette_for()` / `build_theme()` / `load_settings()` / `save_settings()` / `apply_saved()`; real Button/Label/Panel/HSlider styleboxes; 40/48 px fonts; 128/160 px touch padding; `user://settings.json`.
- `scripts/ui/screen_router.gd` — static `goto_stage()` / `scene_for()` + root-meta params (`map_path`, `map_json`, `return_stage`, `editor_buffer`).
- `scripts/ui/ui_kit.gd` (new) — shared screen scaffold, headings, captions, touch-size buttons, haptics.
- `scripts/ui/{splash,title,settings,hq_armory}_screen.gd`, `scripts/ui/{campaign,credits}_screen.gd` (new), `scenes/{campaign,settings,hq,credits}.tscn` (new).
- `scripts/editor/map_editor_screen.gd` (rewrite), `map_editor_state.gd` (RefCounted, `erase_cell` undoable), `map_editor_validator.gd` (bounds / walkable / reachability / visibility), `scenes/map_editor.tscn` (script attached).
- `scripts/planning/squad_hud.gd` (rewrite), `planning_root.gd` (map param, MENU/back, themed HUD bar), `map_renderer.gd` (palette keys, `col_letter()`), `plan_board.gd` (0–1 squad colours).
- `scripts/sim/map_loader.gd` (`load_from_string`, editor schema), `greybox_map.gd` (`from_dict` keeps zones/spawns).
- Compile fixes: `mission_prep_panels.gd` (`PrepPanel`), `lockstep_session.gd:77`, `audio/acoustic_bus.gd` split from `tactical_audio.gd`, `audio/bus_graph.gd` (`apply_volumes`), harness fixes.
- CI: `tests/parse_all.{gd,tscn}`, `tests/scene_smoke.{gd,tscn}`, `tools/ci_gate.sh`, `.github/workflows/headless-ci.yml` (all steps run, real gates), `project.godot` `quit_on_go_back=false`.

### Sim fixes surfaced once the harness actually ran
- `determinism_harness.gd:711` `var match` (keyword) → parser-stage failure that Godot 4.0 never prints; `--script` exited silently in every CI run. `_test_visibility_west_corner_wrap` was called but never committed — implemented.
- `Visibility`: Godot 4 `wrapf()` snaps values within ~3.1e-5 of PI to -PI, killing the -eps grazing ray at the west seam → exact single-period `wrap_angle()`.
- `SimWorld`: snapshot/restore now carry `entity_seq` + tap-in state; `setup()` clears entities, overrides, tap-in, drones, vehicles (Planning Reset kept spent CP).
- Test fixes: sweep-line IoI observer in cell units; acoustic attenuation via `is_equal_approx`; override replay compares equal ticks.

### Decisions
- **D-BAL-01 (user-approved 2026-11-24):** a hit from a known caliber always deals at least 1 damage: `damage_for = max(pen - armor, 1)`; unknown caliber = 0.

### Gate status (PR #1 CI, Godot 4.0.4 headless)
- Parse gate PASS (79 scripts, 13 scenes); boot smoke, scene smoke (every screen), meta progression, UI polish audit, map validation, UI audio smoke, map editor, SimClock probe PASS; determinism harness 35/36 before D-BAL-01.

---

## Session 12 — 2026-11-23 — Phase K — Touch-First In-Game CQB Map Editor

### Files
- `scripts/editor/map_editor_state.gd` — `MapEditorState` (Node): paint wall/door/zones/ai_spawn/objective/jammer; undo/redo (≤50) via `Callable` undo+redo closures; `to_json()` / `MapEditorState.from_json()`; `validate()`.
- `scripts/editor/map_editor_validator.gd` — `MapEditorValidator.validate(m) -> Array[Dictionary]` (out-of-bounds checks for solids, doors, zones, objectives, spawns, jammer).
- `scripts/editor/map_editor_screen.gd` — `MapEditorScreen` (Control): `MapRenderer` grid canvas + tool palette (WALL/DOOR/ZONES/UNITS/ERASE/UNDO/REDO/VALIDATE) + invalid-cell highlight.
- `scenes/map_editor.tscn` — root scene.
- `scripts/ui/title_screen.gd` — `map_editor := 6` + MAP EDITOR button.
- `tests/map_editor_harness.gd` — `map_editor_state_undo`, `map_editor_roundtrip`, `map_editor_validator`.
- `scripts/sim/greybox_map.gd` — `to_dict()` extended with zones/spawns/objectives/jammer; `load_from_string()` static.

### Notes
- `MapLoader.load_from_string(text) -> GreyboxMap` added (per WO spec for the roundtrip gate).

---

## Session 11 — 2026-11-23 — M6 WO completion (Phases A2, J, J2)

### Phase A2 — Re-Audit fixes (WO-N64-R6-AND-M6-REMEDIATION)
- `FogLayer` v2: `live_vp`/`memory_vp` `UPDATE_ONCE` (triggered on change), `fog_mask.gdshader` (live > 0.5 → alpha 0; memory → 50% fog), `mark_visible()` renders full visibility polygons into `memory_vp`.
- `LockstepSession`: `peer.poll()` inside `poll()`, `ticks_since_sync` every tick, `LOCKSTEP_INPUT_DELAY_TICKS` on queued inputs.
- `acoustic_bus.gd` → `tactical_audio.gd` (sim kept pure); `planning_root.gd` `queue_redraw()` on acoustic rings.

### Phase J — MIL-STD C4I UI/UX & RTS-RPG (N64-R6-MILSTD-UI-UX-RTS-RPG-SPEC)
- `ThemeManager` v2: real `Theme` + `StyleBoxFlat`, `theme_changed(palette)`, `applied_theme`; 3 palettes (Dark Tactical/Light Blueprint/Night-Ops).
- `MapRenderer`: MGRS-style coords (columns A–Z, row labels 01–99) + zone overlays.
- `SquadHud`: screen-space `Control` (was a Node2D stub).
- `PlanBoard`: N64 squad palette (red/blue/green/gold).
- `OperativeToken` v2: MIL-STD symbology + LKP ghost dot (`set_lkp`).
- `ExecutionHud`: health dots (green/yellow/red).
- `RosterRolesScreen` v2 + `ArmoryScreen` v2 (bar graphs / slot cards).
- `tests/ui_polish_audit.gd` — audit (theme_apply, squad_hud_control, map_renderer: PASS).

### Finalization
- Pull synced (remote main = 6e512cd); boot smoke + editor clean.

---

## Session 10 - 2026-11-23 - M6 remediation (WO-N64-R6-AND-M6-REMEDIATION Phase A)

### Fog render (CP-061)
- `FogLayer` (`scripts/planning/fog_layer.gd`) redesigned per WO Phase A: two offscreen `SubViewport` masks — `live_vp` (`CLEAR_MODE_ALWAYS`; white `Polygon2D` shapes of visible operative polygons) + `memory_vp` (`CLEAR_MODE_NEVER`) — composited by a full-map `ColorRect` with `fog_mask.gdshader` (live > 0.5 → alpha 0; memory > 0.5 → 0.50 fog; unseen → 0.85 fog); per-cell `Polygon2D` churn + `_map_cells()` CPU loops removed.
- `PlanningRoot._update_fog()` (EXECUTION): cached `map.get_wall_segments()`; `Visibility.compute_polygon(o.pos, segs, LOS_VERTEX_EPSILON_RAD)`; cells inside any poly → `fog.mark_memory(GridUtil.cell_of(o.pos))`; fog visible during EXECUTION (hidden in planning); `fog.reset_fog()` on reset.
- HUD: `_hud` mounted in `CanvasLayer`; Execute/Alpha/Bravo/Charlie/Delta/Reset wired; `_place_hud` sized to fit portrait 1080px width.

### Visibility
- `Visibility.compute_polygon`: rays at `a ± eps` wrapped via `wrapf(..., -PI, PI)` before `rays.sort()`.
- `Visibility._ray_hit_t`: endpoint hits allowed (`t > 0.0 and u >= -0.000001 and u <= 1.000001`) — closes corner-piercing leaks.
- `DeterminismHarness._test_visibility_west_corner_wrap` added (Phase A test).

### CI
- `.github/workflows/headless-ci.yml` — zero-artifact headless CI on push/PR to main: cached Godot 4.0.4-stable Linux headless (`Godot_v4.0.4-stable_linux.x86_64.zip`), two-pass `--import`, boot smoke (grep `ERROR|SCRIPT ERROR|Parse`), determinism harness, simclock probe.

### Verification evidence (Godot 4.0.stable)
```
[HARNESS] fog2_setup live=0
[HARNESS] fog2_live_shapes=1
[HARNESS] fog2_memory_shapes=1
[HARNESS] fog2_poly_contains=true
[HARNESS] fog2_reset_memory=0
[HARNESS] fog2_probe PASS
[HARNESS] visibility_west_corner_wrap PASS (poly=900 t=80.3990)
[TacPlan] boot OK phase=PLANNING fps_cap=30 renderer=gl_compatibility ticks_per_sec=60
```

---

## Session 9 — 2026-11-23 — M6 fog of war (CP-061)

### Fog render
- `FogLayer` (`scripts/planning/fog_layer.gd`, `class_name FogLayer`, Node2D; added to PlanningRoot after MapRenderer): fog cell `Polygon2D`s over every map cell NOT in any visible operative polygon; `MEMORY_COLOR` cell `Polygon2D`s (alpha 0.50) for visited cells; `visible_cells(polys)` / `rebuild(polys, visited)` with change-detection (no shape churn when the sets are unchanged).
- `PlanningRoot._update_fog()` (EXECUTION): per live operative — `Visibility.compute_polygon(o.pos, map.get_wall_segments(), 0.00001)` → `FogLayer.rebuild(polys, visited)` (cells inside any poly marked visited).

### Fix
- `Visibility`: `segments: Array[Array[Vector2]]` → `Array` + `var d: Vector2 = v - observer` (nested-generic param type broke 4.0.0 parse; the class was unresolvable and broke `planning_root` boot).

### Verification evidence (Godot 4.0.stable)
```
[HARNESS] fog_visible size=25 has_c54=true
[HARNESS] fog_rebuild fog=167 memory=0
[HARNESS] fog_memory has_c54=true fog_c54=false
[HARNESS] fog_probe PASS
[TacPlan] boot OK phase=PLANNING fps_cap=30 renderer=gl_compatibility ticks_per_sec=60
```
(16×12 = 192 cells; visible=25, fog=167 ✓; FOG_COLOR alpha 0.62, MEMORY_COLOR alpha 0.50)

---

## Session 8 — 2026-11-23 — M6 fog of war (CP-060)

### Visibility
- `GreyboxMap.get_wall_segments()`: blocker-cell outer faces from `solid_cells` (open-door cells are not blockers; door faces excluded via `is_solid` neighbor check; bounds-clipped).
- `Visibility.compute_polygon(observer, segments, eps)` (`scripts/sim/visibility.gd`, `class_name Visibility`, `RefCounted`): 3 rays/vertex (center ± eps), angular sort, parametric hit valid iff `T1 > 0 ∧ 0 < T2 < 1`, nearest-positive-t hit per ray → closed polygon (G7 rotational sweep-line).
- `DeterminismHarness._test_visibility_sweepline_ioi` (CP-060): 1440-ray brute-force reference vs polygon boundary, `IoU ≥ 0.99`, observer at cell (2,2) center (world px 40,40); harness registered in `_initialize`.

### Verification evidence (Godot 4.0.stable)
```
[HARNESS] cp060_probe segments=180
[HARNESS] cp060_probe poly=720
[TacPlan] boot OK phase=PLANNING fps_cap=30 renderer=gl_compatibility ticks_per_sec=60
```
Notes: harness `godot -s tests/determinism_harness.gd` is silent/hangs in this environment (class-registration + `-s` quirks; the `Visibility` class is not resolvable in `-s` mode); verification ran via inline-math probe (`tests\zz_cp060_probe` — deleted after green). IoU loop itself not executable here; polygon non-empty (720 pts).

---

## Session 7 — 2026-11-23 — M4 fields of fire (CP-043)

### Fields of fire
- `SimWorld._step_operative`: `SET_FIELD_OF_FIRE` now also sets `o.facing_deg = cmd.bearing_deg`; `_step_move` leaves `facing_deg` frozen while `field_of_fire_deg >= 0` (movement-facing override; the FoF arc itself is set on command and stored for LOS).

### Harness
- New `_test_fof_override` (CP-043): op plans `move(5,2) → set_fof(90) → move(7,2)`; asserts `field_of_fire_deg == 90` and `facing_deg == 90` while the op moves (override active) and the op completes; harness 12 → 14 checks.

### Verification evidence (Godot 4.0.stable)
```
[HARNESS] fof_override PASS (done=true override_seen=true)
[HARNESS] RESULT PASS failures=0
```

---

## Session 6 — 2026-11-23 — M4 tactical actions (CP-042)

### Tactical actions
- New `SimEntity` (`scripts/sim/sim_entity.gd`): spawned secondary entity with `due_tick` expiry (journal `entity_spawned`/`entity_effect`).
- `SimWorld._step_action`: FRAG/FLASHBANG/TEAR_GAS spawn a `SimEntity` (FRAG damage: operators within `FRAG_RADIUS_CELLS` cells, owner excluded — deterministic, RNG stays reserved for M7); BREACH_CHARGE keeps the door-breach pending model; cooldown lock (`ACTION_COOLDOWN_TICKS`) set for all actions; invalid actions journal `action_rejected` (bounds/range/door rules).
- `SimConstants`: `ACTION_ENTITY_LIFE_TICKS = 30`, `FRAG_DAMAGE = 25`, `FRAG_RADIUS_CELLS = 2`.
- Entities included in `SimWorld.snapshot_data()`/`restore_from_data()` and `state_hash()` (`Q` part).
- `DeterminismHarness`: new `_test_tactical_actions` (CP-042); harness 12 → 13 checks.

### Verification evidence (Godot 4.0.stable), commit pending
```
[HARNESS] tactical_actions PASS (spawned=3 effects=3 cooldown_seen=true hp_op0=100 hp_op1=75)
[HARNESS] RESULT PASS failures=0
```

---

## Session 5 — 2026-11-23 — M4 stances (CP-040)

### Tactical stances
- Verified against the BP-03 table via `SimOperative.speed_cells_per_sec()`: `STANCE_SPEED_MULTIPLIERS` (blitz 1.6 → 6.4 cells/s, normal 1.0 → 4.0, cautious 0.5 → 2.0) and `STANCE_ACOUSTIC_RADIUS_MULTIPLIERS` (blitz 1.5, normal 1.0, cautious 0.35).
- `DeterminismHarness`: new `_test_stance_table` (CP-040); harness 11 → 12 checks.

### Verification evidence (Godot 4.0.stable), commit 90ef6cd
```
=== GATE 3: determinism harness ===
[HARNESS] command_serialization PASS
[HARNESS] queue_roundtrip PASS
[HARNESS] world_snapshot_roundtrip PASS (restore=true continuation=true)
[HARNESS] determinism_same_seed PASS (hashes_equal=true journals_equal=true completed=true)
[HARNESS] info hashA=1da7aa36441c tickA=467
[HARNESS] rng_state_coverage PASS (hash_changed=true replay_draws_equal=true)
[HARNESS] setup_resets PASS (ops=2 hash_match=true)
[HARNESS] go_code_same_tick PASS (pre0=1 pre1=1 late0=11 late1=11)
[HARNESS] route_pipeline PASS (raw=401 decimated=88 baked=218 waypoints=89 corner_dev=7.39 tail_kept=true)
[HARNESS] camera_clamp PASS (right_ok=true left_ok=true)
[HARNESS] execution_move_adherence PASS (drift_ok=true clip_ok=true final_ok=true pos_ok=true)
[HARNESS] collision_halt PASS (op0_halted=true op1_halted=true op0_done=false)
[HARNESS] stance_table PASS (blitz=6.4000 normal=4.0000 cautious=2.0000)
[HARNESS] RESULT PASS failures=0
```

---

## Session 4 — 2026-11-23 — M5 execution sim slice 1 (A* + adherence + collision halt)

### Execution-phase sim
- New `GridPathfinder` (`scripts/sim/grid_pathfinder.gd`): integer-grid A* on `GreyboxMap` — **D-023** (sim layer is RefCounted per D-018; `AStarGrid2D` is a `Node`).
- `SimWorld._step_move` rewritten: plans A* path (doors pass for planning); per-tick advance along the polyline at stance speed (`speed * 1/60`); blocked cells halt (`move_blocked`/`move_unblocked` journal); `move_start`/`move_end`.
- `SimWorld._step_action`: wall/door/bounds enforcement + `ACTION_MAX_RANGE_CELLS = 6` range check (`SimConstants`); breach-on-door only; invalid actions journal `action_rejected`.
- `SimOperative`: added `halted` + `move_blocked_from`; positions now cell centers in cell units (**D-017** unify; `GridUtil.cell_of`).
- CP-051 collision: `_check_collision` + `_collision_plan` + `_polyline_intersects`/`_segments_intersect`/`_point_on_segment` — intersecting plans halt both (journal `collision_halt`); no avoidance.
- `state_hash()`: op part extended with `halted`, `move_blocked_from`.

### Game wiring
- `PlanningRoot`: owns `SimWorld` (setup on boot/reset); `_physics_process` steps world when EXECUTION (**CP-052**); `_sync_tokens` reads world during physics (CQS); HUD: **Execute / Go-Code: Alpha / Reset**.
- Demo mission: op0 `move(7,2) → cautious → move(7,4)`; op1 `move(13,6) → breach(8,6) → wait alpha → move(2,6)` — breach opens the door (fuse 45) and op1 moves through.

### Harness
- `_plan_op0`/`_plan_op1` updated; new `_test_execution_move_adherence` (**CP-050**) + `_test_collision_halt` (**CP-051**); 9 → 11 checks.

### Verification evidence (Godot 4.0.stable), commit 9adcf79
```
=== GATE 2: headless boot smoke ===
[TacPlan] boot OK phase=PLANNING fps_cap=30 renderer=gl_compatibility ticks_per_sec=60
=== GATE 3: determinism harness ===
[HARNESS] command_serialization PASS
[HARNESS] queue_roundtrip PASS
[HARNESS] world_snapshot_roundtrip PASS (restore=true continuation=true)
[HARNESS] determinism_same_seed PASS (hashes_equal=true journals_equal=true completed=true)
[HARNESS] info hashA=1da7aa36441c tickA=467
[HARNESS] rng_state_coverage PASS (hash_changed=true replay_draws_equal=true)
[HARNESS] setup_resets PASS (ops=2 hash_match=true)
[HARNESS] go_code_same_tick PASS (pre0=1 pre1=1 late0=11 late1=11)
[HARNESS] route_pipeline PASS (raw=401 decimated=88 baked=218 waypoints=89 corner_dev=7.39 tail_kept=true)
[HARNESS] camera_clamp PASS (right_ok=true left_ok=true)
[HARNESS] execution_move_adherence PASS (drift_ok=true clip_ok=true final_ok=true pos_ok=true)
[HARNESS] collision_halt PASS (op0_halted=true op1_halted=true op0_done=false)
[HARNESS] RESULT PASS failures=0
=== CP-052 static: planning_root.gd `_physics_process` → `world.step()` (line 71); token sync same process; no other writes outside physics during EXECUTION ===
```

---

## Session 3 — 2026-11-23 — Audit remediation

### Repo & config cleanup
- Purged 24 stale `game/*` git index entries left behind by S2f (`d631818`), deleted leftover `game\` directory (`node_2d.tscn` + `.godot` cache), and retired dead `scenes/boot.tscn` + `scripts/boot.gd`.
- Updated `.gitignore` (`game/android/` → `android/`) so the Gradle template directory stays untracked.
- Locked `physics/common/physics_ticks_per_second=60` and `rendering/anti_aliasing/quality/msaa_2d=0` explicitly in `project.godot`.

### Android Route A default & toolchain alignment
- Switched `export_presets.cfg` (`gradle_build/use_gradle_build=false`) to Route A (direct export via prebuilt `android_debug.apk`) and created gitignored `builds\` directory.
- Rewrote `docs/BUILD-IN-ANDROID-STUDIO.md` around Route A setup, corrected `adb.exe install` command, rewritten CP-030 1–7 feel-test checklist, and documented why Route B (Gradle 7.4 / AGP 7.2.1 / SDK 32 / build-tools 32.0.0 / NDK 23.2.8568313 / Java 11) is blocked against local JDK 25 (`C:\android\Android Studio\jbr`; `C:\Program Files\...\jbr` missing `lib\jvm.cfg`) and installed SDK platforms 24/31/33–37 (when unblocked, open `android\build`, not `android\`).

### Simulation & planning bug fixes
- `SimConstants`: added `ACTION_FUSE_TICKS = 45` and `ACTION_COOLDOWN_TICKS = 60` (D-020).
- `SimWorld` / `SimOperative`: added `operatives.clear()` in `setup()`; deterministic fixed action fuse (`ACTION_FUSE_TICKS`); uniform 0-tick evaluation for instant commands (`SET_STANCE`, `SET_FIELD_OF_FIRE`, already-issued `WAIT_GO_CODE`) so go-codes release on the exact same tick (D-021); fractional movement remainder `move_carry` across consecutive moves (D-022); strengthened `state_hash()` with `rng.state`, sorted door keys, `done`/`path_index`/`active_path`/`move_carry`, and canonical sorted `_canon()` dict serialization.
- `CommandQueue.reset()`: deep-copies commands and normalizes `operative_id` and `sequence_index`.
- `GreyboxMap`: added `in_bounds()`; out-of-bounds `is_solid()` now returns `true`; `open_door()` ignores non-door cells.
- `RouteSanitizer`: `decimate()` preserves the final endpoint; `bake_smooth()` computes Catmull-Rom tangent handles (`TENSION = 1/6`) for true Bezier smoothing and appends the final endpoint if baked output falls short.
- `MissionCamera`: added viewport-aware `clamp_to_limits()` on configure/pan/zoom/resize (no dead-zone over-pan) and `zoom_about()` pinch focal zoom.
- `OperativeToken`: resized `RADIUS = 6.5` to fit cleanly inside 16 px cells with centered 9 px label.
- `PlanningController`: screen-space `SELECT_RADIUS_SCREEN_PX = 72.0 / zoom.x`, persistent per-operative committed `Line2D`s (`_route_lines`), fixed `_long_fired` use-after-erase bug on release, pinch re-anchoring on finger count changes, incremental drag throttling via `_kept_route`, and minimum 2-point check on commit.
- `PlanningRoot`: added `class_name PlanningRoot`, live `SimClock.phase` in boot log, token `z_index = 1`, and `viewport.size_changed` camera wiring.
- `DeterminismHarness`: expanded from 5 to 9 checks (replaced invalid cross-seed/endpoint checks; added `rng_state_coverage`, `setup_resets`, `go_code_same_tick`, `corner_dev` + `tail_kept`, and `camera_clamp`).

### Verification evidence (Godot 4.0.stable)
```
=== GATE 1a/1b: editor import pass 1 & 2 ===
WARNING: Custom cursor shape not supported by this display server.
WARNING: Blend file import is enabled in the project settings, but no Blender path is configured in the editor settings. Blend files will not be imported.
=== GATE 2: headless boot smoke ===
[TacPlan] boot OK phase=PLANNING fps_cap=30 renderer=gl_compatibility ticks_per_sec=60
=== GATE 3: determinism harness ===
[HARNESS] command_serialization PASS
[HARNESS] queue_roundtrip PASS
[HARNESS] world_snapshot_roundtrip PASS (restore=true continuation=true)
[HARNESS] determinism_same_seed PASS (hashes_equal=true journals_equal=true completed=true)
[HARNESS] info hashA=da8bd1b730b7 tickA=691
[HARNESS] rng_state_coverage PASS (hash_changed=true replay_draws_equal=true)
[HARNESS] setup_resets PASS (ops=2 hash_match=true)
[HARNESS] go_code_same_tick PASS (pre0=1 pre1=1 late0=11 late1=11)
[HARNESS] route_pipeline PASS (raw=401 decimated=88 baked=218 waypoints=89 corner_dev=7.39 tail_kept=true)
[HARNESS] camera_clamp PASS (right_ok=true left_ok=true)
[HARNESS] RESULT PASS failures=0
=== GATE 4: simclock probe ===
[PROBE] planning_cap=30
[PROBE] execution_cap=60 phase=1
[PROBE] back_to_planning_cap=30 phase=0
=== GATE 5: BOM check ===
BOM_COUNT=0
```

---

## Session 2f — 2026-08-26 — Flat repo restructure (`d631818`)

- Moved Godot project root from `game\` to repository root (`project.godot` at root, `android\` Gradle template beside it), set `export_presets.cfg` (`com.tacplan.game`, `orientation=1`, `gradle=true`), and updated `docs\BUILD-IN-ANDROID-STUDIO.md` for root-level paths.

---

## Session 2d — 2026-08-25 — EXPORT RESCUE (user hit greyed-out Export button)

- **Debug keystore generated FOR the user** at `C:\android\keystores\tacplan-debug.keystore` via Studio's keytool (alias androiddebugkey / pass android / RSA 3072 / 9999d). User pastes path+user+pass into Editor Settings → Export → Android. Keystore stays OUTSIDE repo forever.
- Preset flipped `use_gradle_build=false` → Route A (direct export) needs NO Java, NO gradle template — kills two of the three grey-out warnings permanently for first boot.
- `docs\BUILD-IN-ANDROID-STUDIO.md` rewritten around the user's EXACT three warning lines: templates fix = Manage Export Templates → "Download and Install" (~1 GB, one-time); gradle-template warning = ignore for Route A; keystore = paste values.
- Remaining user actions: click Download-and-Install templates → paste keystore values → Export Project → adb install.

---

## Session 2c — 2026-08-25 — ANDROID TRACK PULLED FORWARD (user priority: phone NOW)

**User clarification locked in: this is an Android deliverable, full stop. The PC "run" mentioned in S2b is only a dev-preview of the same portrait/touch scene (Godot authoring happens on PC; the RTF's mandated OpenGL ES pipeline IS the Android one). No Windows target exists anywhere.**

### Shipped
- `game\export_presets.cfg` — Android preset: ARM64-only, portrait (orientation=1), package `com.tacplan.game` (D-010 default until user renames), gradle_build=true, immersive mode, debug export → `builds\TacPlan-debug.apk` (gitignored)
- `docs\BUILD-IN-ANDROID-STUDIO.md` — complete user walkthrough: 2-minute editor setup (Java = Studio JBR, SDK = C:\android\sdk), one-click Gradle template install, Route A (Godot direct export) vs Route B (Android Studio), adb install, CP-030 feel-test script, troubleshooting table

### Status effect
- M10/BP-10 flipped 🔄 ACTIVE: structural half of CP-100 passed (presets valid, no signing tracked); remaining gates CP-100 final + CP-101 are USER device runs
- User can have the game on their phone TODAY via Route A (~3 minutes total)

---

## Session 2b — 2026-08-25 — M3 Planning Phase v1 SHIPPED (CP-031 PASSED)

**The C4I terminal exists: blueprint map renders, operatives stand ready, routes draw under your finger.**

### AUTO-COMMIT LAW ADOPTED
- User granted standing approval — commits happen automatically after each verified phase/gate batch. Codified in RULES §5.2 / AGENTS.md / CLAUDE.md.
- S2 committed as e93e535.

### New planning layer (`game\scripts\planning\`)
- `grid_util.gd` — central px↔cell conversion utility (RULES §4 law honored)
- `route_sanitizer.gd` — decimation threshold 12px → Curve2D bake_interval 8px → baked points (G10 pipeline exactly per blueprint)
- `plan_board.gd` — planned route storage per operative (feeds AgentCommand construction in M4/M5)
- `mission_camera.gd` — pan/pinch ortho camera, map limits, zoom clamp 1–8×, fit-to-map configure
- `map_renderer.gd` — blueprint aesthetic: dark floor, faint blue grid lines, solid tiles, amber/green door state
- `operative_token.gd` — circle token + selection ring + id label
- `planning_controller.gd` — THE gesture state machine: OBSERVATION (1-finger pan, 2-finger pinch) ↔ ROUTING (long-press 0.45s near token); live preview Line2D while drawing (`antialiased=false` G6, round joints); release = sanitize→board→commit signal
- `planning_root.gd` + `scenes/planning.tscn` — full assembly; **now the main scene** (boot print preserved for gate continuity)
- project.godot: `emulate_touch_from_mouse=true` → desktop mouse testing works TODAY

### Verification
- Boot smoke through FULL planning scene: ZERO errors, boot line intact
- Harness 5/5 PASS — new route_pipeline test: synthetic noisy stream 401 pts → 88 decimated → 213 baked → 86 waypoints; deterministic re-run; endpoints kept; first-cell sane

### Notes
- Tap-to-cell mode currently produces straight polylines — AStarGrid2D pathing lands with BP-04/M5 (noted in BP-05 decision D-012)
- CP-030 (modal camera feel) code-complete; visual/touch verdict awaits USER desktop run

---

## Session 2 — 2026-08-25 — M2 Deterministic Sim Core LIVE (CP-020/021/022 PASSED)

**Replays are now hash-proven deterministic. The Command Pattern core exists and the greybox mission runs end-to-end headless.**

### Housekeeping
- **First commit approved & made: b0b45a8** (11 files — governance suite + Godot skeleton)
- **D-009 RESOLVED: portrait primary** — viewport 1080×1920, `window/handheld/orientation=1`, desktop window override 486×864
- Config autoload dissolved → static `SimConstants` class (D-019; single tuning surface reachable from game AND script mode); autoloads now SimClock+EventBus only

### New sim layer (`game\scripts\sim\` — pure RefCounted, ZERO autoload refs, D-018)
- `agent_command.gd` — 5 command types (MOVE_TO_CELL / SET_STANCE / WAIT_GO_CODE / PERFORM_ACTION / SET_FIELD_OF_FIRE) + ActionKind enum; dict round-trip
- `command_queue.gd` — per-operative queue w/ cursor; serialization preserves position
- `sim_operative.gd` — stance-driven speed from SimConstants table; FoF facing override; wait state
- `greybox_map.gd` — 16×12 fixture: border walls, x=8 wall, breachable door at (8,6); is_solid() door-aware
- `sim_world.gd` — THE deterministic sim: tick-stepped command consumption, movement interpolation along planned vectors (IEEE-only math), go-code waits, seeded-RNG breach fuses → pending-event door opening, tick-indexed journal
- `mission_snapshot.gd` — capture/restore wrapper over world snapshot_data (incl. rng seed+state)

### Tests (`game\tests\`)
- `determinism_harness.gd` — SceneTree `-s` mode, 4 tests ALL PASS:
  - command_serialization PASS · queue_roundtrip PASS
  - world_snapshot_roundtrip PASS (restore hash-exact + post-restore continuation matches uninterrupted run)
  - determinism_same_seed PASS (pair hashes+journals identical; cross-seed diverges)
- `simclock_probe.tscn/.gd` — CP-020 evidence: caps flip 30→60→30 across phase transitions

### Mission fixture result (info)
Two-operative plan completes tick 692: op1 breaches door (fuse via seeded RNG), both hold for Alpha @300, release same-tick, op0 ends under FoF bearing 270. Door state mutation flows through snapshots/hashes.

### Gotchas learned
- **G16: first-import class-cache quirk** — adding a NEW `class_name` referenced by existing scripts fails ONE import ("Identifier not declared in current scope") because autoloads compile before the global class cache refreshes. Run editor-import twice before judging.
- PowerShell stderr wrapping prints cosmetic `NativeCommandError` records around Godot's stderr — filter on actual message text, not record headers.

---

## Session 1 — 2026-08-25 — M1 Godot Skeleton LIVE (CP-010/011/012/013 PASSED)

**User installed Godot → `C:\Godot`. Project now boots headless clean with renderer locked.**

### Tooling verified
- `C:\Godot\Godot_v4.0-stable_win64_console.exe` → `4.0.stable.official.92bee43ad` (console twin used for all gates)

### Created (`game\` Godot project root)
- `project.godot`: gl_compatibility forced BOTH desktop+mobile · physics 60 Hz · landscape (D-009 assumed) · canvas_items/expand stretch · input map scaffold (`ui_pan`, `ui_pinch_zoom`, `operative_longpress`, `node_tap`, `commit_plan`) · etc2_astc VRAM compression
- Autoloads (Genesis headers only, no other comments): `config.gd` (cell 16 / caps 30·60 / stance multiplier tables / go-codes / LOS epsilon 0.00001) · `event_bus.gd` (typed signals: phase_changed, plan_committed, tick_advanced, go_code_issued, operative_halted, operative_damaged, breach_detonated) · `sim_clock.gd` (Phase enum, tick authority via `_physics_process`, Engine.max_fps applied per phase)
- `scenes/boot.tscn` + `scripts/boot.gd` smoke print

### Verification evidence
- Per-script `--check-only`: config/event_bus PARSE CLEAN exit 0. sim_clock/boot FAIL there by design → **G-law discovered:** `--check-only --script` compiles standalone WITHOUT autoload globals; cross-autoload refs can't resolve in that mode.
- Authoritative gate: `--headless --path game --quit` → **ZERO error lines**, boot line `[TacPlan] boot OK phase=PLANNING fps_cap=30 renderer=gl_compatibility ticks_per_sec=60`
- **G15 proven via empty-project control:** 4.0 `--quit` ALWAYS exits code 1 even clean → exit codes banned as pass/fail; log filtering is the signal.
- Bonus G14 reinforcement: PowerShell `Set-Content -Encoding utf8` wrote a BOM that broke a control `.tscn` ("Expected '['" at char 1). File tools or BOM-free writes only; check first bytes when parse errors point at char 1.

### Status
- ROADMAP: M0 ✅ · M1 ✅ · next M2 deterministic sim core (AgentCommand serialization, MissionSnapshot, replay determinism harness CP-021/022)
- First commit still awaiting user approval.

---

## Session 0 — 2026-08-25 — Foundation & Governance Day

**Goal:** Ingest the architectural blueprint RTF, adopt sibling-project governance patterns, create the tailored file set, plan everything.

### Discovered / decided
- Source doc read in full: `Tactical Android Game Development.rtf` (Aspose-generated RTF; extracted cleanly via .NET RichTextBox → `blueprints\architecture-blueprint-source.txt`)
- Engine mandated by source: **Godot 4**, Compatibility renderer (OpenGL ES 3.0) — NOT Unity/Flutter despite sibling projects
- Environment verified: Android Studio ✅ (`C:\Program Files\Android\Android Studio`), SDK/NDK ✅ (`C:\android\sdk`), Flutter present-but-unused (`C:\src`), **Godot ❌ missing — user action required**

### Created (governance layer)
- Root: `RULES.md` (operating law w/ 14 technical laws distilled from the blueprint), `CLAUDE.md`, `AGENTS.md`, `README.md`, `.gitignore` (Godot/Android aware; blueprints unversioned per house rule)
- `blueprints\`: `SESSION_HANDOFF.md`, `CURRENT_STATE.md`, `CHANGELOG.md`, `CHECKLIST.md`, `CHECKPOINTS.md` (gates CP-001…CP-101), `ROADMAP.md` (M0→M10), `BLUEPRINTS.md`
- `blueprints\blueprint-sections\`: BP-01…BP-10 engineering canon encoding EVERY recommendation in the RTF:
  - BP-01 project foundation · BP-02 deterministic sim core (Command Pattern/CQS/replays)
  - BP-03 tactical vocabulary (routes/stances/go-codes/actions/fields of fire)
  - BP-04 AStarGrid2D navigation (no RVO) · BP-05 touch UI/UX (modal modes/loupe/radial)
  - BP-06 sweep-line visibility + fog of war · BP-07 mobile perf/battery
  - BP-08 audio design · BP-09 mission content/enemy AI · BP-10 Android build/release
- Reserved `game\` (Godot project root, M1) and `docs\`

### Git
- Initialized repo on branch `main`. Zero commits (first commit awaits approval). Explicit-path staging law active.

### Decisions logged
- D-001 Godot 4 + Compatibility renderer locked · D-002 AStarGrid2D ~16 px integer grid
- D-003 strict path adherence (no RVO) · D-004 Command Pattern + CQS + replay reset-and-feed
- D-005 fixed 60 Hz tick · D-006 typed GDScript (no C#) unless overridden
- D-007 Godot project lives in `game\` subfolder · D-008 blueprints stay unversioned
- OPEN: D-009 orientation (landscape assumed), D-010 package id (`com.tacplan.game` proposed)

### Blockers handed to user
- Install Godot 4.x stable → record exe path in `CURRENT_STATE.md` tooling table (gate CP-010)

---
