# Blueprint & Work Order: 5-ft Scale Full-Building 2.5D Engine, Interchangeable TilesetThemes & Tilt/Rotate Camera

> **Status:** Active Next-Gen Visual Engine Blueprint (shared 5 ft × 5 ft scale across `TacPlanShooter`, `Pathfinder God`, and `Sovereign Nodes`; `gl_compatibility` OpenGL ES 3.0, MSAA off, pure 60 Hz 2D `scripts/sim/` untouched).

## 1. Unified 5 ft × 5 ft Tactical Scale & Full-Building Maps
- **Canonical Grid Unit:** `1 grid cell = 5 ft × 5 ft` (standard doorway = 1 cell, hallway = 2 cells, room = 3×3 to 6×6 cells, full compound = `32×24` to `48×36` cells).
- **Full-Building Upgrade (`data/maps/op01_glass_house.json`):** Expand from small box to a `32×24` (160×120 ft) full tactical compound: exterior approach street/courtyard, entry vestibule, central corridor, side offices, security/server room, hostage suite, and 3+ synchronized breach entry points (`Alpha`/`Bravo`/`Charlie`/`Delta`).
- **Whisper-Subtle Non-White Gridlines:** Replace any white/bright gridlines with subtle dark etched grooves (`Color(0.06, 0.14, 0.20, 0.14)`) visible only during Planning and hidden completely during Execution.

## 2. Interchangeable High-Detail `TilesetTheme` Contract (`godot4-asset-vault`)
Every theme pack in `addons/godot4-asset-vault/themes/<theme_id>/` conforms to one standardized `TilesetTheme` resource contract so swapping themes is a single JSON field (`"tileset_theme": "tactical_compound"`):
- `floor_tiles` (4 seamless high-detail 64×64 or 128×128 variants + `_n.png` normal map)
- `wall_top_cap` + `wall_face_variants` (4 vertical extruded bulkhead/concrete/brick panels + `_n.png` normal map + AO base shadow)
- `doors` (`CLOSED_UNLOCKED`, `LOCKED`, `BARRICADED`, `OPEN`, `BREACHED`)
- `props_atlas` (crates, terminals, desks, server racks, cover barriers, vehicles)
- `ambient_palette` (`floor_tint`, `fog_color`, `light_color`, `grid_color`)
- Planned starter themes: `tactical_compound`, `industrial_warehouse`, `moonbase_lab`, `bank_vault`, and `ancestral_crypt` (for `Sovereign Nodes`).

## 3. HD-2D / 2.5D-in-3D World View (`Node3D` + `Camera3D` View Layer over Pure 2D `SimWorld`)
To support true camera height, pitch tilt, 90° auto-snap rotation, and razor-sharp clarity at eye-level zoom without touching deterministic 2D simulation:
- **Pure 2D Sim -> 3D View Projection:** `SimWorld` remains 100% 2D integer grid (`scripts/sim/` untouched). View layer maps `(cell_x, cell_y, floor)` -> `Vector3(cell_x * 1.5, floor * 3.2, cell_y * 1.5)`.
- **Batched Mobile-Safe 3D Geometry (`gl_compatibility`, `msaa_3d = 0`):**
  - `MultiMeshInstance3D` for all floor plates (1 draw call per floor) and `MultiMeshInstance3D` for extruded 3D wall blocks (1 draw call per floor) textured with crisp `StandardMaterial3D` (`TEXTURE_FILTER_NEAREST` for chunky pixel clarity or high-res crisp PBR + `_n.png` normal maps — zero blur at close zoom!).
  - **Dynamic Wall Cutaway Shader:** Walls standing between `Camera3D` and active operatives automatically clip/fade down to waist-high (`0.45 m`) so interiors stay 100% readable at every rotation angle.
  - **8-Directional `Sprite3D` Units & Props:** Operatives, hostiles, drones, and vehicles render as crisp Y-billboarded `Sprite3D`s (or low-poly meshes) that auto-select facing angle relative to camera yaw, with real ground shadows, muzzle-flash `OmniLight3D`, and smooth OrangePixel stride/recoil/dust-puff juice.
- **3-Tier Camera Rig (`scripts/view3d/tactical_camera_3d.gd`):**
  - **Pitch Tilt & Height:** Smoothly transitions from **88° Blueprint Top-Down** (fast N64 route drawing) -> **52° Tactical 2.5D** (*Space Grunts* / *XCOM* isometric-like angle) -> **20° Just-Above-Eye-Level Recon** (zoomed in low behind breaching teams, pan up to look down hallways, then pull back out).
  - **90° Auto-Snap Rotation:** Two-finger twist (or quick `↺ / ↻` HUD buttons) smoothly rotates yaw and spring-snaps to exact `0° / 90° / 180° / 270°` cardinal bearings.
  - **Edge-to-Edge Full Screen:** Extended exterior courtyard/street apron fills 100% of tall portrait displays (`720×1612` BLU B160V and `1080×2400` Moto G 2025) with zero black margins.

## 4. Phased Rollout
- **Step 1 (Immediate):** Upgrade `OP-01` to `32×24` 5-ft compound, remove white gridlines, add edge-to-edge exterior apron, and formalize `TilesetTheme` resource in `godot4-asset-vault`.
- **Step 2 (HD-2D View Prototype):** Build parallel `scripts/view3d/` (`world_view_3d.gd`, `tactical_camera_3d.gd`, `wall_cutaway.gdshader`) reading live `SimWorld` state so players can toggle between Classic Blueprint and 2.5D Tilt/Rotate 3D View with zero simulation rewrite.
