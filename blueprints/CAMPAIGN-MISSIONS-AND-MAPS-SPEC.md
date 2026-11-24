# Blueprint: 10-Mission Campaign Pack & Data-Driven Map Schema

> **Status:** Active Content & Map Loader Blueprint (extends Phases A–G; all names/locations are 100% synthetic per `RULES.md` §1.4).
> **Dual-Use Law:** Every map JSON supports Solo Campaign, 2-Player Co-op, AND 2-Player PvP (Asymmetric Breachers vs. Defenders + Symmetric Extraction) without duplicating geometry.

## 1. Data-Driven Map JSON Schema (`data/maps/<map_id>.json`)
All geometry snaps to the 16×16 px integer grid (`SimConstants.GRID_CELL_SIZE_PX`). `GreyboxMap.load_from_json(path)` parses the schema deterministically with zero autoload dependencies:
- `map_id`: string (e.g., `"op01_glass_house"`)
- `title`: string
- `floors`: int (`1`–`3`), `width_cells`: int, `height_cells`: int
- `lighting`: `"DAY"` | `"LOW_LIGHT"` | `"NIGHT"`
- `walls`: array of `{ "floor": int, "a": [x, y], "b": [x, y], "material": "DRY_WALL" | "CONCRETE" | "ARMORED" }`
- `doors`: array of `{ "id": string, "floor": int, "cell": [x, y], "orientation": "H" | "V", "state": "OPEN" | "CLOSED_UNLOCKED" | "LOCKED" | "BARRICADED" }`
- `stair_links`: array of `{ "from_floor": int, "from_cell": [x, y], "to_floor": int, "to_cell": [x, y] }`
- `insertion_zones`: array of `{ "id": string, "floor": int, "cells": [[x, y], ...], "vehicle_req": "NONE" | "VAN" | "BEARCAT" | "HELO" }`
- `extraction_zones`: array of `{ "id": string, "floor": int, "cells": [[x, y], ...] }`
- `defender_zones`: array of `{ "floor": int, "cells": [[x, y], ...] }` (used in PvP Breachers vs. Defenders)
- `objectives`: array of `{ "kind": "HOSTAGE_RESCUE" | "BOMB_DISARM" | "INTEL_EXTRACT" | "HVT_CAPTURE" | "AREA_CLEAR", "floor": int, "cell": [x, y], "timer_ticks": int }`
- `ai_spawns`: array of `{ "id": string, "archetype": string, "floor": int, "cell": [x, y], "facing_deg": int, "patrol": [[x, y], ...] }`
- `hostage_spawns`: array of `{ "id": string, "floor": int, "cell": [x, y] }`
- `jammer_nodes`: array of `{ "id": string, "floor": int, "cell": [x, y], "radius_cells": int }`

## 2. 10-Operation Campaign Escalation Arc
| Op ID | Codename | Floors | Core CQB Focus & Mechanics Introduced | Primary Objectives | RP Reward |
| :--- | :--- | :---: | :--- | :--- | :---: |
| `op01` | **Glass House** | 1 | Vertical slice: 2 operatives, 1 Go-Code (`Alpha`), door breach + flashbang | Hostage Rescue (1) | 150 |
| `op02` | **Night Shift** | 1 | Stealth vs. `Blitz`, suppressed sidearms, locked rear entry, `PATROL_SENTRY` hearing | Area Clear + Intel | 200 |
| `op03` | **Iron Shutter** | 1 | Warehouse sightlines, `ROOM_ANCHOR` crossfire, BearCat exterior cover, `Alpha`/`Bravo` breach | Hostage Rescue (2) | 250 |
| `op04` | **Silent Relay** | 1 | Low-light server room, `TECH_JAMMER` RF zones, playable Ground Recon Bot, lockpick/electronics | Intel Extract | 300 |
| `op05` | **Penthouse Lock** | 2 | Multi-floor stairwell fatal funnels, `HOSTAGE_GUARD`, `Escort` mode, police `SURRENDER` morale break | Hostage Rescue (2) | 350 |
| `op06` | **Redline Terminal** | 1 | Timed `BOMB_DISARM` (`demolitions`), wide concourse cover, `TACTICAL_FLANKER` counter-flanks | Bomb Disarm (2) | 400 |
| `op07` | **Blackwater Pier** | 2 | Narrow ship corridors, barricaded bulkheads, `HEAVY_GUNNER` suppression, `Shield` + `Breacher` | HVT Capture | 450 |
| `op08` | **Cold Vault** | 2 | Regional bank vault, roof/rear insertion (SUV/Helo), 3-squad `Alpha`/`Bravo`/`Charlie` sync | Hostage Rescue (3) | 500 |
| `op09` | **Signal Tower** | 3 | 3-floor vertical assault, overlapping RF jammers, indoor Micro-UAV recon, high-morale OpFor | Bomb Disarm + Intel | 600 |
| `op10` | **Sovereign Citadel** | 2 | Courtyard BearCat ram-breach + villa 4-squad `Alpha`/`Bravo`/`Charlie`/`Delta` finale | HVT Capture + Rescue | 800 |

## 3. Mission Grading & Replayability
- **Score Breakdown (deterministically computed at mission end):**
  - Objective Completion (`+100%` base RP)
  - Zero Operative Casualties (`+25%` RP bonus)
  - Zero Hostage Harm / Clean ROE (`+20%` RP bonus; collateral harm applies `-50%` penalty)
  - Tactical Speed / Stealth Bonus (`+15%` RP)
- **PvP Arena Support:** Every `op01`–`op10` JSON loads directly into 2-Player Asymmetric PvP (using `defender_zones`) or Symmetric Extraction (splitting `insertion_zones` across Faction 0 and Faction 1).

## 4. Mandatory Map Validation Gate (`tests/map_validation_harness.gd`)
Headless test validates every `data/maps/*.json`:
1. Schema parses cleanly with valid `width_cells`, `height_cells`, and `floors`.
2. Every `insertion_zone`, `extraction_zone`, `objective`, `ai_spawn`, and `hostage_spawn` sits inside bounds on a walkable cell.
3. `GridPathfinder` confirms at least one valid path (allowing door breaches) from an insertion zone to every objective and extraction zone.
4. `Visibility.compute_polygon()` executes cleanly with zero degenerate/NaN polygons from every spawn cell.

## Decision D-MISSION-01 · Ground-floor mission results

The ground-floor runner treats each authored objective cell as a checkpoint. Once the routes finish, success requires all checkpoints to have been reached and a surviving operative at an exit when the map defines one. The result screen shows the outcome and supports replanning with the routes retained. Operations whose objectives and exits are only on upper floors offer labeled ground-floor practice. Dedicated rescue, timed interaction, multi-floor travel, and progression rewards remain separate campaign milestones.
