# Blueprint: Advanced Deterministic CQB AI Behavior Spec

> **Status:** Active Canonical AI Blueprint (pure autoload-free GDScript under `scripts/sim/ai/`, 60 Hz fixed tick, seeded RNG only).
> **Design Goal:** Authentic police/military CQB AI—no wallhacking, genuine Last Known Position (LKP) memory, threat-weighted flanking, interlocking crossfire, suppression/morale, and zero non-deterministic physics steering.

## 1. 3-Layer Deterministic AI Architecture

### Layer 1 — Sensory & Threat Blackboard (`scripts/sim/ai/threat_blackboard.gd`)
- **Dual-Cone Vision:**
  - *Focal Cone* (`±35°`, full range): Fast target acquisition (`reaction_ticks` scaled by archetype/skill).
  - *Peripheral Cone* (`±75°`, 60% range): Triggers `SUSPICIOUS` head-turn toward the stimulus rather than instant snap-firing.
  - Occluded by solid walls, closed doors, smoke/tear gas, and darkness/flashbang blindness.
- **Wall-Attenuated Acoustic Perception:**
  - Sound events carry `(cell, radius_cells, kind, tick)`: `FOOTSTEP_BLITZ`, `FOOTSTEP_NORMAL`, `DOOR_BREACH`, `GUNSHOT_UNSUPPRESSED`, `GUNSHOT_SUPPRESSED`, `FLASHBANG`, `DRONE_BUZZ`, `SHOUT`.
  - Intervening walls attenuate effective hearing radius by `-35%` per wall segment crossed (deterministic ray count against `GreyboxMap.get_wall_segments()`).
- **Last Known Position (LKP) Memory & Discovery:**
  - Enemies NEVER track players through walls. Breaking LOS freezes the target's `LKP` cell and velocity vector.
  - Confidence decays over ticks (`CONFIRMED` -> `STALE` after 240 ticks -> `EXPIRED` after 900 ticks).
  - Visual discovery of a downed ally, breached door, or active recon drone immediately escalates faction alert (`UNAWARE` -> `ALERTED` -> `COMBAT`).

### Layer 2 — Squad-Level Tactical Coordinator (`scripts/sim/ai/squad_coordinator.gd`)
Nearby hostiles within shout or radio range share a deterministic `SquadBlackboard` and dynamically assign roles via integer/fixed-order utility scoring:
- **`ANCHOR` (Crossfire Holder):** Picks cover cells with clear sightlines onto fatal funnels/doorways; refuses to step blindly into an active operative Field of Fire.
- **`SUPPRESSOR`:** Fires controlled bursts at an operative's `LKP` to build suppression and pin them while teammates maneuver.
- **`FLANKER`:** Queries `GridPathfinder` (`AStarGrid2D`) using a **threat-weighted cell cost overlay** (cells inside known operative sightlines carry heavy traversal penalty) to route through alternate doors/corridors and strike the flank.
- **`RUNNER` / `TECH`:** Moves to activate room alarms, RF jammers (to blind playable drones/Heartbeat Sensors), or reinforce the hostage/objective room.
- **Friendly Squad Micro-Cohesion:** Operatives strictly obey player-drawn routes (zero RVO path deviation per `RULES.md` §4), while sharing contact callouts (reducing squadmate `reaction_ticks` by 25%) and prioritizing uncovered threats within their Field of Fire.

### Layer 3 — Individual Tactical FSM & Utility Brain
#### Enemy FSM (`scripts/sim/ai/enemy_ai.gd`)
States: `IDLE_GUARD`, `PATROL`, `INVESTIGATE_LKP`, `HOLD_AMBUSH`, `SUPPRESS_LKP`, `FLANK_ROUTE`, `TAKE_COVER`, `STUNNED`, `FALLBACK_RALLY`, `HOSTAGE_COERCE`, `SURRENDER`.
- **Target Utility Scoring:** Ranks visible targets (operatives and playable drones) by `proximity + facing_threat + active_shooter - cover_factor`.
- **Suppression & Morale (0–100):**
  - Near-miss bullets, flashbangs, breach explosions, and ally casualties raise `suppression` and reduce `morale`.
  - High-morale military archetypes dig into cover or counter-flank; low-morale hostiles hesitate, retreat to rally cells, or enter `SURRENDER` under police CQB overwhelm (flashbanged + outnumbered + low `aggression`).
- **PvP Mode Integration:** In 2-Player PvP, Defenders use player-planned `CommandQueue` + Defender reflex AI (`HOLD_AMBUSH` / `ENGAGE` / `FALLBACK`) + live Tap-In overrides instead of autonomous OpFor roaming.

#### Friendly Reflex AI (`scripts/sim/ai/friendly_reflex_ai.gd`)
- Enforces `Engage` / `Advance` / `Escort` ROE modes alongside `CommandQueue`.
- **Hostage Safety Gate:** Ray-checks firing line against all hostage cells; holds fire if a hostage is in the line of fire unless `self_control` snaps under extreme suppression.

#### Hostage AI (`scripts/sim/ai/hostage_ai.gd`)
- States: `CAPTIVE` (ducks during nearby gunfire/blasts) -> `FOLLOW_ESCORT` (trails `Escort` operative via `AStarGrid2D`) -> `EXTRACTED`.

## 2. Data-Driven Enemy Archetypes (`scripts/sim/ai/ai_archetypes.gd`)
| Archetype | Reaction Ticks | Focal Range | Hearing Mult | Base Morale | Preferred Role |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `PATROL_SENTRY` | 24 (0.40s) | 10 cells | 1.0 | 55 | `PATROL` -> `INVESTIGATE_LKP` |
| `ROOM_ANCHOR` | 18 (0.30s) | 12 cells | 0.9 | 70 | `ANCHOR` (fatal funnel crossfire) |
| `TACTICAL_FLANKER` | 15 (0.25s) | 11 cells | 1.15 | 80 | `FLANKER` (threat-weighted A*) |
| `HEAVY_GUNNER` | 22 (0.37s) | 13 cells | 0.85 | 90 | `SUPPRESSOR` (pins LKP) |
| `TECH_JAMMER` | 26 (0.43s) | 9 cells | 1.1 | 60 | `RUNNER` (jammers/alarms/anti-drone) |
| `HOSTAGE_GUARD` | 20 (0.33s) | 9 cells | 1.0 | 65 | `ANCHOR` / `HOSTAGE_COERCE` |

## 3. Mandatory Headless AI Verification Gates (`tests/determinism_harness.gd`)
1. `_test_ai_no_wallhack_lkp`: Hostile loses LOS -> fires/investigates only LKP, never tracks operative behind wall.
2. `_test_ai_acoustic_wall_attenuation`: Unsuppressed shot triggers `SUSPICIOUS` through 1 wall; suppressed shot does not.
3. `_test_ai_threat_weighted_flank`: `FLANKER` routes around operative's Field of Fire via secondary door instead of walking down the fatal funnel.
4. `_test_ai_flashbang_morale_stun`: Flashbang applies `STUNNED` lock + morale drop; low-morale target transitions to `SURRENDER` when overwhelmed.
5. `_test_ai_hostage_lof_safety`: Friendly operative in `Engage` mode holds fire when a hostage blocks the firing line.
6. `_test_ai_determinism_replay`: Full multi-squad skirmish produces identical `SimWorld.state_hash()` across two runs with the same seed.
