# Blueprint: N64 Rainbow Six Mirror Tactical Map, MIL-STD C4I UI/UX & RTS-RPG Upgrade

> **Status:** Active Phase J Visual & UX Upgrade Blueprint (replaces Phase I stub implementations with production-grade, touchscreen-modernized N64 Rainbow Six tactical planning UI + MIL-STD-2525-inspired symbology + RTS-RPG progression presentation).
> **Core Identity:** Real-Time Tactical Planner + RTS-RPG. Authentic military/police C4I blueprint clarity (training-grade top-down situational awareness) wrapped in a fast, thumb-friendly Portrait `1080×1920` Android game.

## 1. Re-Audit Findings (Stubs to Replace Immediately)
- `scripts/ui/theme_manager.gd`: `apply()` is currently empty (`pass` in all 3 match branches) — MUST generate and apply real Godot `Theme` + `StyleBoxFlat` palettes to the scene tree and `MapRenderer`.
- `scripts/planning/map_renderer.gd`: Currently 44 lines of flat rectangles — MUST upgrade to full N64 architectural blueprint rendering with military grid coordinates, wall materials, door symbology, zones, and multi-floor ghosting.
- `scripts/planning/squad_hud.gd`: Currently a 30-line `Node2D` drawing world-space circles — MUST upgrade to a screen-space `CanvasLayer`/`Control` N64 color-coded Squad Status HUD (`Red`/`Blue`/`Green`/`Gold` boxes, Mode badge, health dots, Tap-In CP/cooldown ring).

## 2. N64 Rainbow Six Tactical Planning Map Mirror (Modernized for Touch)
### A. Architectural Blueprint Canvas (`scripts/planning/map_renderer.gd`)
- **Tactical Grid & MGRS-Style Coordinates:** Alphanumeric column headers (`A`–`Z`) and numeric row labels (`01`–`99`), 5-cell major sector lines, North compass indicator, and metric scale bar (`1 cell = 1.0 m`).
- **Wall Material Rendering:** `CONCRETE` (thick hatched perimeter walls), `DRY_WALL` (thin interior partitions), `ARMORED` (double-lined reinforced walls).
- **Door & Threshold Symbology:** Swing-arc icon (`CLOSED_UNLOCKED`), padlock badge (`LOCKED`), diagonal X-hatch (`BARRICADED`), dashed open gap (`BREACHED_DESTROYED`).
- **Tactical Zone Overlays:** Striped green `INSERTION` zones (with vehicle class glyph), checkered amber `EXTRACTION` zones, red `OBJ`/`HST`/`BOMB`/`HVT` intel pins, and dashed cyan `RF JAM` circles.
- **Multi-Floor Blueprint Switcher:** `F1`/`F2`/`F3` pill toggle with stairwell connector chevrons and 15% opacity ghost outlines of adjacent floors.

### B. 4-Squad Color-Coded Route & Synchronized Timing Overlay (`plan_board.gd`, `planning_controller.gd`)
- **N64 Squad Palette:** `RED` (`#EF4444`), `BLUE` (`#3B82F6`), `GREEN` (`#22C55E`), `GOLD` (`#F59E0B`).
- **Waypoint Callout Nodes:** Numbered nodes (`1`, `2`, `3`...) displaying attached Go-Code diamond (`A`/`B`/`C`/`D`), ROE Mode tag (`ENG`/`ADV`/`ESC`), Stance chevrons (`>>>` Blitz / `>>` Normal / `>` Cautious), Action glyph (`FB`/`FG`/`TG`/`C4`), and translucent **Field of Fire (FoF) sector wedge** with bearing readout (`090° ±35°`).
- **Synchronized Breach ETA Strip:** Computes deterministic `GridPathfinder` travel time per squad to each Go-Code (e.g., `RED → A: 6.2s | BLUE → A: 5.8s`) so commanders can synchronize multi-door breaches to the tenth of a second.
- **Touch Ergonomics (`RULES.md` §4):** Observation Mode (1-finger pan, 2-finger pinch) -> Long-press Operative enters Routing Mode with upward finger offset + top-right `220×220` PiP Loupe (`SubViewport`, `msaa_2d = DISABLED`) -> Tap Waypoint opens bottom-arc **Radial Command Node Menu** (`Stance`, `Mode`, `Go-Code`, `Action`, `FoF`, `Delete`).

### C. MIL-STD-2525 / APP-6 Inspired Symbology (`operative_token.gd`, `icon_registry.gd`)
- **Friendly Operatives:** Squad-colored framed unit marker with directional barrel/sight cone, CQB billet icon (Lead/Pointman/Breacher/Shield/Tech/Marksman/Medic), and compact callsign (`R1`, `B2`).
- **Hostiles & LKP:** Red diamond frame when in active LOS; fading ghost diamond (`?` + seconds-since-contact) at Last Known Position (LKP) when LOS breaks—no wallhacking.
- **Hostages / Civilians:** Blue/green neutral square frame (`HST`).
- **Playable Drones & Vehicles:** Rotated UAV/crawler glyph with battery/signal bar + sight cone; rectangular armored NATO vehicle frame (`APC`/`VAN`/`HELO`).

## 3. RTS-RPG Progression & Dossier Presentation
- **N64-Style Operative Dossier (`roster_roles_screen.gd`):** Clean horizontal bar graphs for the 5 Traits (`Aggression`, `Leadership`, `Self Control`, `Stamina`, `Teamwork`) and 5 Skills (`Demolitions`, `Electronics`, `Firearms`, `Grenades`, `Stealth`), plus RPG Rank/XP bar, CQB Billet specialization perks, mission ribbons, and `HEALTHY`/`WOUNDED`/`KIA` status.
- **Armory & Loadout Bench (`hq_armory_screen.gd`):** Visual slot cards for Primary, Secondary, Slot 1, Slot 2, Armor Class (`Light`/`Medium`/`Heavy` + Shield), Drone, and Insertion Vehicle with live stat delta bars (Weight/Speed, Noise, Armor Tier, RP Cost) and one-tap "Apply Kit to Squad".
- **Screen-Space N64 Squad HUD (`squad_hud.gd` + `execution_hud.gd`):** Bottom-anchored `CanvasLayer` cards for `RED`/`BLUE`/`GREEN`/`GOLD` showing active Mode, Go-Code wait pulse, per-operative Green/Yellow/Red health dots, Tap-In Command Points (`CP 4/4`) + cooldown ring, and one-tap operative/drone Tap-In trigger.

## 4. Real Theme Engine (`scripts/ui/theme_manager.gd`)
- Builds a real `Theme` resource using `StyleBoxFlat` (crisp 1–2 px tactical borders, subtle corner bevels, high-contrast typography, >= 72×72 px touch targets when `accessible_scaling` is enabled) and applies it live to `get_tree().root.theme` + notifies `MapRenderer` and HUD nodes via signal `theme_changed(palette: Dictionary)`.
- Supports **Dark Tactical (C4I)**, **Light Blueprint (Daylight)**, and **Night-Ops (NVG OLED)**, persisted in `user://settings.json`.

## 5. Mandatory Visual & UI Audit Gate (`tests/ui_polish_audit.gd`)
Headless test verifies:
1. `ThemeManager.apply()` generates a non-null `Theme` with distinct background/accent colors for all 3 styles (zero `pass` stubs).
2. `MapRenderer` exposes theme-reactive palette binding and draws coordinates, wall materials, doors, and zones without errors.
3. `SquadHud` is a `Control` (screen-space) with clickable squad/operative status cards.
4. `MissionPrepPanels` instantiates real interactive `Control` children for all 6 N64 stages (`Briefing` -> `Planning`).
