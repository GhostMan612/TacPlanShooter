# CURRENT_STATE.md — Component Inventory Snapshot
**Snapshot date:** 2026-11-23 (end of Session 3 — audit remediation) · **Commits:** `b0b45a8` (S0+S1), `e93e535` (M2), `706eecf` (M3), `1edbe2e` (S2c), `c474c0e` (S2d), `d631818` (S2f), `7a4f8ae` (S3)

## Repo layout (`C:\TacPlan Shooter\`)

```
├── .gitignore                        ← Godot+Android aware (android/, builds/, blueprints/, export_presets.cfg ignored)
├── RULES.md                          ← canonical operating law
├── CLAUDE.md / AGENTS.md / README.md ← agent & repo guidance
├── project.godot                     ← GODOT 4 PROJECT ROOT — portrait primary (D-009), gl_compatibility, 60Hz, msaa_2d=0
├── export_presets.cfg                ← gitignored local Android preset: ARM64, portrait, com.tacplan.game, Route A (gradle=false)
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
│   │   └── grid_pathfinder.gd        ← integer-grid A* on GreyboxMap (D-023; doors pass, walls/bounds enforced in movement)
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
| **Deterministic sim core** | 🟢 14/14 harness PASS; zero-tick instants, move carry, strengthened hash, CP-050/051 execution adherence, CP-040 stances, CP-042 tactical actions, CP-043 FoF override | CP-044 (radial menu); M6 fog (CP-060/061) |
| **Planning phase v1 (M3)** | 🟢 Catmull-Rom Bezier + per-op lines + clamped camera + resize wired | CP-030 feel verdict = USER device test |
| **Execution sim v1 (M5/BP-02+BP-04)** | 🟢 slice 1: `GridPathfinder` A* movement + adherence + collision-halt + wall/door/bounds + action range; `PlanningRoot` Execute/Go-Code Alpha/Reset HUD + live token sync | CP-050/051/052 ✅ PASS; next: M5 remainder, then M4 stances/actions/FoF |
| Visibility/fog (M6/BP-06) | 🟢 CP-060 ✅ + CP-061 ✅ (FogLayer v2: SubViewport live/memory masks; Phase A2: UPDATE_ONCE + fog_mask.gdshader; WCW PASS) + Phase J (ThemeManager v2, MapRenderer coords+zones, SquadHud Control, PlanBoard palette) | Phase A–J complete — M7 mission loop (CP-070/071) |
| Enemy AI / mission loop (M7/BP-09) | ⬜ not started | execution sim wiring |
| Audio pass (M9/BP-08) | ⬜ not started | content |
| **Android export track (M10/BP-10)** | 🟡 Route A READY · Route B BLOCKED | USER Route A APK export + CP-101 boot; Route B blocked by Godot 4.0 template (Gradle 7.4/AGP 7.2.1/API 32/Java 11) vs local JDK 25 & SDK 24/31/33–37 |

## Known unknowns / open decisions

- Godot version pin = 4.0-stable (upgrade decision to 4.x pending; unblocks Route B Android Studio Gradle builds).
- Package id: `com.tacplan.game` set in `export_presets.cfg` — DECISION D-010 formally open.
- Art style: blueprint-schematic aesthetic assumed; no assets yet.
- Facing uses `atan2` (libm variance risk) — mitigated: quantized to int degrees for hashing (D-017).
