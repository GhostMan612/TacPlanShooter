# SESSION_HANDOFF.md — Cold Start Entry Point
> **READ THIS FILE FIRST in every new session.** Then read **`RULES.md`** (mandatory law), then `CURRENT_STATE.md`, `CHECKLIST.md`, then the relevant BP section.

**⬅️ RULES FILE (MANDATORY READING, position 2):**
- Path: `C:\TacPlan Shooter\RULES.md`
- Contains: working-directory and signing rules, technical laws, and verification gates.
- **If any document contradicts RULES.md, RULES.md wins.**

**Last updated:** 2026-11-25 (Session 21 — Mission Prep, Armory RP Unlocks, Live Tap-In Control & 2-Player Co-Op/PvP Lobby)
**Repo:** [GhostMan612/TacPlanShooter](https://github.com/GhostMan612/TacPlanShooter) · `main`
**Source document:** `blueprints\Tactical Android Game Development.rtf` → canonical text at `blueprints\architecture-blueprint-source.txt`
**Godot:** 4.0.4.stable / 4.0.stable (`C:\Godot\Godot_v4.0-stable_win64_console.exe`) for headless gates & Route A export.

---

## Project in one paragraph

**TacPlan Shooter** — a pure top-down tactical planning game for Android in **Godot 4** (Compatibility/OpenGL ES renderer): the Rainbow Six (1998) pre-mission planning loop with NO first-person shooting. Players draw insertion routes, set stances/go-codes/tactical actions/fields of fire on a blueprint map, then commit and watch a deterministic simulation execute the plan frame-perfectly. Replay scrubbing via Command Pattern + fixed-tick reset-and-feed.

## Where we are (TL;DR)

WO-SPACE-GRUNTS-25D-VISUAL-UPGRADE (2026-11-25) — in progress: beveled floor plates, 2.5D extruded walls + doors + shadows, translucent zone decals, `PropLayer` y-sorted props, chunky 3/4 pixel operatives, full-screen edge-to-edge camera + follow-cam, ALPHA/BRAVO/CHARLIE/DELTA HUD. HYGIENE_COMMENTS=0.

BP-08 (M9 Audio) — done: `TacticalAudio` (buses, duck, squelch on go-code/breach, heartbeat on op_damaged), placeholders in `assets/audio`, autoload registered. Next: M5 remainder.

**FULL ACCESS + FULL ALLOW granted (2026-11-24, user-directed):** RULES.md §1.1 (external dirs writable), AGENTS.md "Hard boundaries" flipped. All denies → FULL ALLOW.

- **Session 21 (`CP-074`, `CP-075`, `CP-102` ✅ PASSED):** Shipped interactive `ArmoryScreen` RP unlocks + `ProgressionSave`, 5-tab `MissionPrepScreen` (`scenes/prep.tscn` — `BRIEF`/`INTEL`/`ROSTER`/`KIT`/`SQUAD` deploying 2–4 operatives with weapon caliber, armor class, heartbeat sensor, and squad colors), live `TapInController` cell-redirect during Execution (`-1 CP`, `REL AI`, deterministic `override_stream` replay), and 2-Player Co-Op/PvP (`TitleScreen` 7/7 enabled -> `scenes/two_player.tscn` / `TwoPlayerScreen` Pass-and-Play blind SHA-256 `CommitReveal` + `LockstepSession` UDP 7600 `create_server`/`connect_on_port`).
- Exported & `apksigner`-verified `builds\TacPlan-debug.apk` (`28,399,175` bytes, `v1`/`v2`/`v3`, `INTERNET` + `ACCESS_NETWORK_STATE`) and verified end-to-end on BOTH **Moto G (2025)** (`ZT4222BMWN`, Android 16, `720x1604`) and **BLU `B160V`** (`7040016025040287`, Android 14, `720x1612`) with `0` `godot:E`/`AndroidRuntime:E` logcat errors, plus all 12 headless CI gates green (`HYGIENE_COMMENTS=0`).

## Immediate next actions

1. Optional 2-device live Wi-Fi match playthrough (`Moto G` `10.1.10.240` <-> `BLU B160V` `10.1.10.15` over UDP `7600`).
2. Add custom portraits/icons (`assets/portraits/`) or `MissionPrepPanels` unit trait/skill radar charts if desired for visual polish.
3. Configure release keystore signing outside the repo when ready for distribution.

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
