# SESSION_HANDOFF.md — Cold Start Entry Point
> **READ THIS FILE FIRST in every new session.** Then read **`RULES.md`** (mandatory law), then `CURRENT_STATE.md`, `CHECKLIST.md`, then the relevant BP section.

**⬅️ RULES FILE (MANDATORY READING, position 2):**
- Path: `C:\TacPlan Shooter\RULES.md`
- Contains: working-directory and signing rules, technical laws, and verification gates.
- **If any document contradicts RULES.md, RULES.md wins.**

**Last updated:** 2026-11-24 (Session 16 — Phase L AAA Tactical CPU & GOAP Squad AI)
**Repo:** [GhostMan612/TacPlanShooter](https://github.com/GhostMan612/TacPlanShooter) · `main`
**Source document:** `blueprints\Tactical Android Game Development.rtf` → canonical text at `blueprints\architecture-blueprint-source.txt`
**Godot:** 4.0.4.stable for CI and verified Route A export.

---

## Project in one paragraph

**TacPlan Shooter** — a pure top-down tactical planning game for Android in **Godot 4** (Compatibility/OpenGL ES renderer): the Rainbow Six (1998) pre-mission planning loop with NO first-person shooting. Players draw insertion routes, set stances/go-codes/tactical actions/fields of fire on a blueprint map, then commit and watch a deterministic simulation execute the plan frame-perfectly. Replay scrubbing via Command Pattern + fixed-tick reset-and-feed.

## Where we are (TL;DR)

**FULL ACCESS + FULL ALLOW granted (2026-11-24, user-directed):** RULES.md §1.1 (external dirs writable), AGENTS.md "Hard boundaries" flipped. All denies → FULL ALLOW.

- Phase L (`AAA-TACTICAL-AI-CPU-SPEC.md` + SceneTree `_init()` fix across all harnesses) is complete and verified: `InfluenceMap`, `GoapActions`, `GoapPlanner`, `SquadTactics`, and `CpuCommander` integrate cleanly into `EnemyAi`, `AiCoordinator`, `CombatSystem`, and `SimWorld` with full snapshot/hash determinism (`aaa_ai_harness` 6/6 PASS, `determinism_harness` PASS, `parse_all` 89 scripts / 13 scenes `failures=0`, all 12 headless gates green).
- `.github/workflows/headless-ci.yml` polls `.godot/global_script_class_cache.cfg` (`> 1000` bytes) during import passes and runs `aaa_ai_harness.gd` in CI.
- Upper-floor objectives, dedicated objective rules, timeline, and replay scrubbing remain open alongside handset verification of the Route A APK.

## Immediate next actions

1. Push `main` so GitHub Actions Headless CI confirms all 12 Linux Godot 4.0.4 gates (including `AAA AI harness`) green remotely.
2. Verify the Route A APK on an Android handset using the [build guide](../docs/BUILD-IN-ANDROID-STUDIO.md). Check boot, touch controls, fog appearance, and execution frame time.
3. Implement CP-071 timeline / replay scrubbing UI and multi-floor objectives (M7/M8).

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
