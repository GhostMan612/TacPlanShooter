# WORK ORDER: M7 — End-to-End Integration, Asset Wiring & Android Device QA
Repo: C:\TacPlan Shooter (GhostMan612/TacPlanShooter, branch: main)
Governing Law: Read RULES.md first. Full files only. Zero comments except the 4-line Genesis header. Typed GDScript everywhere. Keep `builds/` and signing keystores untracked.

## OBJECTIVE
Wire all Phase A–K systems into one cohesive playable Android vertical slice (Splash -> Title -> Campaign/Map Editor -> 7-Stage N64 Mission Prep -> OP-01 Planning & Execution -> AAR), bind the new SVG/PNG art assets, and turn all 6 Headless CI harnesses green.

## TASKS

### M7.1 — Full Screen-Flow & Scene Entrypoint Wiring
- Wire `scripts/ui/screen_router.gd` so real Godot scene transitions run cleanly end-to-end:
  `scenes/splash.tscn` (1.8s tap-to-skip) -> `scenes/title.tscn` (`Campaign`, `Quick Operation`, `2-Player`, `Map Editor`, `HQ & Armory`, `Settings`, `Credits`) -> `scenes/loading.tscn` -> `scenes/planning.tscn` (with `MissionPrepPanels` overlay for Briefing/Intel/Roster/Kit/Team before Planning) -> `scenes/aar.tscn` (with `Replay`, `Retry`, `Next Operation`, `Title`).
- Update `project.godot` `run/main_scene` to `res://scenes/splash.tscn` once all transitions pass boot smoke with zero errors.

### M7.2 — Live PlanningRoot, ThemeManager & SquadHud Bindings
- In `scripts/planning/planning_root.gd`:
  - Connect `ThemeManager.theme_changed` -> `renderer.apply_palette(pal)` and initialize with the active saved theme from `user://settings.json`.
  - Mount `SquadHud` inside `_hud_layer` (`CanvasLayer`) and call `squad_hud.refresh(world)` on setup, `_physics_process()` (during `EXECUTION`), and `_on_reset_pressed()`.
  - Load `data/maps/op01_glass_house.json` via `MapLoader` as the default vertical-slice mission (falling back cleanly to `GreyboxMap.build_default()` if missing).
  - Trigger `AarScreen` when all mission objectives complete or all operatives are incapacitated/KIA.

### M7.3 — Asset Pack Binding (SVG Icons + PNG Portraits/Sprites)
- `scripts/ui/icon_registry.gd`: Load the `.svg` icons in `assets/icons/` (and `assets/icons/svg/` if present) via `ResourceLoader.exists()` with safe fallback to procedural draws.
- `scripts/ui/roster_roles_screen.gd`: Bind `assets/portraits/opr_01_vanguard.png` through `opr_06_lifeline.png` when present on disk (graceful fallback if unzipped later).
- `scripts/planning/operative_token.gd`: Support optional top-down sprite textures from `assets/sprites/` (`op_pointman.png`, `op_breacher.png`, `op_heavy.png`, `op_tech.png`, `op_hostile_sentry.png`, `drone_micro_uav.png`, `drone_ground_bot.png`, `vehicle_bearcat_apc.png`, `vehicle_raid_van.png`) layered with MIL-STD directional cone and squad color ring.

### M7.4 — Green Headless CI (All Harnesses)
- Update `.github/workflows/headless-ci.yml`:
  - Run all harnesses with `stdbuf -oL -eL ./bin/godot --headless --path . --script tests/<name>.gd 2>&1 | tee <name>.log || true` so Linux stdout flushes before `SceneTree.quit()`.
  - Gate all 6 harnesses (`determinism_harness.gd`, `meta_progression_harness.gd`, `ui_polish_audit.gd`, `map_validation_harness.gd`, `ui_audio_smoke.gd`, `map_editor_harness.gd`) + `Boot smoke` + `SimClock probe` on zero `FAIL|ERROR|SCRIPT ERROR|Parse` and presence of `PASS`.

### M7.5 — Android Debug APK Verification Checklist (Device QA)
1. Confirm `builds\TacPlan-debug.apk` builds cleanly (`arm64-v8a`, `gl_compatibility`, `msaa_2d=0`, Portrait `1080×1920`, `com.tacplan.game`) and stays untracked in git.
2. On-device smoke test:
   - Splash -> Title -> Settings theme toggle (`Dark Tactical`, `Light Blueprint`, `Night-Ops NVG`) updates colors immediately.
   - Launch `OP-01: Glass House`: pan/pinch works smoothly; long-press operative draws route; tap waypoint sets Go-Code/Stance/Action.
   - Tap `Execute`: GPU `FogLayer` reveals live sightlines and retains 50% visited memory; Go-Codes `Alpha`–`Delta` trigger synchronized movement; Tap-In direct control respects cooldown/CP limits; `Reset` restores clean state.
   - Complete or abort mission -> `AAR` displays grade + RP/XP breakdown.
   - Open `Map Editor`: paint walls/doors/zones, click `Validate`, click `Playtest`, return cleanly.

## DO-NOT BOUNDARIES
- DO NOT commit `builds/`, `*.apk`, `*.aab`, or `*.keystore` files (`RULES.md` §1.2).
- DO NOT add code comments outside the 4-line Genesis header (`RULES.md` §3.2).
- DO NOT enable MSAA on any `SubViewport` or `Line2D` (`RULES.md` §4).
- DO NOT reference autoloads or networking inside `scripts/sim/` (`RULES.md` §3.4).
- DO NOT use `git add -A` or `git add .` — stage by explicit path only.
