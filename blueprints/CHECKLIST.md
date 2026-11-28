# CHECKLIST.md — Main Execution Checklist
Single source of truth for "what's next". Grouped by milestone; each item cites its BP + gate.
Legend: ⬜ todo · 🔄 doing · ✅ done (gate passed) · ⏸️ blocked

## M0 — Foundation & governance (BP-01)
- ✅ Extract RTF → `blueprints\architecture-blueprint-source.txt` (canonical design text)
- ✅ Root governance: RULES.md / CLAUDE.md / AGENTS.md / README.md / .gitignore (CP-002)
- ✅ blueprints\ set: HANDOFF, STATE, CHANGELOG, CHECKLIST, CHECKPOINTS, ROADMAP, BLUEPRINTS
- ✅ BP-01…BP-10 engineering canon derived from source document
- ✅ Reserve `docs\`; repo initialized branch main (CP-003)

## M1 — Godot project opens clean (BP-01)
- ✅ **USER**: install Godot 4.x stable, record exe path in CURRENT_STATE.md (CP-010) — 4.0.stable @ `C:\Godot`
- ✅ Create `project.godot` (originally `game\project.godot`, flattened S2f): `gl_compatibility` forced desktop+mobile, 60 Hz physics tick, input map scaffold (CP-011)
- ✅ Autoload stubs: SimClock, EventBus (Config dissolved into SimConstants S2; Genesis headers per RULES §3.2) (CP-013)
- ✅ Headless parse gate passes: zero errors on project import smoke test (CP-012)
- ✅ First commit approved: b0b45a8 (11 files — root docs + skeleton, portrait primary)

## M2 — Deterministic sim core (BP-02)
- ✅ SimClock fixed-tick authority verified incl. FPS cap flips 30↔60 via probe scene (CP-020)
- ✅ `AgentCommand` resource + serialization round-trip identical (CP-021)
- ✅ Per-operative command queues (CommandQueue, deep-copy `reset()`, cursor-preserving round-trip)
- ✅ MissionSnapshot: capture/restore incl. RNG seed+state, door states, journal; replay reset-and-feed (CP-022)
- ✅ Determinism harness: same-seed pair identical hashes+journals; strengthened `state_hash()` + `rng_state_coverage` + `setup_resets` + `go_code_same_tick` (CP-022, CP-023)
- ✅ Sim layer kept autoload-free/pure (RefCounted classes, `-s` SceneTree testable)
- ✅ Second commit approval: M2 sim core + tests (e93e535)

## M3 — Planning phase v1: observation & routes (BP-03 + BP-05)
- ✅ Observation camera rig: one-finger pan, two-finger pinch focal ortho zoom, clamped `position` (no dead zone, CP-032), viewport resize sync; plan-edit lock via modal state machine (logic complete — CP-030 verdict ⬜ USER)
- ✅ Operative selection via long-press (screen-space hit radius 72 px / zoom; camera finger-offset nudge deferred to M8 polish)
- ✅ Route draw pipeline: decimation (tail preserved) → Catmull-Rom Curve2D Bezier → baked points → Line2D (G10) — CP-031 re-PASSED 2026-11-23 (`corner_dev=7.39`, `tail_kept=true`)
- ✅ Planning board stores committed cell-waypoint routes per operative; persistent per-operative `Line2D`s
- ✅ Tap-to-cell strict mode: freehand Curve2D Bezier ships alongside `PlanningController.commit_tap_cell()` A* pathing (M3 L33)
- ✅ Desktop testing enabled: emulate_touch_from_mouse=true

## S3 — Audit remediation (2026-11-23)
- ✅ Purge 24 stale `game/*` index entries, delete leftover `game\` dir, retire `scenes/boot.tscn` + `scripts/boot.gd`, ignore `android\` in `.gitignore`, lock `physics_ticks_per_second=60` and `msaa_2d=0` in `project.godot`
- ✅ Switch `export_presets.cfg` to Route A (`use_gradle_build=false`), create `builds\`, rewrite `docs\BUILD-IN-ANDROID-STUDIO.md` (Route A default + Route B toolchain mismatch)
- ✅ Fix M2 sim bugs (`SimConstants` fixed fuses, `SimWorld.setup()` operative clear, 0-tick instant commands, `move_carry`, strengthened `state_hash()`, `CommandQueue.reset()` deep copy, `GreyboxMap.in_bounds()`)
- ✅ Fix M3 planning bugs (`RouteSanitizer` Catmull-Rom handles + tail endpoint, `PlanningController` per-op routes + `_long_fired` release bug + pinch anchor + screen-space select + incremental drag, `MissionCamera` clamp + focal zoom, `OperativeToken` 6.5 px radius, `PlanningRoot` `class_name` + live phase + resize)
- ✅ Expand `DeterminismHarness` to 9/9 PASS; sync docs + `blueprints\`

## M4 — Full plan vocabulary (BP-03 + BP-05)
- ✅ Stances: Blitz / Normal / Cautious (velocity multiplier + acoustic radius table) (CP-040)
- ✅ Go-codes Alpha/Bravo/Charlie: conditional wait nodes halt queue until issued (CP-041; `SimWorld.issue_go_code` emits `EventBus.go_code_issued` for UI confirmation)
- ✅ Tactical actions: flashbang / frag / tear gas / breach charge as spawned entities + cooldown lock (CP-042)
- ✅ Fields of fire: facing override independent of movement vector ("slicing the pie") (CP-043)
- ✅ Radial command node menu along bottom arc (thumb reach); progressive disclosure (M4 line 48; `scripts/ui/radial_menu.gd` opened on right-tap; wired in `PlanningRoot._setup_hud` → `_on_radial_go_code` → `world.issue_go_code`)

## M5 — Execution sim v1 (BP-02 + BP-04)
- ✅ Movement interpolation strictly along planned vectors at stance speed (CP-050)
- ✅ Strict path adherence: intersecting plans collide & halt both agents (NO avoidance) (CP-051)
- ✅ Go-code sync: multi-team simultaneous breach resolves frame-exact (CP-041 flipped; burst-sync edge cases deferred to M6+; `SimWorld.go_code_ready()` + zero-tick WAIT_GO_CODE check in `step()`)
- ✅ Execution runs entirely inside `_physics_process()`; render layer read-only (CQS audit) (CP-052)
- ✅ Wall/door/bounds enforcement in SimWorld moves and actions
- ✅ Unify sim cell-corner vs render cell-center coordinates
- ✅ Freehand→AStarGrid2D repair contract
- ✅ Action range check

## M6 — Visibility & fog of war (BP-06)
- ✅ Segment extraction + vertex aggregation from level geometry (`GreyboxMap.extract_segments()`)
- ✅ Rotational sweep-line visibility polygon: 3 rays/vertex, T1>0 ∧ 0<T2<1, angular sort (CP-060 — verified: segments=180, poly=720)
- ✅ Rotational sweep-line visibility polygon: 3 rays/vertex, T1>0 ∧ 0<T2<1, angular sort (CP-060 — verified: segments=180, poly=720)
- ✅ Phase A (WO-N64-R6-AND-M6-REMEDIATION): FogLayer SubViewport masks (fog2 probe PASS: live=1, memory=1, poly_contains=true, reset=0); Visibility wrapf + endpoint tolerance (WCW PASS: poly=900 t=80.3990); HUD CanvasLayer + Alpha/Bravo/Charlie/Delta wired; Zero-Artifact CI (`.github/workflows/headless-ci.yml`)
- ✅ Visited-memory additive buffer @50% opacity (mark_visible → memory_vp, Phase A2)
- ✅ Phase J: ThemeManager v2 (real Theme + StyleBoxFlat, theme_changed, applied_theme), MapRenderer MGRS coords (A–Z, 01–99) + zone overlays, SquadHud screen-space Control, PlanBoard N64 squad palette (red/blue/green/gold), OperativeToken MIL-STD symbology + LKP ghost dot, ExecutionHud health dots, RosterRolesScreen + ArmoryScreen, `ui_polish_audit` PASS
- ✅ Planning smoke covers exact token tracking, live contacts, last-seen positions, and fog reset.
- ✅ Verify frame time and fog compositing on a mid-range Android handset (BLU `B160V`, Android 14 API 34, `PowerVR Rogue GE8300`, `720x1612` portrait: GPU `FogLayer` live sight + 50% visited memory verified clean; SurfaceFlinger `BLAST` layer `refresh_ms=16.67`, `samples=126`, `avg_ms=33.13`, `median_ms=33.67`, `p95_ms=50.52`, `0` shader/GL errors).

## M7 — Enemy AI & mission loop (BP-09)
- ✅ Patrol routes + idle/chase states; detection = visual cone (LOS-gated) + acoustic radius vs stance noise (CP-070)
- ✅ Engagement resolution deterministic (seeded RNG for spread/reaction only)
- ✅ Phase L: AAA Tactical CPU & GOAP Squad AI (`InfluenceMap`, `GoapActions`/`GoapPlanner`, `SquadTactics`, `CpuCommander`, bounding overwatch, anti-drone & tactical reload) (CP-072)
- ✅ Timeline & replay scrubbing (CP-071): `AarScreen` journal timeline + `ReplayScrubber` HSlider + `PlanningRoot.scrub_replay_to_tick()`, verified in `scene_smoke.tscn` (CP-071)
- ✅ Fatal funnels emphasis: doorway chokepoint encounters authored into map data (`op01_glass_house.json` `[5, 2]`, loaded by `MapLoader`) + `SimWorld.record_funnel_encounter()` journal entries (M7 line 75).
- ✅ Multi-floor stair links & upper-floor combat/AI/fog (`OP-05`–`OP-10`, CP-073): `GreyboxMap` floor slices, `MapLoader` bidirectional `stair_links`, `AgentCommand.USE_STAIRS`, `SimWorld`/`CombatSystem`/`AiCoordinator` floor isolation, `PlanningRoot` `F1/N` switcher + auto-ascend (`scene_smoke` + BLU `B160V` `OP-05` verified).

## M8 — Touch UX polish (BP-05)
- ✅ PiP magnifier loupe during routing (`PipLoupe` 3x under-finger magnifier mounted on HUD canvas — CP-080 USER verified on BLU `B160V`)
- ✅ Camera auto-offset so finger never occludes selected operative (`MissionCamera.set_finger_offset` + edge nudge on routing start; CP-080)
- ✅ Touch UX de-clunking: `0.28 s` hold / `24 px` hold slop, `RoutePlanner.repair_freehand_waypoints`, `DRAW`/`TAP` mode toggle, compact above-map `_node_menu` (`CLEAR NODE` + `DONE`), `TacticalVfx` live tracers/flashes/rings, and translucent replay `AarScreen` (`GRADE` + `+RP` + `NEXT OPERATION`).
- ✅ UI texture atlas pass; MultiMesh props placement tooling (M8 line 80): `scripts/planning/props_placement.gd` (`MultiMeshInstance2D` + `QuadMesh`, spawn/defender markers, `rebuild()`).

## M9 — Audio pass (BP-08)
- ✅ Audio bus layout w/ ducking: breach/explosion compresses ambient bus (`CP-090` PASS — `TacticalAudio._duck_ambient(0.45)` on `EventBus.breach_detonated`, recovers via `_unduck`)
- ✅ Randomized radio squelch + telemetry blips on planning UI ops (`TacticalAudio.play_blip` / `_play_squelch`, verified in `ui_audio_smoke.gd`)
- ✅ Damage → heartbeat synth drives LowPassFilter over `Ambient` bus (`TacticalAudio._on_operative_damaged`, cutoff scaled by HP peak, verified in `ui_audio_smoke.gd`)

## M11 — 5-ft 2.5D Engine & Tileset Themes (WO-25D, CP-103)
- ✅ OP-01 expanded to `32x24` 5-ft compound with edge-to-edge exterior apron, 4 named breach entries, and 5 authored chokepoints.
- ✅ Planning gridlines changed to `Color(0.06, 0.14, 0.20, 0.14)`; hidden completely during EXECUTION.
- ✅ `TilesetTheme` contract + 5 registry palettes; map JSON `tileset_theme` field round-trips through `GreyboxMap`/`MapLoader` and colours `MapRenderer`.
- ✅ `scripts/view3d/` HD-2D view reads live `SimWorld` state only: batched MultiMesh floors/walls, Sprite3D actors, wall cutaway, 88°/52°/20° pitch, 90° yaw snap, toggle with zero sim rewrite.
- ✅ Headless evidence: `parse_all` 100/15, `scene_smoke`, `map_validation`, `tileset_theme`, determinism, AAA, meta, audio, fog gates green.

## M12 — Replay portability (WO-REPLAY-MANIFEST-PORTABILITY, CP-104) — SPEC'D, PENDING IMPLEMENTATION
- ✅ `ReplayManifest` schema v1: tick-0 snapshot + tick-indexed go-code/override stream + `final_state_hash` + `journal_digest` + `integrity_hash` (`scripts/sim/replay_manifest.gd`) — CP-104A PASS.
- ✅ `ReplayPlayer.replay_into` re-issues inputs at `tick - 1` via `schedule_go_code()` / `apply_override()`; harness proves direct stream injection diverges (CP-104B PASS). `PlanningRoot.scrub_replay_to_tick()` unification deferred to Phase 2.
- ⬜ `ReplayStore` atomic save/load with `.bak`, size/event/tick caps and sanitized filenames (`scripts/meta/replay_store.gd`, CP-104A/C). Filename/tick/event caps live in `ReplayManifest` today.
- ⬜ AAR `SAVE REPLAY` + `REPLAYS` screen with watch/import/copy/delete and verified-playback badge (CP-104D USER).
- ✅ `tests/replay_manifest_harness.gd` added to Headless CI (27 → 28 steps, run `46172399208` success, replay step green); CP-104A/B/C green, CP-104D USER pending.

## M10 — Android release track (BP-10) — ACTIVE (Route A default)
- ✅ Route A clean-checkout preset verified with Godot 4.0.4, ARM64 packaging, signature, and all ten source maps (CP-100).
- ✅ Handoff doc rewritten: `docs\BUILD-IN-ANDROID-STUDIO.md` (Route A walkthrough, `adb.exe install`, CP-030 1–7 test script, Route B blocker details)
- ✅ Install Route A debug APK (`builds\TacPlan-debug.apk`) on physical Android device (`BLU B160V`, `7040016025040287`) and verify boot + touch planning/execution/AAR/editor controls (CP-101, CP-030).
- ✅ Update `CHANGELOG.md` + `CHECKPOINTS.md` + N64 Mission Prep 5-tab flow (`scenes/prep.tscn` + `MissionPrepScreen`: `BRIEF`/`INTEL`/`ROSTER`/`KIT`/`SQUAD`) + RPG `ArmoryScreen` RP unlocks + `ProgressionSave` (`CP-074`)
- ✅ Live Tap-In Direct Control (`TapInController.ingest_cell_target` + `REL AI` + `override_stream` replay) and 2-Player Co-Op/PvP Lobby (`TitleScreen` 7/7 enabled -> `scenes/two_player.tscn` / `TwoPlayerScreen` Pass-and-Play SHA-256 `CommitReveal` + LAN `LockstepSession` UDP 7600, `CP-075`)
- ✅ Device UI walkthrough (`CP-102`): Route A APK (`INTERNET` + `ACCESS_NETWORK_STATE`, `28,399,175` B, `apksigner` v1/v2/v3 PASS) installed & live-verified via screencap + `logcat` on BOTH **Moto G 2025** (`ZT4222BMWN`, `720x1604`) and **BLU `B160V`** (`7040016025040287`, `720x1612`) with `0` errors
- ⬜ Route B requires JDK 11 and the SDK platform, build-tools, and NDK versions pinned by the generated template.
- ⬜ Release signing flow (deferred until store-ready; debug keystore only, never committed)

