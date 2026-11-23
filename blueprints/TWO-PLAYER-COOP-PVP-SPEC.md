# Blueprint: Simultaneous 2-Player Co-op & PvP Architecture

> **Status:** Active Expansion Blueprint (builds on `blueprints/N64-R6-TACTICAL-PLANNING-SPEC.md` and Decision D-TAPIN-01).
> **Execution Model:** One continuous N64-style execution phase (plan once -> lock in -> continuous 60 Hz execution until mission outcome).
> **Balance Pillar:** Tap-In Direct Control is gated by cooldowns and a tactical command budget so pre-mission planning remains decisive over pure twitch play.

## 1. Supported 2-Player Modes
1. **Co-op Assault (2vAI):**
   - P1 owns `Red`/`Blue` squads; P2 owns `Green`/`Gold` squads.
   - Planning Phase: Shared live blueprint (both players see each other's routes, Go-Code wait markers, and breach points in real time).
   - Execution Phase: Shared Fog of War; both players watch full bird's-eye view, trigger Go-Codes (`Alpha`/`Bravo`/`Charlie`/`Delta`), and can tap-in to different operatives simultaneously.
2. **Asymmetric PvP — Breachers vs. Defenders:**
   - **Faction 0 (Breachers):** Plans insertion routes, breach charges, flashbangs/frags, Fields of Fire, and Go-Codes from perimeter zones (interior starts shrouded except intel markers).
   - **Faction 1 (Defenders):** Plans interior patrol loops, ambush Fields of Fire, locked/barricaded doors, acoustic alarms/traps, and defender Go-Codes.
   - Planning Phase: **Simultaneous Blind Timed Planning** (configurable 60s / 90s / 120s countdown). Neither side sees the other's plan before lock-in.
   - Execution Phase: **Per-Faction Fog of War** (`FogLayer` computes `Visibility.compute_polygon()` only for `o.faction == local_faction`). Enemy units outside sightlines are hidden except for acoustic emission rings and Heartbeat Sensor blips.
3. **Symmetric PvP — Extraction / Skirmish:**
   - Both players deploy 2–4 operatives from opposite perimeters under blind timed planning to secure and extract a central objective (hostage, intel, or VIP) with per-faction Fog of War and simultaneous tap-in combat.

## 2. Tap-In Cooldowns & Command Budget (Anti-Twitch Guardrails)
All values live in `scripts/sim/sim_constants.gd` and are enforced deterministically inside `SimWorld.step()` (60 Hz ticks):
- **`TAPIN_HANDOFF_TICKS = 30` (0.5s):** Brief radio-handoff delay when tapping into an operative before manual movement/fire activates (prevents instant cross-map snap-firing).
- **`TAPIN_MAX_BURST_TICKS = 600` (10.0s):** Maximum continuous direct-control window per tap-in before automatic return to AI plan execution.
- **`TAPIN_COOLDOWN_TICKS = 480` (8.0s):** Per-player global cooldown after releasing (or timing out of) an operative before the player can tap-in again.
- **`TAPIN_UNIT_COOLDOWN_TICKS = 720` (12.0s):** Per-operative cooldown before the same operative can be tapped into again (encourages coordinating across squads rather than solo-carrying one unit).
- **`TAPIN_COMMAND_POINTS_MAX = 4`:** Finite tactical override charges per mission (1 CP spent per tap-in; optional slow regen or objective-bonus CP in longer missions).
- **Leadership Synergy:** A Team Leader's `leadership` trait (0–100) scales `TAPIN_COOLDOWN_TICKS` by up to `-20%` for their squad, tying N64 roster selection directly into live execution economy.
- **Clean Plan Resumption:** When tap-in ends, the operative resumes their next uncompleted waypoint from their current cell via `GridPathfinder` (or holds position with active Field of Fire if the queue is empty).

## 3. Networking & Determinism Architecture
- **Transport (Phase D1 — Zero-Server LAN / Direct Wi-Fi):** Godot 4 `ENetMultiplayerPeer` (UDP) over local Wi-Fi/hotspot; Host/Client handshake exchanges mission ID, RNG seed, and mode config.
- **Commit-Reveal Blind Planning (PvP Anti-Peek):**
  1. When a player presses Ready (or timer hits 0), their device serializes their full squad plan and sends `SHA-256(plan_json + salt)` to the peer.
  2. Once both commitments are received, both devices exchange `plan_json + salt`, verify the peer's hash, initialize identical `SimWorld` snapshots, and begin tick 0 simultaneously.
- **60 Hz Deterministic Lockstep:**
  - Every tick, each device exchanges only lightweight input packets (`tick`, `faction_id`, `go_codes_bitmask`, `mode_changes`, and quantized `OverrideCommand` if tapped in).
  - Input delay buffer (`LOCKSTEP_INPUT_DELAY_TICKS = 3`, 50 ms) absorbs LAN jitter without breaking 60 Hz fixed-step determinism.
  - Periodic state-hash checksum (`SimWorld.state_hash()` every 60 ticks) detects any desync immediately and logs diagnostics.
- **Sim Layer Isolation (`RULES.md` §3.4):** `scripts/sim/` remains 100% network-free and autoload-free. Networking lives under `scripts/net/` (`lockstep_session.gd`, `commit_reveal.gd`) and feeds validated commands into `SimWorld`.

## 4. Per-Faction Visibility & Fog Isolation
- `SimOperative` gains `faction_id: int` (`0` = Team/Breachers, `1` = Defenders/OpFor) and `owner_peer_id: int`.
- `PlanningRoot._update_fog()` filters operatives by `o.faction_id == local_faction_id` before calling `Visibility.compute_polygon()`, so the GPU `SubViewport` `FogLayer` requires zero structural changes to support Co-op and PvP.
- Enemy tokens are rendered only when inside the local faction's active visibility polygon or within an equipped Heartbeat Sensor pulse radius; acoustic rings render briefly when out-of-sight enemies fire unsuppressed weapons or sprint (`Blitz`).
