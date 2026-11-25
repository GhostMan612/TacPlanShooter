# SESSION_HANDOFF.md — Cold Start Entry Point
> **READ THIS FILE FIRST in every new session.** Then read **`RULES.md`** (mandatory law), then `CURRENT_STATE.md`, `CHECKLIST.md`, then the relevant BP section.

**⬅️ RULES FILE (MANDATORY READING, position 2):**
- Path: `C:\TacPlan Shooter\RULES.md`
- Contains: working-directory and signing rules, technical laws, and verification gates.
- **If any document contradicts RULES.md, RULES.md wins.**

**Last updated:** 2026-11-24 (Session 18 — BLU B160V Android 14 hardware QA, 720x1612 HUD layout fix & WAV header fix)
**Repo:** [GhostMan612/TacPlanShooter](https://github.com/GhostMan612/TacPlanShooter) · `main`
**Source document:** `blueprints\Tactical Android Game Development.rtf` → canonical text at `blueprints\architecture-blueprint-source.txt`
**Godot:** 4.0.4.stable / 4.0.stable (`C:\Godot\Godot_v4.0-stable_win64_console.exe`) for headless gates & Route A export.

---

## Project in one paragraph

**TacPlan Shooter** — a pure top-down tactical planning game for Android in **Godot 4** (Compatibility/OpenGL ES renderer): the Rainbow Six (1998) pre-mission planning loop with NO first-person shooting. Players draw insertion routes, set stances/go-codes/tactical actions/fields of fire on a blueprint map, then commit and watch a deterministic simulation execute the plan frame-perfectly. Replay scrubbing via Command Pattern + fixed-tick reset-and-feed.

## Where we are (TL;DR)

BP-08 (M9 Audio) — done: `TacticalAudio` (buses, duck, squelch on go-code/breach, heartbeat on op_damaged), placeholders in `assets/audio`, autoload registered. Next: M5 remainder.

**FULL ACCESS + FULL ALLOW granted (2026-11-24, user-directed):** RULES.md §1.1 (external dirs writable), AGENTS.md "Hard boundaries" flipped. All denies → FULL ALLOW.

- BLU `B160V` Hardware QA & Fixes (Session 18): verified Route A ARM64 debug APK (`builds\TacPlan-debug.apk`, `apksigner` v1/v2/v3 PASS) live on physical Android 14 device `7040016025040287` (`PowerVR Rogue GE8300`, `720x1612` portrait): Title, Settings (`Night-Ops NVG` / `Dark Tactical`), `OP-01` Planning (`_center_camera_if_short()` + compact `ActionBar` fix in `planning_root.gd`), long-press routing + `PipLoupe`, 60 Hz Execution + `FogLayer` GPU shader (`SurfaceFlinger` `BLAST` `median_ms=33.67`, `p95_ms=50.52`), `AarScreen` + `ReplayScrubber` (`SCRUB TICK 98 / 197`), `MapEditorScreen`, and `0` logcat errors; also fixed `tools/gen_placeholder_audio.ps1` + 14 `assets/audio/sfx_ui_*.wav` (`blockAlign=2`, `bitsPerSample=16`, `0` WAV import errors).
- Headless verification (`parse_all.tscn`, `scene_smoke.tscn`, `determinism_harness.gd`, etc.) passes cleanly with zero errors.
- Remaining items are subjective feel/listen confirmations (`CP-080` / `CP-090` USER), multi-floor stair links, 2-Player LAN lockstep transport, and store release signing.

## Immediate next actions

1. Extend maps with multi-floor stair links and objective variants beyond ground floor.
2. Implement 2-Player LAN lockstep transport and complete subjective UX/audio checks (`CP-080`, `CP-090`).
3. Configure release keystore signing outside the repo (and optionally JDK 11 / NDK 23 if Route B Gradle assembly is ever needed).

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
