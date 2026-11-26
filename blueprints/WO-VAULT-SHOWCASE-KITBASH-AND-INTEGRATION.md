# WORK ORDER: VAULT SHOWCASE, MODULAR KITBASHING & TACPLANSHOOTER INTEGRATION
Repos:
- Vault: `GhostMan612/godot4-asset-vault` (local vault repo)
- Game: `C:\TacPlan Shooter` (`GhostMan612/TacPlanShooter`, branch: `main`)
Governing Law: Follow `RULES.md` (full files only, zero comments except 4-line Genesis header in `.gd` files, typed GDScript everywhere, `gl_compatibility` OpenGL ES 3.0, `msaa_2d=0`, stage by explicit path only, keep all Headless CI gates green).

## TRACK 1 — Runnable Showcase Project & Godot 4 Plugin (`godot4-asset-vault`)
Make `GhostMan612/godot4-asset-vault` directly openable as a Godot 4 showcase gallery and reusable EditorPlugin:
- CREATE: `project.godot` (`config_version=5`, `gl_compatibility`, `msaa_2d=0`, `textures/canvas_textures/default_texture_filter=0` Nearest, `run/main_scene="res://showcase/vault_gallery.tscn"`).
- CREATE: `addons/godot4_asset_vault/plugin.cfg` + `addons/godot4_asset_vault/vault_dock_plugin.gd` (`@tool extends EditorPlugin`): adds a lightweight bottom dock scanning `tacplanshooter/` and `tacplanshooter_hd/` for `.tres` TileSets, `CanvasTexture`, `SpriteFrames`, and `.svg` icons with clickable thumbnails.
- CREATE: `showcase/vault_gallery.tscn`, `showcase/floors_and_walls.tscn`, `showcase/avatars_gallery.tscn`, `showcase/props_gallery.tscn`: live 16 px reference-grid contact sheets rendering every tile, 2.5D wall extrusion, normal-mapped `CanvasTexture` under a moving `PointLight2D`, and animated operator class so scale/seam/palette issues are immediately visible.

## TRACK 2 — Modular Kitbashing Operative Rig & Palette-Swap Shader (`godot4-asset-vault`)
Build a reusable layered operative rig (4 helmets × 4 vests × 4 squad colors = 64 variants from one atlas slice):
- CREATE: `tacplanshooter_hd/shaders/palette_swap.gdshader` (`shader_type canvas_item;`, `gl_compatibility`-safe): maps 4 key mask colors (`#FF00FF` primary squad accent, `#00FFFF` secondary trim, `#FFFF00` armor plate, `#00FF00` visor/optic) to uniform `Color` parameters (`squad_color`, `trim_color`, `armor_color`, `optic_color`) with zero branching overhead.
- CREATE: `tacplanshooter_hd/scenes/modular_operative.tscn` + `tacplanshooter_hd/scripts/modular_operative.gd`:
  - Layered `Sprite2D` stack: `BodyLayer` -> `VestLayer` -> `HelmetLayer` -> `WeaponLayer` -> `SquadRingLayer`, all sharing `CanvasTexture` (diffuse + `_n.png` normal map) and `palette_swap.gdshader`.
  - Exposes `configure(squad_id: int, role_id: StringName, armor_tier: StringName, weapon_id: StringName) -> void` for instant N64 `RED`/`BLUE`/`GREEN`/`GOLD` squad tinting and Kit loadout swaps.

## TRACK 3 — Submodule Link & HD 2.5D Integration (`TacPlanShooter`)
Link `godot4-asset-vault` into `TacPlanShooter` and wire the HD 2.5D pack cleanly with graceful fallbacks:
1. Link submodule in `C:\TacPlan Shooter`:
   - `git submodule add https://github.com/GhostMan612/godot4-asset-vault.git addons/godot4-asset-vault`
   - Update `.github/workflows/headless-ci.yml` checkout step to `submodules: recursive` so CI always pulls the vault cleanly.
2. Wire `tacplanshooter_hd/` into `TacPlanShooter` (keeping procedural `_draw()` fallback if any asset path is absent):
   - `scripts/planning/map_renderer.gd`: Support optional `TileMap` layer bound to `res://addons/godot4-asset-vault/tacplanshooter_hd/tilesets/spacegrunts_25d_tileset.tres` (2.5D extruded south walls + deterministic hashed floor variants + normal-mapped `CanvasTexture`), while preserving MGRS coordinates, zone overlays, and Dark/Light/NVG theme tinting.
   - `scripts/planning/operative_token.gd`: Instantiate `modular_operative.tscn` (or `pointman_breacher_anim_frames.tres` / `recon_shield_anim_frames.tres`) with `palette_swap.gdshader` for squad colors and animated walk/shoot states synced to `SimOperative` movement/fire ticks.
   - `scripts/ui/icon_registry.gd`: Register `addons/godot4-asset-vault/tacplanshooter/icons/` + existing `assets/icons/` SVGs.
   - `project.godot` / Android export icons: Point launcher icons to `tacplanshooter_hd/` adaptive/mipmap icons.

## VERIFICATION GATES
- Vault repo: `godot --headless --path . --quit` returns zero `ERROR|SCRIPT ERROR|Parse` across `showcase/*.tscn` and `modular_operative.tscn`.
- `TacPlanShooter`: `HYGIENE_COMMENTS=0`, `parse_all.tscn`, `scene_smoke.tscn`, `ui_polish_audit.gd`, `determinism_harness.gd`, and all GitHub Actions Headless CI gates pass green with `submodules: recursive`.
- On-device (`BLU B160V`, PowerVR Rogue GE8300): Confirm `gl_compatibility` + `msaa_2d=0` holds smooth 30/60 FPS with 2.5D tileset + `palette_swap.gdshader` + `FogLayer` active.
