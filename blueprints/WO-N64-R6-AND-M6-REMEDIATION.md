# WORK ORDER: WO-N64-R6-AND-M6-REMEDIATION
Repo: C:\TacPlan Shooter (GhostMan612/TacPlanShooter, branch: main)
Governing Law: Read RULES.md first. Full files only. Zero comments except the 4-line Genesis header. Typed GDScript everywhere. Pure autoload-free code under scripts/sim/.

## PHASE A — M6 Remediation & Zero-Artifact CI (Do First)
Target files:
- MODIFY: `scripts/sim/visibility.gd`
- CREATE: `scripts/planning/fog_mask.gdshader`
- MODIFY: `scripts/planning/fog_layer.gd`
- MODIFY: `scripts/planning/planning_root.gd`
- MODIFY: `tests/determinism_harness.gd`
- CREATE: `.github/workflows/headless-ci.yml`

Requirements:
1. `scripts/sim/visibility.gd`: Wrap `a + eps` and `a - eps` via `wrapf(..., -PI, PI)` before `rays.sort()`. In `_ray_hit_t()`, allow endpoint hits (`t > 0.0 and u >= -0.000001 and u <= 1.000001`) to stop corner-piercing leaks. Add `_test_visibility_west_corner_wrap()` to `tests/determinism_harness.gd`.
2. `scripts/planning/fog_layer.gd` + `fog_mask.gdshader`: Replace per-cell `Polygon2D` node churn and `_map_cells()` CPU loops with two offscreen `SubViewport` masks (`msaa_2d = Viewport.MSAA_DISABLED` on both): `live_vp` (`CLEAR_MODE_ALWAYS`) and `memory_vp` (`CLEAR_MODE_NEVER`, reset via `reset_fog()`), composited by one full-map `ColorRect` shader (`live > 0.5` -> alpha `0.0`, `memory > 0.5` -> `0.50` opacity fog, unseen -> `0.85` opacity fog).
3. `scripts/planning/planning_root.gd`: Mount `_hud` inside a `CanvasLayer`; wire `Execute`, `Alpha`, `Bravo`, `Charlie`, `Delta`, and `Reset` buttons to fit portrait `1080px` width; cache `map.get_wall_segments()` (invalidate on breach/reset); pass `SimConstants.LOS_VERTEX_EPSILON_RAD`; call `fog.reset_fog()` on setup and reset.
4. `.github/workflows/headless-ci.yml`: Zero-artifact workflow on `push`/`pull_request` to `main` using cached Godot 4.0.4-stable Linux headless binary; run two-pass `--import`, boot smoke filtered for `ERROR|SCRIPT ERROR|Parse` (ignoring Godot 4.0 `--quit` exit code 1), `determinism_harness.gd`, and `simclock_probe.tscn`.

## PHASE B — N64 R6 Data & Squad Architecture
Target files:
- CREATE: `scripts/sim/operative_profile.gd` (5 traits, 5 skills, KIA/wounded status, synthetic codenames only)
- CREATE: `scripts/sim/kit_catalog.gd` (weapons, suppressed variants, 2 equipment slots, Light/Medium/Heavy armor stats)
- CREATE: `scripts/sim/squad_config.gd` (`Red`, `Blue`, `Green`, `Gold` squads, leader promotion, leadership modifier)
- MODIFY: `scripts/sim/sim_constants.gd` (add `&"delta"` to `GO_CODES`, add `Mode { ENGAGE, ADVANCE, ESCORT }`)
- MODIFY: `scripts/sim/agent_command.gd`, `scripts/sim/sim_operative.gd`, `scripts/sim/sim_world.gd` (support `SET_MODE`, `DELTA` go-code, operative skills/armor modifiers, Heartbeat Sensor detection radius)

## PHASE C — Bird's-Eye Tap-In Direct Control & Pre-Mission Flow
Target files:
- CREATE: `scripts/sim/override_command.gd` (deterministic tick-indexed `OverrideCommand` for Tap-In move/aim/fire/slot)
- MODIFY: `scripts/sim/sim_world.gd` (ingest `OverrideCommand` inside `step()`, record in journal, support deterministic replay)
- CREATE: `scripts/planning/squad_hud.gd` (color-coded team boxes, active Mode, green/yellow/red health dots, tap-to-select operative)
- CREATE: `scripts/planning/tap_in_controller.gd` (top-down touch pad + release-to-AI toggle feeding `OverrideCommand` to `SimWorld`)
- CREATE: `scripts/ui/mission_prep_flow.gd` (`Briefing` -> `Intel` -> `Roster` -> `Kit` -> `Team` -> `Planning` state machine)
- MODIFY: `tests/determinism_harness.gd` (add tests for `DELTA` go-code, `Engage`/`Advance`/`Escort` modes, and `OverrideCommand` replay determinism)

## PHASE D — Simultaneous 2-Player Co-op & PvP Lockstep
Spec: `blueprints/TWO-PLAYER-COOP-PVP-SPEC.md`
Target files:
- MODIFY: `scripts/sim/sim_constants.gd` (add `TAPIN_HANDOFF_TICKS`, `TAPIN_MAX_BURST_TICKS`, `TAPIN_COOLDOWN_TICKS`, `TAPIN_UNIT_COOLDOWN_TICKS`, `TAPIN_COMMAND_POINTS_MAX`, `LOCKSTEP_INPUT_DELAY_TICKS`)
- MODIFY: `scripts/sim/sim_operative.gd` (add `faction_id` and `owner_peer_id` for per-faction isolation)
- MODIFY: `scripts/sim/sim_world.gd` (enforce deterministic tap-in cooldowns, CP budget, leadership scaling, and `state_hash()` checksums inside `step()`)
- CREATE: `scripts/net/commit_reveal.gd` (`SHA-256(plan_json + salt)` commitment, reveal exchange, and hash verification for blind PvP planning)
- CREATE: `scripts/net/lockstep_session.gd` (`ENetMultiplayerPeer` 60 Hz deterministic lockstep transport, input delay buffer, and periodic state-hash sync)
- MODIFY: `scripts/planning/planning_root.gd` (filter `_update_fog()` by `o.faction_id == local_faction_id` for per-faction Fog of War and acoustic/sensor blips)
- MODIFY: `tests/determinism_harness.gd` (add headless 2-faction determinism, tap-in cooldown, and CP budget harness tests)
  
## PHASE E — Playable Drones, Vehicles & Real CQB Depth
Spec: `blueprints/META-PROGRESSION-AND-CQB-SPEC.md`
Target files:
- CREATE: `scripts/sim/door_system.gd` (door states `OPEN`/`CLOSED_UNLOCKED`/`LOCKED`/`BARRICADED`/`BREACHED_DESTROYED`, fatal funnel penalties, silent lockpick/ram/shotgun/C4 breach methods)
- CREATE: `scripts/sim/ballistics_suppression.gd` (caliber vs. Light/Medium/Heavy armor & directional shield cone, suppression meter pressuring `self_control`, medical states `HEALTHY`/`WOUNDED`/`INCAPACITATED`/`KIA`)
- CREATE: `scripts/sim/sim_drone.gd` (playable ground recon bot, indoor micro-UAV, utility drone via tick-indexed `OverrideCommand`, battery/signal limits, RF jammer interference)
- CREATE: `scripts/sim/sim_vehicle.gd` (insertion/breach/mobile cover/extraction vehicles registering dynamic solid wall segments and scripted Go-Code arrival/ram paths)
- MODIFY: `scripts/sim/sim_world.gd` (integrate door, ballistics/suppression, drone, and vehicle simulation inside 60 Hz deterministic `step()`)
- MODIFY: `scripts/planning/fog_layer.gd` (feed drone live vision polygons into faction `SubViewport` `live_vp` + `memory_vp`, remove live sightline on drone loss)
- MODIFY: `tests/determinism_harness.gd` (add determinism tests for door breach, ballistics/suppression, playable drones via `OverrideCommand`, and vehicle dynamic wall segments)

## PHASE F — Meta-Progression, Roster Positions & Armory Economy
Spec: `blueprints/META-PROGRESSION-AND-CQB-SPEC.md`
Target files:
- CREATE: `scripts/meta/unit_profile.gd` (persistent `UnitProfile`/`CampaignState` operative pool, XP, mission ribbons, and CQB roles: Squad Leader, Pointman, Breacher, Shield/Heavy, Tech/Drone Operator, Marksman/Overwatch, Medic/Rescue)
- CREATE: `scripts/meta/armory_catalog.gd` (unlockable primary/secondary weapons, attachments, armor tiers, tactical tools, drones, vehicles, and PvP Standardized Loadout Points vs. Open Unit Roster rules)
- CREATE: `scripts/meta/progression_save.gd` (versioned local JSON persistence separate from deterministic `MissionSnapshot`, mission grading for Requisition Points and Unit XP)
- CREATE: `scripts/ui/hq_armory_screen.gd` (armory unlock tree, gear equipping, and PvP equal-budget loadout validation UI)
- CREATE: `scripts/ui/roster_roles_screen.gd` (operative roster management, CQB billet assignment, and XP/trait progression UI)
- CREATE: `tests/meta_progression_harness.gd` (verify persistent HQ save/load, operative XP/roles, armory unlock tree, mission RP grading, and PvP equal-budget loadout validation)

## PHASE G — Advanced Deterministic CQB AI
Spec: `blueprints/AI-BEHAVIOR-SPEC.md`
Target files:
- CREATE: `scripts/sim/ai/threat_blackboard.gd` (dual-cone vision, wall-attenuated acoustic perception, LKP memory & discovery escalation)
- CREATE: `scripts/sim/ai/ai_archetypes.gd` (data-driven enemy archetypes: `PATROL_SENTRY`, `ROOM_ANCHOR`, `TACTICAL_FLANKER`, `HEAVY_GUNNER`, `TECH_JAMMER`, `HOSTAGE_GUARD`)
- CREATE: `scripts/sim/ai/squad_coordinator.gd` (`SquadBlackboard`, `ANCHOR`/`SUPPRESSOR`/`FLANKER`/`RUNNER` role assignment, threat-weighted `AStarGrid2D` overlay, friendly squad micro-cohesion)
- CREATE: `scripts/sim/ai/enemy_ai.gd` (11-state tactical FSM, target utility scoring, suppression/morale & surrender, PvP Defender reflex integration)
- CREATE: `scripts/sim/ai/friendly_reflex_ai.gd` (`Engage`/`Advance`/`Escort` ROE modes alongside `CommandQueue`, hostage line-of-fire safety gate)
- CREATE: `scripts/sim/ai/hostage_ai.gd` (`CAPTIVE` -> `FOLLOW_ESCORT` -> `EXTRACTED` state machine)
- MODIFY: `scripts/sim/sim_world.gd` (integrate 3-layer deterministic AI coordinator, sensory blackboard, and FSM updates inside 60 Hz fixed tick)
- MODIFY: `tests/determinism_harness.gd` (require all 6 headless AI verification gates: `_test_ai_no_wallhack_lkp`, `_test_ai_acoustic_wall_attenuation`, `_test_ai_threat_weighted_flank`, `_test_ai_flashbang_morale_stun`, `_test_ai_hostage_lof_safety`, `_test_ai_determinism_replay`)

## PHASE H — Data-Driven Map Loader & 10-Mission Campaign Pack
Spec: `blueprints/CAMPAIGN-MISSIONS-AND-MAPS-SPEC.md`
Target files:
- CREATE: `scripts/sim/map_loader.gd` (deterministic JSON map parser for 1–3 floor geometry, walls, doors, stair links, insertion/extraction/defender zones, objectives, AI/hostage spawns, and jammer nodes)
- MODIFY: `scripts/sim/greybox_map.gd` (implement `GreyboxMap.load_from_json(path)` snapping to `SimConstants.GRID_CELL_SIZE_PX` with zero autoload dependencies)
- CREATE: `scripts/sim/mission_grader.gd` (deterministic end-of-mission RP grading: objective completion, zero casualties, clean ROE/collateral penalty, and speed/stealth bonus)
- CREATE: `data/maps/op01_glass_house.json` through `data/maps/op10_sovereign_citadel.json` (10-operation campaign pack supporting Solo, 2-Player Co-op, and 2-Player PvP)
- CREATE: `tests/map_validation_harness.gd` (enforce all 4 headless map validation checks: schema/bounds parsing, walkable spawn/zone placement, `GridPathfinder` reachability, and `Visibility.compute_polygon()` safety)

## VERIFICATION COMMANDS (local before commit)
- `godot --headless --path . --quit 2>&1 | Select-String "ERROR|SCRIPT ERROR|Parse"` -> empty
- `godot --headless --path . -s res://tests/determinism_harness.gd 2>&1 | Select-String "FAIL|ERROR|SCRIPT ERROR|PASS"` -> all PASS, zero FAIL/ERROR
- `godot --headless --path . res://tests/simclock_probe.tscn --quit 2>&1 | Select-String "ERROR|SCRIPT ERROR|Parse"` -> empty

## DO-NOT BOUNDARIES
- DO NOT touch directories outside `C:\TacPlan Shooter`.
- DO NOT build APKs/AABs or run Gradle (`RULES.md` §2).
- DO NOT add code comments outside the 4-line Genesis header (`RULES.md` §3.2).
- DO NOT enable MSAA on any SubViewport or Line2D (`RULES.md` §4).
- DO NOT reference autoloads inside `scripts/sim/` (`RULES.md` §3.4).
- DO NOT use `git add -A` or `git add .` — stage by explicit path only.
- DO NOT put networking/ENet calls inside scripts/sim/ — keep scripts/net/ strictly decoupled from pure simulation.
