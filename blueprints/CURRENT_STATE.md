# CURRENT_STATE.md — Component Inventory Snapshot
**Snapshot date:** 2026-11-26 (Session 23 — WO-25D Steps 1 & 2, CP-103; was Session 21 — Mission Prep, Armory RP Unlocks, Live Tap-In & 2-Player Co-Op/PvP Lobby)

## Repo layout (`C:\TacPlan Shooter\`)

```
├── .gitignore                        ← ignores temporary exports and signing settings
├── RULES.md                          ← canonical operating law
├── CLAUDE.md / AGENTS.md / README.md ← agent & repo guidance
├── project.godot                     ← GODOT 4 PROJECT ROOT — portrait primary (D-009), gl_compatibility, 60Hz, msaa_2d=0
├── export_presets.cfg.example        ← credential-free ARM64 direct export preset
├── android\                          ← gitignored Gradle template (Route B blocked — open android\build when unblocked)
├── scenes\
│   └── planning.tscn                 ← MAIN SCENE: C4I planning terminal (boot.tscn retired S3)
├── scripts\
│   ├── autoload\
│   │   ├── event_bus.gd              ← typed signals only
│   │   └── sim_clock.gd              ← Phase machine, tick authority, FPS caps via SimConstants
│   ├── sim\                          ← PURE RefCounted layer, zero autoload refs (D-018)
│   │   ├── sim_constants.gd          ← single tuning surface (incl. ACTION_FUSE_TICKS, ACTION_COOLDOWN_TICKS, ACTION_MAX_RANGE_CELLS)
│   │   ├── agent_command.gd · command_queue.gd · sim_operative.gd
│   │   ├── greybox_map.gd · sim_world.gd · mission_snapshot.gd
│   │   ├── grid_pathfinder.gd        ← integer-grid A* on GreyboxMap (D-023; doors pass, walls/bounds enforced in movement)
│   │   └── ai\                       ← AAA tactical CPU (`CpuCommander`), GOAP planner (`GoapActions`/`GoapPlanner`), `InfluenceMap`, `SquadTactics`, `EnemyAi`, `AiCoordinator`
│   ├── view3d\                      ← HD-2D 3D view layer (WorldView3D, TacticalCamera3D, cutaway shader)
│   ├── tileset_theme.gd · tileset_theme_registry.gd ← TilesetTheme resource contract + 5-theme registry
│   └── planning\                     ← C4I terminal layer (S2b/S3)
│       ├── grid_util.gd              ← central px↔cell law
│       ├── route_sanitizer.gd        ← decimate 12px (tail kept) → Catmull-Rom Bezier bake 8px (CP-031)
│       ├── plan_board.gd             ← committed routes per operative
│       ├── mission_camera.gd · map_renderer.gd · operative_token.gd
│       ├── planning_controller.gd    ← gesture FSM: OBSERVATION↔ROUTING, per-op lines, focal pinch
│       └── planning_root.gd          ← `PlanningRoot` scene assembly + boot print + resize hook
├── tests\
│   ├── determinism_harness.gd        ← `-s` SceneTree harness: 14/14 PASS (CP-040 stances, CP-042 tactical actions, CP-043 FoF override added)
│   └── simclock_probe.tscn/.gd       ← CP-020 cap-flip evidence
├── builds\                           ← APK output (gitignored)
├── blueprints\                       ← governance + BP canon (gitignored by design)
└── docs\                             ← BUILD-IN-ANDROID-STUDIO.md (Route A guide + Route B blocker)
```

## External tooling

| Tool | Path | Status |
|------|------|--------|
| Godot engine | `C:\Godot\Godot_v4.0-stable_win64_console.exe` (+ non-console twin) — **4.0.stable.official.92bee43ad** | ✅ verified `--version`; headless smoke clean (`C:\Godot\4.7.2` also present, unused) |
| Android Studio | `C:\Program Files\Android\Android Studio\bin\studio64.exe` | ✅ installed (`...\jbr` missing `lib\jvm.cfg`; working JBR OpenJDK 25 at `C:\android\Android Studio\jbr`) |
| Android SDK | `C:\android\sdk` (platforms `24,31,33–37`, build-tools `34–37`, NDK `27–30`, `platform-tools`) | ✅ present (lacks API 32 / build-tools 32.0.0 / NDK 23.2.8568313 for Godot 4.0 Gradle) |
| Debug keystore | `C:\android\keystores\tacplan-debug.keystore` | ✅ outside repo |
| Flutter/Dart | `C:\src\flutter` | present — NOT used by this project |
| Python env | `C:\venv-hub` (Python 3.14.x) | use AS-IS; ask before installing into |

## Component health

| Component | Health | Next blocker |
|-----------|--------|--------------|
| Governance docs | 🟢 synced S3 | none |
| Godot project skeleton | 🟢 flat root clean; renderer/60Hz/MSAA=0 locked | none |
| **Deterministic sim core** | 🟢 43-case harness passes, including live replay state, pending commands, and reset isolation | Replay scrub UI |
| **Planning phase v1 (M3)** | 🟢 Catmull-Rom Bezier + wall-graze repair + `DRAW`/`TAP` mode + `0.28s` hold + compact above-map `NodeMenu` + `F1/N` switcher | CP-030 & CP-080 ✅ PASS on BLU B160V |
| **Execution sim v1 (M5/BP-02+BP-04)** | 🟢 `GridPathfinder` A* movement + `USE_STAIRS` multi-floor traversal + adherence + collision-halt + `TacticalVfx` tracers/flashes/rings | CP-050/051/052 & CP-073 ✅ PASS on BLU B160V |
| Visibility/fog (M6/BP-06) | 🟢 Cached, palette-aware per-floor GPU masks with live and last-seen map contacts | CP-061 ✅ PASS on BLU B160V (`PowerVR Rogue GE8300`, `median_ms=33.67`) |
| **5-ft 2.5D engine (M11/CP-103)** | 🟢 `op01` 32x24 compound, WO-subtle planning grid, 5-theme `TilesetTheme` registry, batched MultiMesh floors/walls + Sprite3D actors + waist/near-focus cutaway, 88/52/20 pitch + 90° yaw snap | Visual device pass (Android + desktop OpenGL) remains a USER gate |
| **Tests & harnesses** | 🟢 10 of 12 local headless gates green (`parse_all` 100 scripts / 15 scenes, `scene_smoke`, `determinism_harness`, `aaa_ai_harness`, `meta_progression_harness`, etc.) | CP-074 & CP-075 ✅ PASS headless |
| Enemy AI / mission loop (M7/BP-09) | 🟢 Phase L GOAP + CPU Commander across all floors, `OP-05..OP-10` stair links, `MissionPrepScreen` 2–4 op deployment, `ArmoryScreen` RP unlocks, `TwoPlayerScreen` Pass & Play + LAN UDP 7600, `TapInController` live `-1 CP` override | CP-074, CP-075 & CP-102 ✅ PASS (Moto G + BLU B160V) |
| Audio pass (M9/BP-08) | 🟢 `TacticalAudio` autoload (`Ambient` bus ducking, LP heartbeat on damage, seeded squelch/blips); 16-bit PCM WAVs (`0` import errors); `ui_audio_smoke` PASS | CP-090 ✅ PASS |
| **Android export track (M10/BP-10)** | 🟢 Route A APK (`builds\TacPlan-debug.apk`, `INTERNET` + `ACCESS_NETWORK_STATE`) verified clean (`CP-100`) & live-verified on Moto G (`ZT4222BMWN`) + BLU `B160V` (`CP-101`, `CP-102` ✅ PASS) | Store release signing & optional Route B JDK11/NDK23 |

## Known unknowns / open decisions

- Headless CI and the verified Route A setup use Godot 4.0.4 with matching templates.
- Package id: `com.tacplan.game` set in `export_presets.cfg` — DECISION D-010 formally open.
- Art style: blueprint-schematic aesthetic assumed; no assets yet.
- Facing is included in snapshot-based hashes. Cross-platform float behavior remains a verification concern.
