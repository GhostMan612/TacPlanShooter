# Blueprint: Reusable `godot-asset-kit` Multi-Game Portfolio Architecture

> **Status:** Cross-Project Studio Blueprint (shared across `TacPlanShooter`, `Sovereign-Nodes`, and future Godot 4 titles).
> **Core Principle:** Treat Godot 4 assets as text-first, version-controlled studio equity (`.tscn`, `.tres`, `.gdshader`, `.svg`, Python/Blender `bpy` generators, Material Maker `.ptex` graphs) rather than disposable per-game binaries.

## 1. Shared Repository Layout (`GhostMan612/godot-asset-kit`)
```text
godot-asset-kit/
├── generators/
│   ├── svg_icons/          # Pure Python stdlib generators -> MIL-STD, CQB, RPG, & HUD SVGs
│   ├── blender_bpy/        # Headless Blender scripts -> 90° top-down & 35° isometric PNG sheets + glTF
│   └── material_maker/     # .ptex node graphs -> tileable concrete, metal, floor, & terrain textures
├── shaders/
│   ├── fog_mask.gdshader   # SubViewport live + 50% visited memory Fog of War (MSAA-off)
│   ├── nvg_scanline.gdshader
│   └── hit_flash_outline.gdshader
├── ui_kit/
│   ├── theme_manager.gd    # Hot-swappable Dark Tactical / Light Blueprint / Night-Ops StyleBoxFlat themes
│   └── screen_router.gd    # Splash -> Title -> Loading -> Game -> AAR flow
├── audio_cc0/              # Vetted Freesound CC0 SFX + procedural synth presets (zero licensing ambiguity)
├── ci_templates/
│   └── godot4_headless.yml # Shared class-cache + harness verification workflow
└── PROVENANCE.md           # Explicit CC0/MIT license log for every third-party base pack (Kenney, OpenGameArt, Freesound)
```

## 2. Four-Tier Asset Production Rules
1. **Tier 1 — Code, SVG & GLSL Shaders (Default for UI, Maps, Fog, VFX):** Zero pixel blur at any Android/Desktop DPI, tiny APK footprint, 100% git-diffable.
2. **Tier 2 — Procedural Generators (Material Maker + Headless Blender `bpy`):** Generate tileable floor/wall textures and consistent multi-angle orthographic/isometric unit sprites from one rigged base mesh—shared cleanly between top-down (`TacPlanShooter`) and isometric (`Sovereign-Nodes`) projects.
3. **Tier 3 — CC0 Modular Kits (Kenney / OpenGameArt / Freesound):** Use public-domain CC0 packs for fast prototyping, UI/controller prompts, and clean SFX bases; record every source in `PROVENANCE.md`.
4. **Tier 4 — Hero Art & Concept Sheets:** Keep painted operative portraits and splash/title backdrops isolated under `assets/hero/` with explicit provenance so commercial store releases (Google Play / Steam) stay audit-clean.

## 3. Mandatory Phase 0 Taste Gate (Per New Game)
Before building more than 3 gameplay systems on any new Godot 4 game, build and verify one single vertical-slice screen on target hardware proving:
- 1 unit/character sprite + 1 tiled/shaded floor + 1 lighting/fog shader + 1 themed HUD panel at target FPS (30/60) with `msaa_2d = 0`.
