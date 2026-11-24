# Blueprint: N64 Rainbow Six Tactical Planning & Bird's-Eye Tap-In Spec

> **Status:** Active Canonical Expansion Blueprint (overrides pure-observer execution constraint via Decision D-TAPIN-01 while preserving 60 Hz determinism and replayability).
> **Reference Source:** Tom Clancy's Rainbow Six (Nintendo 64, NUS-NR6E-USA Instruction Manual).
> **Scope Note:** 2-Player Co-op transport & control architecture is intentionally deferred to a separate brainstorming pass.

## 1. 7-Stage N64 Mission Flow
1. **Briefing:** Mission objectives, threat background, commander/advisor notes (synthetic placeholders only per RULES.md §1.4).
2. **Intel:** Categorized dossiers (`People`, `Organizations`, `Misc`) plus floor-plan intel markers (known hostage/hostile/entry locations).
3. **Roster:** Select up to 4 operatives from the unit pool. Campaign KIA is permanent if the player advances without replaying the mission.
   - **5 Traits (0–100):** `aggression`, `leadership`, `self_control`, `stamina`, `teamwork`.
     - `leadership` of the Team Leader buffs/debuffs `teamwork` and `self_control` of squadmates.
     - Low `self_control` under heavy fire risks panic/snap; `aggression` governs snap behavior (reckless fire vs. seeking cover).
     - `stamina` governs wound tolerance before incapacitation.
   - **5 Skills (0–100):** `demolitions`, `electronics`, `firearms`, `grenades`, `stealth`.
     - `demolitions`: breaching charge placement speed, bomb disarm speed, shotgun breach efficiency.
     - `electronics`: lockpicking, bugging, security bypass speed.
     - `firearms`: weapon spread/reticle tightness, recovery speed, reaction time.
     - `grenades`: throw accuracy for flashbangs/frags.
     - `stealth`: movement acoustic emission multiplier.
4. **Kit (Loadout):** Per-operative loadout (with one-tap "Apply to All" option):
   - **Primary Weapon:** Submachine guns (standard & integrally suppressed), compact carbines, assault rifles (armor-piercing long range), tactical breaching shotgun.
   - **Secondary Weapon:** Standard or suppressed sidearm.
   - **2 Equipment Slots:** Extra Primary Mags, Extra Secondary Mags, Frag Grenades, Flashbangs, Heartbeat Sensor (wall-penetrating hostile blips on Overview Map), Lockpick Kit, Electronics Kit, Demolitions Kit.
   - **Uniform & Armor Class:** `Light` (quiet/fast, low pistol protection), `Medium` (balanced), `Heavy` (high rifle/blast protection, slower/louder).
5. **Team Assignment:** Split up to 4 operatives into 1–4 color-coded squads (`Red`, `Blue`, `Green`, `Gold`). Promote any squad member to Team Leader.
6. **Planning Screen (Top-Down Tactical Blueprint):**
   - Multi-floor blueprint support (floor up/down switcher + zoom/pan).
   - Color-coded per-team waypoint routing on the 16 px `AStarGrid2D` grid.
   - **4 Synchronized Go-Codes:** `Alpha`, `Bravo`, `Charlie`, `Delta` (team halts at waypoint until matching Go-Code is issued).
   - **3 Team Modes (ROE) per Waypoint Segment:**
     - `Engage` (advance, engage targets of opportunity, do not chase fleeing hostiles)
     - `Advance` (move rapidly to next waypoint, fire only at threats directly in path without pausing)
     - `Escort` (lead rescued hostages along cleared path to extraction)
   - **3 Movement Stances/Speeds:** `Blitz` (6.4 cells/s, 1.5x noise), `Normal` (4.0 cells/s, 1.0x noise), `Cautious` (2.0 cells/s, 0.35x noise).
   - **Special Waypoint Actions:** `Flashbang`, `Frag Grenade`, `Tear Gas`, `Breach Charge`, `Field of Fire` (independent facing arc).
7. **Execute (Bird's-Eye Mission Watch + Live Tap-In):**
   - Full bird's-eye orthographic tactical view with GPU-masked Fog of War (live sight + 50% opacity visited memory).
   - N64 Overview Map symbology: facing-indicator circles (white/squad-colored = operatives, red = hostiles, blue = hostages), Heartbeat Sensor pulse blips through walls when equipped.
   - Color-coded Squad Status HUD: active Mode badge + per-operative health dots (`Green` = healthy, `Yellow` = wounded, `Red` = KIA).
   - Live commander overrides: issue `Alpha`/`Bravo`/`Charlie`/`Delta` Go-Codes, cycle squad Mode (`Engage`/`Advance`/`Escort`), cycle squad Speed.

## 2. Decision D-TAPIN-01: Deterministic Tap-In Direct Control
- During `EXECUTION`, the player may tap any living operative (on the map or Squad HUD) to take direct top-down control.
- **Control Scheme (Mobile Portrait 1080x1920):** Virtual left-thumb move pad + right-thumb aim/fire/action trigger (or tap-to-move + drag-to-aim) while keeping the bird's-eye camera centered or follow-locked on the controlled operative. Tapping "Release / AI" returns the operative to their next queued waypoint.
- **Determinism Guarantee:** Live player inputs NEVER mutate `SimOperative` directly from `_process()` or input callbacks. Instead, each physics tick (60 Hz) serializes active tap-in input into a deterministic `OverrideCommand` (`tick`, `operative_id`, `move_dir_q`, `aim_deg_q`, `fire_pressed`, `use_slot`) appended to `SimWorld`'s command journal. Replaying `MissionSnapshot` + initial plans + recorded `OverrideCommand` stream reproduces the exact outcome frame-for-frame.

## Decision D-PLAN-01 · Route commands for the ground-floor runner

A route through a closed game door queues the existing door action before its movement command. The planner reports the number of added actions. Tap a committed route cell, then tap a go-code button to assign a wait at that cell. Tap the same code again to clear it. During execution the same controls issue the recorded go-codes through the tick stream. This provides touch access to waits while the full waypoint editor remains in the blueprint.
