# Blueprint: Phase L — AAA-Grade Tactical CPU & GOAP Squad AI

> **Status:** Active Phase L AI Upgrade Blueprint (extends `AI-BEHAVIOR-SPEC.md`; 100% deterministic 60 Hz pure autoload-free GDScript under `scripts/sim/ai/`, seeded RNG only, zero wallhacking, lockstep-safe for Solo, Co-op, and Skirmish vs. CPU).
> **Inspiration:** *F.E.A.R.* (GOAP + telegraphed squad callouts), *Door Kickers 2* / *Ready or Not* (CQB room clearing & crossfire), and *Rainbow Six* (autonomous CPU Commander pre-mission planning).

## 1. Autonomous CPU Commander (`scripts/sim/ai/cpu_commander.gd`)
Enables full Skirmish/PvP-style matches against a smart CPU Commander (both Attacking and Defending):
- **Topology Analysis (Pre-Mission Tick 0):** Scans `GreyboxMap` to identify fatal funnels (doorways/choke cells), room partitions, exterior breach points, cover corners, and objective sightlines.
- **Automated Pre-Mission Blueprint Generation:** Outputs valid `CommandQueue` plans for CPU squads before tick 0—assigning interlocking crossfire `ANCHOR`s, patrol loops, barricaded doors, RF jammer placements, and synchronized Go-Codes (`Alpha`/`Bravo`/`Charlie`/`Delta`).
- **Live Command Adaptation:** Issues CPU Go-Codes dynamically when a breach, alarm, or casualty occurs; shifts reserve units to reinforce breached sectors; deploys CPU counter-drones or smoke/flashbangs.

## 2. GOAP (Goal-Oriented Action Planning) Brain (`scripts/sim/ai/goap_planner.gd`, `goap_actions.gd`)
Replaces rigid single-step transitions with a lightweight, deterministic 2–4 step GOAP action planner evaluated at fixed intervals (every 12 ticks, staggered by unit ID for flat mobile CPU cost):
- **World State Facts (Bitmask/Int Dict):** `target_visible`, `lkp_known`, `in_cover`, `under_suppression`, `ammo_low`, `has_flashbang`, `has_frag`, `has_smoke`, `ally_suppressing`, `flank_open`, `spotted_by_drone`, `hostage_near`.
- **Canonical AAA Tactical Chains:**
  - *Flush Cover:* `MoveToThrowAngle` -> `ThrowFragOrFlash` -> `AdvanceOnStunned`
  - *Bounding Overwatch:* Unit A `SuppressLKP` -> Unit B `BoundCoverToCover` -> swap roles
  - *Tactical Reload:* `AmmoLow` -> `CalloutCoveringFire` -> `StepBehindHardCover` -> `Reload` -> `RePeek`
  - *Anti-Drone Counter:* `SpottedByDrone` -> `EngageDrone` OR `TriggerRFJammer` -> `RepositionCell` (never camp a cell after a drone spots you)
  - *Breach Counter:* `HearBreach` -> `FallbackToCrossfireCell` -> `PreAimFatalFunnel`

## 3. Deterministic Tactical Influence Maps (`scripts/sim/ai/influence_map.gd`)
Integer-grid heatmaps (`width_cells × height_cells`) updated incrementally inside `SimWorld.step()`:
- **Danger / LOF Heatmap:** Cells inside known hostile/operative sight cones or active gunfire lanes receive high traversal cost so `FLANKER`s route through safe corridors and alternate doors.
- **Cover Quality Evaluator:** Scores candidate cells adjacent to walls/pillars by directional protection against LKP, clean peek sightline, and at least 1 retreat exit (prevents corner-trapping).
- **Smoke / Tear-Gas Masking:** Marks occluded cells as reduced-danger so CPU units use smoke to cross open halls or extract.

## 4. Squad Micro-Tactics & Telegraphed CQB Callouts (`scripts/sim/ai/squad_tactics.gd`)
- **Crossfire Geometry:** Pairs automatically split left/right of doorways (L-shaped interlocking angles) and never stack on the same cell or block a teammate's line of fire.
- **Telegraphed Tactical Callouts:** Emits structured journal/audio events (`"CONTACT_VISUAL"`, `"SUPPRESSING"`, `"FLANKING_LEFT"`, `"RELOADING_COVER_ME"`, `"FLASH_OUT"`, `"DRONE_SPOTTED"`) so players hear/see real coordinated tactics (driven by `TacticalAudio` + optional subtitle feed).
- **Fair Difficulty Doctrines (`RECRUIT`, `VETERAN`, `TIER_ONE`):** Scales reaction ticks, GOAP chain depth, grenade/smoke usage, bounding overwatch frequency, and anti-drone adaptation—NEVER cheats with wallhacks or inflated HP.

## 5. Mandatory Headless AAA AI Verification Gates (`tests/aaa_ai_harness.gd`)
*(Use `func _init() -> void:` per Godot 4.0.4 Linux CLI compatibility.)*
1. `_test_goap_flush_cover`: Covered target triggers `ThrowFragOrFlash` -> `Advance` plan.
2. `_test_bounding_overwatch`: 2-unit CPU squad splits into `SUPPRESSOR` + `FLANKER` via `InfluenceMap` danger avoidance.
3. `_test_tactical_reload_cover`: Low-ammo CPU moves behind cover before reloading.
4. `_test_anti_drone_reposition`: CPU spotted by a playable drone engages it or relocates out of the spotted cell.
5. `_test_cpu_commander_preplan`: `CpuCommander` generates valid interlocking defense plans on `op01_glass_house.json`.
6. `_test_aaa_ai_determinism`: Full GOAP + InfluenceMap skirmish yields identical `SimWorld.state_hash()` across two same-seed runs.
