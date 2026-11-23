# Blueprint: Meta-Progression, Playable Drones, Vehicles & Real CQB Mechanics

> **Status:** Active Long-Term Master Expansion Blueprint (extends `N64-R6-TACTICAL-PLANNING-SPEC.md` and `TWO-PLAYER-COOP-PVP-SPEC.md`).
> **Vision:** Full-blown bird's-eye real-time tactical planner shooter with authentic police/military CQB mechanics, playable recon/tactical drones, insertion/support vehicles, deep armory & roster meta-progression, and simultaneous 2-player Co-op or PvP.
> **Determinism Law:** Every CQB mechanic, drone flight/crawl, vehicle deployment, and loadout stat resolves inside 60 Hz deterministic `SimWorld.step()`. Playable drones use the exact same tick-indexed `OverrideCommand` pipeline (Decision D-TAPIN-01).

## 1. Real Police & Military CQB Mechanics
- **Entry Doctrines:**
  - *Deliberate Entry:* Stack on doorway -> under-door camera/mirror peek -> slice the pie (progressive Field of Fire arc rotation) -> clear corners methodically.
  - *Dynamic Entry:* Stack -> synchronized Go-Code (`Alpha`/`Bravo`/`Charlie`/`Delta`) -> mechanical/explosive breach -> flashbang/CS gas -> flood room along interlocking Fields of Fire.
- **Door & Threshold Simulation:**
  - Door states: `OPEN`, `CLOSED_UNLOCKED`, `LOCKED`, `BARRICADED`, `BREACHED_DESTROYED`.
  - Fatal funnels: narrow doorways apply accuracy/exposure penalties to operatives lingering in the threshold without cover or flashbang suppression.
  - Breach methods: silent lockpick (`electronics` skill), battering ram / Halligan (fast, medium noise), ballistic shotgun breach (loud, instant on locks), C4/detcord charge (destroys barricades + stuns adjacent hostiles).
- **Ballistics, Armor & Suppression:**
  - Caliber vs. Armor tiers (`Light` Level IIA, `Medium` Level II, `Heavy` Level III/IV + ballistic shield directional cone).
  - Suppression meter per unit: near-miss gunfire degrades accuracy/reticle and pressures `self_control` (driving AI into cover or panic unless steadied by high Team Leader `leadership`).
  - Medical states: `HEALTHY` -> `WOUNDED` (speed/aim penalty, optional bleed) -> `INCAPACITATED` (stabilizable by Medic/IFAK) -> `KIA` (campaign permadeath).
- **Acoustic & Electronic Warfare:**
  - Suppressed vs. unsuppressed acoustic rings alert nearby hostiles and show directional sound blips in PvP.
  - Defender countermeasures: door barricades, trip/motion alarms, RF signal jammers (degrade Heartbeat Sensor and disrupt playable drones inside jam radius).

## 2. Playable Drones & Ground Recon Bots (Tap-In Compatible)
- **Drone Classes:**
  - *Throwable Ground Recon Bot:* Compact wheeled crawler tossed into hallways or under gaps; quiet, low profile, climbs small thresholds, transmits live 360° or cone visibility polygon into `FogLayer`.
  - *Indoor Micro-UAV (Quadcopter):* High mobility, ignores low cover/furniture, louder acoustic signature (alerts hostiles/defenders if flown close), limited battery ticks.
  - *Tactical Utility Drone (Unlockable):* Carries single-use micro-flash, acoustic lure, or remote breach relay.
- **Planning & Live Execution Integration:**
  - Drones can be pre-programmed with recon waypoints during Planning OR **tapped-in directly** during Execution via `OverrideCommand` (same 60 Hz deterministic stream as operatives, with separate drone battery/signal limits and RF jammer interference).
  - Drone vision polygons feed directly into the faction's GPU `SubViewport` `FogLayer` (`live_vp` + `memory_vp`), letting a player scout a room live before issuing Go-Code `Alpha`.
  - Vulnerability: Drones can be shot down by hostiles/defenders or disabled inside RF jam zones; losing a drone removes its live sightline (visited memory remains at 50% opacity).

## 3. Vehicles (Insertion, Breach, Mobile Cover & Extraction)
- **Vehicle Classes (Meta-Unlockable):**
  - *Unmarked Raid Van:* Stealth approach, fast perimeter drop-off, low armor.
  - *Armored SWAT APC / BearCat:* Bulletproof mobile cover in exterior courtyards, ram-breach capability on exterior gates/walls, onboard kit/ammo resupply point.
  - *Tactical Extraction SUV / Helo Insertion:* Unlocks alternate roof/rear insertion zones and rapid VIP/hostage extraction points on eligible maps.
- **Simulation Representation:**
  - Vehicles register dynamic solid wall segments (blocking bullets & LOS via `GreyboxMap.get_wall_segments()`), spawn insertion/extraction zones, and optionally execute scripted arrival/ram paths on a Go-Code trigger.

## 4. Meta-Progression System (Persistent Unit HQ)
Persisted locally in versioned JSON (`UnitProfile` / `CampaignState`, separate from deterministic `MissionSnapshot`):
- **Operative Roster & CQB Positions (Billets):**
  - Synthetic operative pool (`OPR_01`, etc., per `RULES.md` §1.4) earning XP, mission ribbons, and trait/skill growth per completed operation.
  - **Tactical Positions / Roles:**
    - `Squad Leader` (boosts squad `leadership` aura & reduces Tap-In cooldown)
    - `Pointman` (faster FoF rotation, higher `firearms` reaction speed, threat spotting)
    - `Breacher` (`demolitions` & shotgun/ram/C4 speed bonus, heavy armor efficiency)
    - `Shield / Heavy` (directional ballistic shield arc, draws fire, breach anchor)
    - `Tech / Drone Operator` (`electronics` speed, extra drone battery/jam resistance, Heartbeat Sensor range)
    - `Marksman / Overwatch` (long-range sightline & exterior overwatch angle bonus)
    - `Medic / Rescue` (stabilizes `INCAPACITATED` operatives, faster `Escort` hostage movement)
- **Armory & Gear Tree:**
  - Unlock and equip Primary Weapons (SMGs, Carbines, Rifles, Breaching Shotguns), Secondary Sidearms, Attachments (Suppressors, Optics, Lasers/Lights, AP/Subsonic ammo), Armor Classes (Light/Medium/Heavy + Helmet/Shield), Tactical Tools (Under-Door Cam, Lockpick, Electronics, Demolitions, Heartbeat Sensor, IFAK, Jammers/Traps for PvP Defenders), Drones, and Vehicles.
- **Economy & Mission Grading:**
  - Operations award **Requisition Points (RP)** and **Unit XP** graded on Objective Completion, Zero Casualties, Hostage Safety, ROE Compliance, and Stealth/Speed bonuses.
  - **PvP Balance Rule:** Ranked/Fair-Play PvP supports both *Standardized Loadout Points* (equal RP budget per match so skill/planning wins) and *Open Unit Roster* mode for custom friend matches.
