# WORK ORDER: UI/UX & Feature Audit Remediation (2026-11-24)
Repo: GhostMan612/TacPlanShooter · Governing law: `RULES.md` (full files, Genesis header only, typed GDScript, stage by explicit path, no binaries).

## 0. Why this exists
A full audit on 2026-11-24 found that the vertical-slice loop (Splash → Title → Planning → Execute → AAR) broke at almost every step. Several items marked done in `SESSION_HANDOFF.md` / `CURRENT_STATE.md` were not true: Headless CI had **never passed** (54 failed and 4 cancelled runs; the five harness steps after the determinism one were always skipped; import-log parse errors were never gated).

## 1. Audit findings (condensed)

### Blockers (loop-breaking)
| # | Finding | Where | Step |
|---|---|---|---|
| B1 | Title buttons looked up string keys in an int-keyed dict; Godot 3 `rect_*` props; 3 buttons stacked at (0,0); HQ/Settings/Credits reloaded Title | `scripts/ui/title_screen.gd` | 2 |
| B2 | `squad_hud.gd` failed to compile (static access to instance `PALETTES`, `:=` from Variant) → Planning HUD dead | `squad_hud.gd:13,85` | 1 |
| B3 | `enum Panel` shadows native class → compile error | `mission_prep_panels.gd:9` | 1 |
| B4 | Drawn routes never reach the sim (`route_committed` unconnected); Execute always runs `_demo_plan_op0/1` | `planning_root.gd` | 4 |
| B5 | Walls load only segment start cell (`w["a"]`); wall-face test inverted → LOS/fog see through walls & closed doors | `map_loader.gd:25`, `greybox_map.gd:70` | 3 |
| B6 | Map Editor scene put `script=` in the node header (ignored) → blank screen; editor had no Back | `scenes/map_editor.tscn` | 2 |
| B7 | No death (`health=kia` never set) and no success condition → AAR unreachable; AAR was a zero-size world-space Control | `sim_world.gd`, `planning_root._maybe_aar` | 6 |

### HUD / overlays
- Squad HUD forced 1080×120 over the action bar with `MOUSE_FILTER_STOP` → Execute/Go-Code/Reset unclickable; rows built in `_ready()` while `world == null` (no dots); every op in all 4 squads. **(Step 1/5 — fixed in PR #1)**
- `PlanBoard.SQUAD_COLORS` used 0–255 ints in `Color()` → all white. **(fixed in PR #1)**
- Theme never applied (orphan Node, `set_stylebox` args reversed, bogus `normal_font_color`, renderer palette never wired, no persistence). **(fixed in PR #1)**
- Acoustic rings: `queue_redraw()` inside `_draw()` is a no-op in Godot 4 and rings draw under the map floor fill. Editor invalid-cell overlay had the same layering bug. **(editor fixed in PR #1; rings → Step 5)**
- Fog: per-tick O(cells × poly) CPU scan + one `Polygon2D` per memory cell (violates RULES §4 G8); stale fog after Reset; pixel/cell unit mix in `mark_visible`. **(Step 5)**
- Tokens: no squad colour/callsign/facing/dead state; cell-snapped motion; hostiles/hostages never rendered. **(Step 5)**
- Go-Code buttons mutate sim state from UI handlers (CQS / RULES §4) and work during planning. **(Step 4)**
- No radial command menu (tap waypoint prints a stub), no PiP loupe, no Undo/Clear, routing active during execution. **(Step 7)**

### Readability & touch
- No font sizing (16 px on a 1080-wide canvas ≈ 1 mm), touch targets 32–64 px (Android minimum 48 dp ≈ 126 px), no backgrounds, Android Back quit the app, `button_down` used instead of `pressed`. **(fixed in PR #1)**

### Other features (sim / AI / net / data / tests)
- Enemy vision: `threat_blackboard.gd:84` treats any wall hit at t>0 as blocking; `ai_coordinator.gd:35,57` uses `world.operates`; no enemies are ever spawned.
- Tap-in: each per-tick override spends a CP and a 720-tick cooldown; speed applied twice; walks through walls.
- Snapshot/restore and `setup()` reset incomplete (entity ids, tap-in state, drones).
- Lockstep: no transport, inputs untimed, hashes never compared; `CommitReveal` unused.
- Map data: zone cells on boundary walls (op07/08/10), op04 jammer inside wall, op09 doors on no wall, op01 hostage/guard share a cell; floors/stairs/locks/jammers/lighting not loaded.
- Tests: `ui_polish_audit` never called `apply()`; `map_editor_harness` had a parse error and wrong API; several determinism/meta cases are wrong or tautological (`_test_ballistics` expectation, float `==` in acoustic test, `_test_override_replay` hash, `poly.size() >= 0`).
- Audio/VFX classes are `pass` stubs and never instantiated.

## 2. Phased plan & gates

| Step | Scope | Gate (CI) | Status |
|---|---|---|---|
| 1 | Everything compiles; CI gates import/parse errors and runs every harness | `parse_all.tscn` → `[PARSE_ALL] RESULT PASS`; every step runs with `if: !cancelled()` | **PR #1** |
| 2 | Every screen reachable with a way back; Map Editor functional (export/import/playtest, 4-check validator) | `scene_smoke.tscn` → `[SMOKE] RESULT PASS` | **PR #1** |
| 3 | Rasterize wall segments a→b; fix wall-face test; door lock states | determinism + map_validation harness with real wall counts | pending |
| 4 | `route_committed` → `AgentCommand` queues; spawns from insertion zones; go-codes enqueued per tick (CQS) | new harness: drawn route == executed path; replay hash stable | pending |
| 5 | Tokens (squad colour, callsign, facing, KIA/halt), hostile/LKP rendering, fog GPU memory buffer, acoustic rings on an overlay layer, squad-coloured routes | scene_smoke layout + perf budget probe | pending |
| 6 | KIA from hp, mission success/failure, AAR screen (CanvasLayer, Replay/Retry/Next/Title) | harness: frag kill → AAR; objective complete → AAR | pending |
| 7 | Radial command menu, enemies (spawn + perception fixes), tap-in redesign, audio/VFX, lockstep transport | per-feature harnesses | pending |

## 3. Device notes for the USER
- Android export preset → Resources → **include filter `*.json`**, otherwise `data/maps/*.json` is not packed and Planning falls back to the greybox map.
- Settings persist in `user://settings.json`; custom maps in `user://custom_maps/`.
