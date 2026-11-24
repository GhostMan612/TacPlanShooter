# Blueprint: Full UI/UX Polish — Themes, Screens, Icons, SFX/BGM & VFX

> **Status:** Active Phase I Master Polish Blueprint (Portrait `1080×1920`, `gl_compatibility`, MSAA off, unified UI texture atlas per `RULES.md` §4).

## 1. Theme System (`scripts/ui/theme_manager.gd`)
Runtime-switchable Godot `Theme` presets persisted in `user://settings.json` (accessible from Main Menu Settings and in-mission Pause menu):
- **Dark Tactical (Default):** Deep slate `#0B0F14` canvas, cyan blueprint grid `#2DD4BF`, amber alerts `#F59E0B`, crimson hostiles `#EF4444`, crisp monospace/geometric HUD typography.
- **Light Blueprint:** High-contrast architectural daylight `#F4F6F8` paper, navy ink `#0F172A`, blueprint cobalt `#1D4ED8`, high-visibility outdoor readability.
- **Night-Ops / NVG:** Phosphor green `#22C55E` on `#050A06` OLED black for low-light battery savings.
- Accessible scaling toggle (`Standard` / `Large Touch Targets` >= 72×72 px minimum hitboxes).

## 2. Full Screen & Navigation Flow (`scripts/ui/screen_router.gd`)
1. **Splash Screen (`scenes/splash.tscn`):** Clean 1.8s animated studio/title emblem with subtle blueprint grid reveal, tap-to-skip, pre-warms `ThemeManager` & `TacticalAudio`.
2. **Title Screen (`scenes/title.tscn`):** Animated top-down blueprint backdrop (live sweeping radar/LOS polygon), game title + version badge, and clear primary actions:
   - `Campaign` (OP-01 to OP-10 progression map)
   - `Quick Operation` (instant vertical-slice launch)
   - `2-Player (Co-op / PvP)` (LAN Host / Join lobby + mode selector)
   - `HQ & Armory` (Roster roles, weapons, gear, armor, drones, vehicles)
   - `Settings` (Theme Light/Dark/NVG, Audio sliders: Master/BGM/SFX/Radio, Touch/Haptics, FPS cap info)
   - `Credits`
3. **Async Loading Screen (`scenes/loading.tscn`):** Threaded scene/map loader (`ResourceLoader.load_threaded_request`) with blueprint scanline progress bar, mission codename header, and rotating CQB tactical tips.
4. **7-Stage Mission Prep UI (`scripts/ui/mission_prep_flow.gd`):** Full interactive `Control` panels (replacing the enum stub) for `Briefing`, `Intel`, `Roster`, `Kit`, `Team`, and `Planning` with top step-breadcrumb bar and Back/Next buttons.
5. **In-Mission Execution & Pause Overlay:** Screen-space `CanvasLayer` with Squad Status cards, `Alpha`/`Bravo`/`Charlie`/`Delta` Go-Codes, Tap-In CP/Cooldown ring, Pause/Abort/Theme-toggle modal, and Tap-In dual-thumb overlay.
6. **After-Action Report (`scenes/aar.tscn`):** Animated mission grade (`S`/`A`/`B`/`C`/`F`), RP/XP breakdown, KIA/Wounded roster summary, `Replay` (deterministic replay playback), `Retry`, and `Next Operation`.

## 3. Tactical Iconography & Atlas (`assets/icons/`, `scripts/ui/icon_registry.gd`)
Crisp vector/SVG icons packed into a unified atlas (zero per-icon draw-call bloat):
- Stances (`Blitz`, `Normal`, `Cautious`), ROE Modes (`Engage`, `Advance`, `Escort`), Go-Codes (`Alpha`, `Bravo`, `Charlie`, `Delta`), Actions (`Flashbang`, `Frag`, `Tear Gas`, `Breach`, `Lockpick`, `Field of Fire`), CQB Roles (7 billet badges), Equipment/Armor/Drone/Vehicle silhouettes, Objective markers (`Hostage`, `Bomb`, `Intel`, `HVT`, `Extract`), and Audio/Theme/Settings glyphs.

## 4. Real Audio Implementation (`scripts/audio/tactical_audio.gd` + `scripts/audio/adaptive_bgm.gd`)
Move audio logic out of `scripts/sim/` into `scripts/audio/` so `scripts/sim/` remains 100% pure simulation:
- **Real `AudioServer` Bus Graph:** `Master` -> `BGM`, `Ambient`, `TacticalSFX`, `RadioComms`, `StressHeartbeat`.
- **SFX (Procedural `AudioStreamGenerator` fallback + `.ogg`/`.wav` asset hooks):** UI hover/tap clicks, Codec radio squelch, waypoint telemetry blips, Go-Code confirmation chimes, suppressed/unsuppressed gunfire, breach explosions, flashbang ringing, door lockpick/ram, drone rotor hum, and Tap-In radio handoff.
- **MGS-Inspired Adaptive `BGM` (`adaptive_bgm.gd`):** Seamless layered/crossfaded music states driven by `EventBus` & AI alert level:
  - `PLANNING_STEALTH`: Moody analog synth bass + minimalist espionage pad.
  - `CAUTION_INVESTIGATE`: Rhythmic tension arpeggio + muted percussion pulse.
  - `COMBAT_ALERT`: Sharp alert sting -> driving orchestral-synth action layer.
  - `AAR_VICTORY` / `AAR_DEFEAT`: Clean debrief resolution stinger.
- **Dynamic Mix Effects:** Breach/blast ducks `Ambient` + `BGM` (`-12 dB`, 15 ms attack, 600 ms release); operative damage ramps `StressHeartbeat` + sweeps `AudioEffectLowPassFilter` (`850 Hz`).

## 5. Tactical VFX Layer (`scripts/vfx/tactical_vfx.gd`)
Mobile-safe, MSAA-off batched visual effects synced to `EventBus` & `SimWorld` journal events:
- Muzzle flashes & directional bullet tracers (short additive lines).
- Breach/frag shockwave rings, spark bursts, and subtle camera micro-shake (toggleable in Settings).
- Flashbang radial white-bloom + stunned overhead ring on affected units.
- Tear gas / smoke translucent expanding clouds.
- Expanding acoustic rings for unsuppressed fire / `Blitz` sprints and pulsing green Heartbeat Sensor radar pings.
- Hit sparks, wounded/KIA tactical markers, and subtle blueprint grid scanlines on UI screens.
