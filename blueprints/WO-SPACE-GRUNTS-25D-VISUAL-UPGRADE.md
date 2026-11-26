# WORK ORDER: WO-SPACE-GRUNTS-25D-VISUAL-UPGRADE
Repo: C:\TacPlan Shooter (GhostMan612/TacPlanShooter, branch: main)
Governing Law: Read RULES.md first. Full files only. Zero comments except the 4-line Genesis header. Typed GDScript everywhere. `gl_compatibility`, `msaa_2d=0`, Nearest texture filter (`default_texture_filter=0`). Keep all Headless CI gates + `HYGIENE_COMMENTS=0` green.

## OBJECTIVE
Transform the on-device visual presentation (verified on BLU B160V + Moto G 2025) from flat debug squares + blotchy floor noise into a chunky, readable, full-screen **Space Grunts–style 2.5D top-down tactical game** paired with N64 Rainbow Six planning overlays.

## 1. Kill Blotchy Floor & Build Beveled Modular Floor Plates (`scripts/planning/map_renderer.gd`)
- REMOVE the blotchy `concrete_seamless_256.png` / `fog_noise_256.png` floor tiling immediately.
- Render crisp beveled tactical floor plates (`#18222E` / `#1D2836` base with 1px inner bevels, subtle grate/panel variants selected deterministically via `(x * 73856093 ^ y * 19349663) & 3`, and subtle yellow/dark hazard trim adjacent to door cells).
- Draw faint planning gridlines (`0.08` alpha) **strictly UNDER walls and props**, and hide gridlines + MGRS edge headers during `EXECUTION` so live combat looks like a pure 2.5D game world.

## 2. True Space Grunts 2.5D Extruded Walls, Doors & Cast Shadows (`scripts/planning/map_renderer.gd`)
- Draw every solid wall cell `(x, y)` in two distinct 2.5D layers:
  - **Wall Top Cap:** Deep slate `#0E151F` fill with crisp 2px bright rim bevel (`#4B5E75`) along exposed edges.
  - **South-Facing Vertical Wall Face:** Whenever cell `(x, y + 1)` is walkable, render a tall vertical bulkhead/brick front face (`#263344` with horizontal panel seams, subtle vents/pipes via cell hash, and dark baseboard) PLUS a crisp ground drop shadow (`Color(0, 0, 0, 0.42)`) cast onto the floor cell below.
- Draw 2.5D tactical doors (metallic frame, sliding/hinged door leaf, red/amber locked LED bar or green unlocked LED, debris/spark trim when breached) instead of flat colored squares.
- Replace solid debug zone squares with subtle translucent diagonal-striped floor decals (`IN`, `EX`, `OBJ`) integrated onto the floor layer.

## 3. Lived-In Room Props & Y-Sorting (`scripts/planning/prop_layer.gd`, `scripts/planning/planning_root.gd`)
- Create `scripts/planning/prop_layer.gd` (`y_sort_enabled = true`) that deterministically decorates non-corridor, non-spawn room interior cells with 2.5D tactical props (steel crates, glowing cyan computer terminals, desks, server racks, cover barrels) with soft ground shadows.
- Enable `y_sort_enabled = true` on the world entity container so operatives, hostiles, drones, and props sort cleanly in front of north walls and behind south wall caps.

## 4. Chunky 3/4-View Standing Pixel Operatives & Hostiles (`scripts/planning/operative_token.gd`, `tools/generate_25d_sprites.py`)
- Replace tiny dark dots with chunky, high-contrast **3/4-angle standing pixel-art soldiers** (Nearest-neighbor crisp): readable helmet + bright visor, tactical plate carrier, oversized weapon silhouette (MP5 / shotgun / shield / rifle), dark elliptical foot shadow, crisp squad-colored ground ring (`RED` `#EF4444`, `BLUE` `#3B82F6`, `GREEN` `#22C55E`, `GOLD` `#F59E0B`), and a subtle 2-frame step bob during movement.
- Hostiles render in distinct crimson/charcoal tactical gear with clear silhouette contrast; hostages wear high-vis blue/white markers.
- Add `tools/generate_25d_sprites.py` (stdlib Pillow or pure PNG/TGA generator, Sovereign DNA header) if needed to bake crisp `32×32` 3/4-view sprite sheets into `assets/sprites/25d/` and run editor import so `.import` files are committed cleanly.

## 5. Full-Screen Edge-to-Edge Camera & Sleek Translucent HUD (`mission_camera.gd`, `planning_root.gd`, `squad_hud.gd`)
- Eliminate giant empty black borders: world fills 100% of the screen edge-to-edge.
- **Planning Camera:** Auto-fits the entire 2.5D building horizontally with zero right-edge clipping (all columns visible on both 720×1612 BLU B160V and 1080×2400 Moto G 2025).
- **Execution / Tap-In Camera:** Smoothly zooms in (`2.2×–2.8×` Space Grunts arcade scale) following the active squad or tapped-in operative, with subtle muzzle-flash lighting glow and camera micro-shake on breaches/shots.
- **Sleek Translucent Edge HUD:** Compact translucent dark glass bars (`0.78` alpha) tucked cleanly to top/bottom edges; solid-header `RED SQUAD` / `BLUE SQUAD` cards with green/yellow/red health dots; clear `ALPHA`, `BRAVO`, `CHARLIE`, `DELTA` Go-Code buttons (replacing `W:A..W:D`) and a high-contrast `EXECUTE` CTA button.

## VERIFICATION & DEVICE QA
1. `HYGIENE_COMMENTS=0`, `parse_all.tscn`, `scene_smoke.tscn`, `ui_polish_audit.gd`, `determinism_harness.gd`, and all GitHub Actions Headless CI gates pass green.
2. Rebuild `builds\TacPlan-debug.apk`, reinstall on **BLU B160V** + **Moto G (2025)**, confirm `godot:E` is empty on both devices, and capture fresh screenshots of both **Planning** (full building fit, 2.5D extruded walls, clean floor plates, props) and **Execution** (zoomed-in Space Grunts view, chunky 3/4 soldiers, muzzle/breach VFX).
