# SESSION_HANDOFF.md — Cold Start Entry Point
> **READ THIS FILE FIRST in every new session.** Then read **`RULES.md`** (mandatory law), then `CURRENT_STATE.md`, `CHECKLIST.md`, then the relevant BP section.

**⬅️ RULES FILE (MANDATORY READING, position 2):**
- Path: `C:\TacPlan Shooter\RULES.md`
- Contains: absolute rules (read-only external dirs, no-build law, secrets policy), conventions, all technical laws (G1–G16), workflow + verification law
- **If any document contradicts RULES.md, RULES.md wins.**

**Last updated:** 2026-11-23 (Session 5 — M4 stances CP-040)
**Repo:** `C:\TacPlan Shooter\` (branch `main`, `b0b45a8 → e93e535 → 706eecf → 1edbe2e → c474c0e → d631818 → 7a4f8ae → 9adcf79`)
**Source document:** `blueprints\Tactical Android Game Development.rtf` → canonical text at `blueprints\architecture-blueprint-source.txt`
**Godot:** `C:\Godot\Godot_v4.0-stable_win64_console.exe` (4.0.stable)

---

## Project in one paragraph

**TacPlan Shooter** — a pure top-down tactical planning game for Android in **Godot 4** (Compatibility/OpenGL ES renderer): the Rainbow Six (1998) pre-mission planning loop with NO first-person shooting. Players draw insertion routes, set stances/go-codes/tactical actions/fields of fire on a blueprint map, then commit and watch a deterministic simulation execute the plan frame-perfectly. Replay scrubbing via Command Pattern + fixed-tick reset-and-feed.

## Where we are (TL;DR)

**DIVISION OF LABOR (user-defined):** The agent CODES ONLY — GDScript source, scenes-as-code plans, parse gates. **The USER builds/exports and tests on device** using SDK `C:\android\sdk`. No agent ever emits an APK/AAB.

- 📜 Governance + repo clean (S3): duplicate `game/*` git entries purged, `game\` deleted, `boot.tscn`/`boot.gd` retired, `android\` ignored, `project.godot` locks `physics_ticks_per_second=60` and `msaa_2d=0`.
- 🧠 **M2 ✅ deterministic sim core (hardened S3)** — `SimWorld` clears operatives on `setup()`, fixed deterministic `ACTION_FUSE_TICKS=45`, zero-tick instant commands (CP-023), fractional `move_carry`, strengthened `state_hash()` (`rng.state`, sorted doors, `_canon()`), `CommandQueue.reset()` deep copy, `GreyboxMap.in_bounds()`; **harness 9/9 PASS**.
- 🗺️ **M3 🔄 planning phase v1 (remediated S3)** — real Catmull-Rom Bezier smoothing + tail preservation (CP-031 re-PASSED), persistent per-operative routes, clamped `MissionCamera` (no dead zone, CP-032) + focal pinch zoom + viewport resize, `OperativeToken` 6.5 px radius, screen-space selection (`72/zoom`), `_long_fired` release fix, `PlanningRoot` `class_name`.
- 📱 **ANDROID TRACK (S3):** **Route A (direct Godot export, `use_gradle_build=false`) is READY** in `docs\BUILD-IN-ANDROID-STUDIO.md` (`builds\TacPlan-debug.apk`). **Route B (Gradle / Android Studio) is BLOCKED** because Godot 4.0's template pins Gradle 7.4 / AGP 7.2.1 / Java 11 / SDK 32 / build-tools 32.0.0 / NDK 23.2.8568313, while local tooling has JDK 25 and SDK 24/31/33–37.
- 🏃 **M4 stances ✅ (90ef6cd) — CP-040 verified** — blitz 6.4 cells/s / acoustic 1.5, normal 4.0 / 1.0, cautious 2.0 / 0.35 per BP-03; harness **12/12 PASS**.
- 💣 **M4 tactical actions ✅ — CP-042** — new `SimEntity` (life 30 ticks; `entity_spawned`/`entity_effect` journals) for FRAG/FLASHBANG/TEAR_GAS + BREACH_CHARGE; FRAG damages operators within 2 cells (owner excluded); cooldown lock on spawn; entities in snapshot + state_hash; harness **13/13 PASS** (`tactical_actions PASS: spawned=3 effects=3 cooldown_seen=true hp_op0=100 hp_op1=75`).
- 🎯 **M4 FoF ✅ — CP-043** — `SET_FIELD_OF_FIRE` now sets `facing_deg = bearing`; `_step_move` leaves facing frozen while `field_of_fire_deg >= 0` (override); harness `fof_override PASS (done=true override_seen=true)`; harness **14/14 PASS**.
- 🚀 **M5 slice 1 ✅ (9adcf79) — execution core** — `GridPathfinder` (integer-grid A*; **D-023**), `SimWorld` rewrite: A* plan + per-tick adherence movement at stance speed (`move_blocked`/`move_unblocked`), `SimOperative.halted`, collision-halt (`collision_halt`), wall/door/bounds + action range checks, `state_hash` + halted/blocked. `PlanningRoot`: world stepping in `_physics_process` when EXECUTION (**CP-052**) + live token sync (CQS) + HUD (**Execute / Go-Code: Alpha / Reset**). Harness 12/12 (**CP-050**, **CP-051**); demo: op1 breaches (8,6), door opens via fuse, both ops complete deterministically.
- ✅ **M6: A–J complete (WO)** — CP-060 (segments=180, poly=720); CP-061 (FogLayer v2 SubViewport masks); Phase A (FogLayer v2, lockstep poll+delay, acoustic move, RULES §2 user-grant); Phase J (ThemeManager v2 real Theme, MapRenderer MGRS coords + zones, SquadHud screen Control, PlanBoard squad palette, OperativeToken symbology, ExecutionHud health dots, RosterRolesScreen + ArmoryScreen, ui_polish_audit PASS). Next: M7.
- 🗺️ **M7 in progress (user-granted, user device QA pending)** — M7.1 done: ScreenRouter + SplashScreen(1.8s auto-advance) + TitleScreen buttons, main_scene=splash.tscn; M7.2 done: PlanningRoot OP-01 map via MapLoader, theme_changed→apply_palette wiring, SquadHud mounted, _maybe_aar; M7.3 done: IconRegistry.icon(), OperativeToken sprite_texture, RosterRolesScreen.portraits; M7.4 done: headless-ci stdbuf/tee gates. M7.5: Route A APK export attempt (`builds\TacPlan-debug.apk`) — blocked by pre-existing env-level class registration errors (unchanged files too); user runs on-device tests.
- 🗺️ **Phase K — Touch-First In-Game CQB Map Editor (done)** — `MapEditorState` (paint wall/door/zones/ai_spawn/objective/jammer + undo/redo ≤50, `to_json`), `MapLoader.load_from_string()` + `GreyboxMap.to_dict()` extension, `MapEditorValidator` (out-of-bounds flagging), `MapEditorScreen` (tool palette WALL/DOOR/ZONES/UNITS/ERASE/UNDO/REDO + Validate red-dot highlight), `scenes/map_editor.tscn`, `TitleScreen` MAP EDITOR button, `tests/map_editor_harness.gd` (state undo, to_json→load roundtrip, validator PASS).

## Immediate next actions

1. **USER**: Follow `docs\BUILD-IN-ANDROID-STUDIO.md` (§1–§4) to run a **Route A** direct export (`builds\TacPlan-debug.apk`), `adb.exe install -r`, verify boot on phone (`CP-101`), and report the 7-point **CP-030** feel verdict + `adb.exe logcat -s godot`. (Decide later whether to upgrade Godot 4.0 → 4.x or install JDK 11/17 + SDK 32 + NDK 23 to unblock Route B.)
2. **AGENT**: M7 integration (P2) — Screen flow + theme/squad bindings + asset wiring done (M7.1–M7.3); CI gates updated (M7.4). User QA on device next; M5 remainder, M8+ follow.

### Build hand-off rule
After any change meant for the phone, the AGENT updates source + states expected behavior; the USER runs exports/builds. Never hand-build APKs as deliverables. Commit messages cite parse/test status only.

## Gotchas / constraints (DO NOT FORGET)

| # | Gotcha |
|---|--------|
| G1 | Renderer LOCKED to `gl_compatibility` desktop+mobile. Forward+ crashes old chipsets; Mobile-Vulkan taxes them. Set once in `project.godot`, never drift. |
| G2 | ALL sim logic in `_physics_process()` @60 Hz. Anything mutating game state inside `_process()` breaks determinism/replay. |
| G3 | Seeded `RandomNumberGenerator` only; seed persisted in snapshot. Global `randi()/randf()/randomize()` FORBIDDEN in sim code. |
| G4 | AStarGrid2D ONLY. NavigationAgent2D/NavPoly banned (float nondeterminism + mobile perf). |
| G5 | NO RVO/local avoidance. Intersecting operative paths collide and halt — that's the design punishing bad timing. |
| G6 | MSAA off EVERYWHERE incl. every SubViewport (`msaa_2d=0` in `project.godot`); Line2D `antialiased=false`; smooth lines via alpha-gradient UV textures. |
| G7 | LOS = rotational sweep-line polygons: 3 rays/vertex (±0.00001 rad), intersection valid iff T1>0 and 0<T2<1, angular sort. Naive 360-ray casting is banned (perf + jagged edges). |
| G8 | Fog via GPU mask (SubViewport high-contrast render + Light2D/shader). Per-tile CPU fog arrays banned. Memory buffer = additive texture @50% opacity. |
| G9 | FPS caps: `Engine.max_fps=30` planning, 60 execution, restore on exit. Battery/thermal law. |
| G10 | Touch pipeline: decimation threshold (tail preserved) → Catmull-Rom Curve2D Bezier → `get_baked_points()` → Line2D. Raw touch coords never hit pathfinding or rendering directly. |
| G11 | External dirs READ-ONLY: `pathfinder_god`, `Recovery for All`, `Sovereign Nodes`, `sovereign_mantle`, `sovereign_tagger*`. venv-hub ask-first. C:\android & C:\src are tool homes — never restructure. |
| G12 | NEVER build/export binaries. USER builds/exports locally (`C:\android\sdk`). Agent lane ends at parse-clean source. |
| G13 | `blueprints\` gitignored by design — no history protection there. Stage by explicit path only. |
| G14 | PowerShell 5.1 corrupts UTF-8 round-trips (`Get-Content \| Set-Content`) AND `Set-Content -Encoding utf8` writes BOMs that break `.tscn` headers ("Expected '['" at char 1) — use file tools or BOM-free writes; verify first bytes when parse errors point at char 1. |
| G15 | Godot 4.0 `--quit` ALWAYS exits code 1 even on clean runs (empty-project control proven). NEVER use exit codes as pass/fail — filter logs for `ERROR\|SCRIPT ERROR\|Parse`. Also: `--check-only --script` compiles standalone WITHOUT autoload globals → scripts referencing autoloads fail there by design; the project-level headless boot is the authoritative gate. |
| G16 | First-import class-cache quirk: a brand-new `class_name` referenced by existing scripts fails ONE editor import ("Identifier not declared") — run the import twice before judging. |

## Session-end protocol

1. Update `CHANGELOG.md`; tick `CHECKLIST.md`; flip `CHECKPOINTS.md`; refresh `CURRENT_STATE.md`
2. Rewrite "Where we are" + "Immediate next actions" HERE
3. Commit code by explicit path (never commit `blueprints\`)
