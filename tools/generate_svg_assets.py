#!/usr/bin/env python3
"""Generate tactical SVG icon assets into assets/icons/ (flat SVG, MIL-STD-flavored glyphs).

Run: python tools/generate_svg_assets.py
"""

import os

DARK = "#000000"
ACCENT = "#2DD4BF"


def glyph(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">{body}</svg>'


def ring(r: float, stroke_width: float, accent: bool = True) -> str:
    fill = ACCENT if accent else "#8A8A8A"
    return f'<circle cx="32" cy="32" r="{r}" fill="none" stroke="{fill}" stroke-width="{stroke_width}"/>'


def horizon(y: int, stroke_width: int = 4) -> str:
    return f'<line x1="6" y1="{y}" x2="58" y2="{y}" stroke="{ACCENT}" stroke-width="{stroke_width}" stroke-linecap="round"/>'


ICONS: dict = {
    "stance_blitz": horizon(20) + horizon(46) + '<circle cx="32" cy="13" r="5" fill="none" stroke="' + ACCENT + '" stroke-width="4"/>',
    "stance_normal": horizon(16) + horizon(32) + horizon(48),
    "stance_cautious": horizon(12) + horizon(26) + horizon(40) + horizon(54),
    "roe_engage": ring(18, 4) + horizon(22) + horizon(42, 2),
    "roe_advance": ring(18, 4) + horizon(20, 2) + horizon(42, 2),
    "roe_escort": ring(18, 4) + horizon(22) + horizon(40),
    "code_alpha": '<rect x="8" y="8" width="20" height="20" fill="none" stroke="' + ACCENT + '" stroke-width="3"/><path d="M40 20 L58 8 L58 30 L40 18 Z" fill="' + ACCENT + '"/><rect x="28" y="28" width="28" height="24" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "code_bravo": ring(24, 4, False) + '<circle cx="32" cy="32" r="12" fill="' + ACCENT + '"/>',
    "code_charlie": ring(24, 4) + horizon(30),
    "code_delta": ring(24, 4) + horizon(26) + horizon(38),
    "action_flashbang": '<circle cx="32" cy="32" r="22" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + ring(12, 4, False),
    "action_frag": ring(12, 4, False) + '<path d="M32 10 L32 24 M32 40 L32 54" stroke="' + ACCENT + '" stroke-width="4"/><rect x="12" y="30" width="8" height="4" fill="' + ACCENT + '"/>',
    "action_tear_gas": '<circle cx="32" cy="28" r="10" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<line x1="16" y1="40" x2="48" y2="46" stroke="' + ACCENT + '" stroke-width="4" stroke-linecap="round"/>',
    "action_breach": ring(16, 4, False) + '<rect x="24" y="8" width="16" height="48" fill="none" stroke="' + ACCENT + '" stroke-width="4"/>',
    "action_lockpick": '<line x1="20" y1="20" x2="44" y2="44" stroke="' + ACCENT + '" stroke-width="5"/>' + '<circle cx="32" cy="32" r="14" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "action_fof": ring(22, 3) + ring(30, 3, False) + '<polygon points="10,32 10,44 22,44 22,38" fill="' + ACCENT + '"/>',
    "role_squad_leader": '<rect x="10" y="20" width="44" height="24" fill="none" stroke="' + ACCENT + '" stroke-width="3"/><circle cx="16" cy="14" r="3" fill="' + ACCENT + '"/>',
    "role_pointman": '<circle cx="32" cy="22" r="8" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + horizon(40, 3),
    "role_breacher": '<rect x="12" y="26" width="40" height="22" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<path d="M20 26 L28 14 L32 18 L36 10 L40 18 L40 26 Z" fill="' + ACCENT + '"/>',
    "role_shield": '<rect x="10" y="18" width="44" height="28" rx="6" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "role_tech_drone_operator": '<path d="M20 20 L24 16 L32 28 L26 32 Z" fill="none" stroke="' + ACCENT + '" stroke-width="3"/><circle cx="26" cy="20" r="4" fill="none" stroke="' + ACCENT + '" stroke-width="2"/>',
    "role_marksman_overwatch": ring(20, 3) + '<path d="M24 18 L40 10 L32 30 L26 22 Z" fill="' + ACCENT + '"/>',
    "role_medic_rescue": '<circle cx="32" cy="14" r="6" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<path d="M16 32 L48 32 L48 48 L16 48 Z" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "equipment_mag_p": '<rect x="10" y="16" width="24" height="28" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<rect x="10" y="44" width="24" height="14" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "equipment_mag_s": '<rect x="20" y="14" width="16" height="18" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "equipment_frag": ring(14, 3, False) + '<path d="M32 10 L32 24 L36 24 L36 34 L32 34" fill="' + ACCENT + '"/>',
    "equipment_flashbang": ring(20, 3) + '<circle cx="32" cy="32" r="8" fill="' + ACCENT + '"/>',
    "equipment_heartbeat": ring(20, 2, False) + ring(26, 2) + '<circle cx="32" cy="32" r="4" fill="' + ACCENT + '"/>',
    "equipment_lockpick": '<path d="M10 32 L22 20 L40 40 L54 30" stroke="' + ACCENT + '" stroke-width="4"/>',
    "equipment_electronics": '<path d="M12 12 L16 20 L14 30 L24 34 L22 44" stroke="' + ACCENT + '" stroke-width="4"/>',
    "equipment_demolitions": '<rect x="12" y="14" width="40" height="8" fill="' + ACCENT + '"/>' + ring(8, 3, False) + ring(16, 3, False),
    "item_drone_ground": '<rect x="12" y="10" width="40" height="8" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<rect x="18" y="18" width="28" height="8" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "item_drone_uav": '<circle cx="32" cy="16" r="5" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<line x1="32" y1="21" x2="32" y2="40" stroke="' + ACCENT + '" stroke-width="3"/>',
    "item_vehicle_van": '<rect x="8" y="22" width="48" height="22" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>' + '<path d="M12 38 L20 34 L40 34 L48 38" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "item_vehicle_apc": '<rect x="10" y="12" width="44" height="32" rx="4" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "objective_hostage": '<circle cx="32" cy="14" r="7" fill="none" stroke="' + ACCENT + '" stroke-width="3"/><path d="M32 30 L32 42 M20 42 L44 42" stroke="' + ACCENT + '" stroke-width="3"/>',
    "objective_bomb": ring(16, 3) + '<path d="M20 26 L24 30 L26 26 L28 30 L32 26" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "objective_intel": ring(16, 3) + '<rect x="22" y="24" width="20" height="16" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "objective_hvt": ring(20, 3) + '<circle cx="32" cy="32" r="8" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "objective_extract": ring(16, 3, False) + '<line x1="12" y1="32" x2="52" y2="32" stroke="' + ACCENT + '" stroke-width="3" stroke-dasharray="4 4"/>' + '<path d="M30 42 L32 38 L34 42 L36 38 L38 42" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
    "settings_glyph": ring(16, 3, False) + ring(8, 3) + '<rect x="24" y="24" width="20" height="20" rx="2" fill="none" stroke="' + ACCENT + '" stroke-width="3"/>',
}


def main() -> None:
    os.makedirs("assets/icons", exist_ok=True)
    for name, body in ICONS.items():
        with open(os.path.join("assets", "icons", f"{name}.svg"), "w", encoding="utf-8") as f:
            f.write(glyph(body) + "\n")
    print(f"Generated {len(ICONS)} icons into assets/icons/")


if __name__ == "__main__":
    main()
