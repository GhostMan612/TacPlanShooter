# Blueprint: C4I Mobile UI & Tactical Audio Architecture

> **Status:** Active UX & Audio Blueprint (strictly implements `RULES.md` §4 UI modes, MSAA-off, texture atlas, and audio laws for Portrait `1080×1920` Android).

## 1. Portrait `1080×1920` C4I Screen Layout (`CanvasLayer`)
All HUD elements live inside a screen-space `CanvasLayer`, using unified texture atlases to minimize draw calls (`RULES.md` §4):
- **Top Bar (`y: 0..140`):** Mission codename, Floor Switcher (`F1`/`F2`/`F3`), Phase/Timer readout, and Command Points (`CP 4/4`) + Tap-In Cooldown ring.
- **Tactical Blueprint Viewport (`y: 140..1580`):** Orthographic map canvas + GPU `FogLayer` + operative/drone tokens + route `Line2D`s (with `antialiased = false` and alpha-gradient UV texture).
- **Bottom Thumb-Arc Dock (`y: 1580..1920`):**
  - *Planning Mode:* Squad selector tabs (`Red`, `Blue`, `Green`, `Gold`), `Execute` commit button, `Undo`/`Clear`, and contextual **Radial Command Node Menu** (opens on waypoint tap: `Stance`, `Mode`, `Go-Code`, `Action`, `Field of Fire`, `Delete`).
  - *Execution Watch Mode:* Color-coded **Squad Status Boxes** (Mode badge + Green/Yellow/Red operative health dots — tap any living operative or drone to trigger Tap-In) + 4-button **Go-Code Strip** (`Alpha`, `Bravo`, `Charlie`, `Delta`) + `Reset`.
  - *Tap-In Direct Control Overlay:* Replaces bottom dock while controlling an operative/drone — Left thumb virtual move pad (`x: 40..420`), Right thumb aim/fire ring (`x: 660..1040`), center-top `Release to AI` pill + remaining burst countdown bar (`10.0s`).

## 2. Strict Modal Touch Input (`RULES.md` §4)
1. **Observation Mode (default):** 1-finger pan, 2-finger pinch zoom; accidental touches never alter waypoints.
2. **Routing Mode (long-press operative):** Camera offsets slightly upward so the player's finger never occludes the operative; top-right **Picture-in-Picture Loupe** (`220×220` `SubViewport`, `msaa_2d = DISABLED`) magnifies the exact grid cell under the finger for doorway stacking.
3. **Command Node Mode (tap existing waypoint):** Opens bottom-arc radial menu for one-thumb order assignment.

## 3. Tactical Audio Bus & Mix Architecture (`scripts/audio/tactical_audio.gd`)
Godot `AudioServer` bus layout:
- `Master` -> `BGM` (adaptive stealth-to-combat soundtrack), `Ambient` (room tone / exterior wind), `TacticalSFX` (gunfire, footsteps, breaches, flashbangs, drone buzz), `RadioComms` (UI blips, Go-Code callouts, radio squelch), `StressHeartbeat` (synthesized heartbeat loop).
- **Metal Gear Solid–Inspired Adaptive BGM:** Tempo-synced, layered espionage soundtrack on the `BGM` bus:
  - *Planning & Infiltration:* Moody analog synth basslines, sparse tactical pulses, and atmospheric espionage pads (evoking classic MGS sneaking/briefing themes).
  - *Caution / Investigation:* Adds muted rhythmic percussion and rising tension arpeggios when hostiles investigate disturbances.
  - *Alert / Firefight:* Plays a sharp alert sting on detection and crossfades (`350 ms`) into driving orchestral-synth action percussion and brass-like synth stabs during active combat, then fades back down on Evasion/Clear.
- **Dynamic Breach Ducking:** On `EventBus.breach_detonated` (or frag/flashbang detonation), duck `BGM` and `Ambient` buses by `-14 dB` with `15 ms` attack and `600 ms` release so explosions punch through the mix.
- **C4I UI Feedback:** Waypoint placement, Go-Code assignment, and Tap-In handoff play short randomized Codec-style radio squelch transients + subtle telemetry blips on `RadioComms` (ducking `BGM` by `-4 dB` during callouts).
- **Combat Stress Filter:** On `EventBus.operative_damaged`, ramp up `StressHeartbeat` volume and sweep an `AudioEffectLowPassFilter` on `BGM` + `Ambient` + `TacticalSFX` down to `850 Hz` (recovering smoothly over 3.5s) to communicate operative injury without forcing eyes off the firefight.
