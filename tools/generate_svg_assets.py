# ============================================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================================
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "icons" / "svg"

CYAN = "#2DD4BF"
AMBER = "#F59E0B"
RED = "#EF4444"
BLUE = "#3B82F6"
GREEN = "#22C55E"
WHITE = "#E2E8F0"


def wrap(body: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">'
        + body
        + "</svg>\n"
    )


ICONS = {
    "gocode_alpha.svg": wrap(
        f'<polygon points="32,4 60,32 32,60 4,32" fill="#0B0F14" stroke="{AMBER}" stroke-width="3"/>'
        f'<text x="32" y="41" text-anchor="middle" font-family="monospace" font-size="28" font-weight="bold" fill="{AMBER}">A</text>'
    ),
    "gocode_bravo.svg": wrap(
        f'<polygon points="32,4 60,32 32,60 4,32" fill="#0B0F14" stroke="{GREEN}" stroke-width="3"/>'
        f'<text x="32" y="41" text-anchor="middle" font-family="monospace" font-size="28" font-weight="bold" fill="{GREEN}">B</text>'
    ),
    "gocode_charlie.svg": wrap(
        f'<polygon points="32,4 60,32 32,60 4,32" fill="#0B0F14" stroke="{CYAN}" stroke-width="3"/>'
        f'<text x="32" y="41" text-anchor="middle" font-family="monospace" font-size="28" font-weight="bold" fill="{CYAN}">C</text>'
    ),
    "gocode_delta.svg": wrap(
        f'<polygon points="32,4 60,32 32,60 4,32" fill="#0B0F14" stroke="{RED}" stroke-width="3"/>'
        f'<text x="32" y="41" text-anchor="middle" font-family="monospace" font-size="28" font-weight="bold" fill="{RED}">D</text>'
    ),
    "stance_blitz.svg": wrap(
        f'<polyline points="12,16 26,32 12,48" fill="none" stroke="{AMBER}" stroke-width="4" stroke-linecap="round"/>'
        f'<polyline points="26,16 40,32 26,48" fill="none" stroke="{AMBER}" stroke-width="4" stroke-linecap="round"/>'
        f'<polyline points="40,16 54,32 40,48" fill="none" stroke="{AMBER}" stroke-width="4" stroke-linecap="round"/>'
    ),
    "stance_normal.svg": wrap(
        f'<polyline points="18,16 32,32 18,48" fill="none" stroke="{CYAN}" stroke-width="4" stroke-linecap="round"/>'
        f'<polyline points="34,16 48,32 34,48" fill="none" stroke="{CYAN}" stroke-width="4" stroke-linecap="round"/>'
    ),
    "stance_cautious.svg": wrap(
        f'<polyline points="24,16 40,32 24,48" fill="none" stroke="{GREEN}" stroke-width="4" stroke-linecap="round"/>'
    ),
    "mode_engage.svg": wrap(
        f'<circle cx="32" cy="32" r="20" fill="none" stroke="{RED}" stroke-width="3"/>'
        f'<line x1="32" y1="6" x2="32" y2="58" stroke="{RED}" stroke-width="2.5"/>'
        f'<line x1="6" y1="32" x2="58" y2="32" stroke="{RED}" stroke-width="2.5"/>'
        f'<circle cx="32" cy="32" r="4" fill="{RED}"/>'
    ),
    "mode_advance.svg": wrap(
        f'<line x1="10" y1="32" x2="50" y2="32" stroke="{AMBER}" stroke-width="4"/>'
        f'<polyline points="36,18 52,32 36,46" fill="none" stroke="{AMBER}" stroke-width="4" stroke-linecap="round"/>'
    ),
    "mode_escort.svg": wrap(
        f'<path d="M32 6 L54 14 V32 C54 46 44 55 32 59 C20 55 10 46 10 32 V14 Z" fill="none" stroke="{BLUE}" stroke-width="3.5"/>'
        f'<circle cx="32" cy="26" r="6" fill="{BLUE}"/>'
        f'<path d="M22 44 C22 37 42 37 42 44" fill="none" stroke="{BLUE}" stroke-width="3.5"/>'
    ),
    "action_flashbang.svg": wrap(
        f'<rect x="24" y="16" width="16" height="36" rx="4" fill="none" stroke="{AMBER}" stroke-width="3"/>'
        f'<line x1="24" y1="26" x2="40" y2="26" stroke="{AMBER}" stroke-width="2.5"/>'
        f'<line x1="24" y1="42" x2="40" y2="42" stroke="{AMBER}" stroke-width="2.5"/>'
        f'<circle cx="44" cy="14" r="5" fill="none" stroke="{WHITE}" stroke-width="2.5"/>'
    ),
    "action_frag.svg": wrap(
        f'<ellipse cx="32" cy="36" rx="14" ry="18" fill="none" stroke="{RED}" stroke-width="3"/>'
        f'<rect x="27" y="12" width="10" height="6" fill="{RED}"/>'
        f'<line x1="18" y1="36" x2="46" y2="36" stroke="{RED}" stroke-width="2"/>'
        f'<line x1="32" y1="18" x2="32" y2="54" stroke="{RED}" stroke-width="2"/>'
    ),
    "action_breach_c4.svg": wrap(
        f'<rect x="14" y="20" width="36" height="28" rx="3" fill="none" stroke="{AMBER}" stroke-width="3"/>'
        f'<rect x="24" y="28" width="16" height="12" fill="{RED}"/>'
        f'<path d="M22 20 C22 10 42 10 42 20" fill="none" stroke="{CYAN}" stroke-width="2.5"/>'
    ),
    "action_fof_cone.svg": wrap(
        f'<circle cx="32" cy="32" r="22" fill="none" stroke="{CYAN}" stroke-width="2.5"/>'
        f'<path d="M32 32 L50 18 A23 23 0 0 1 50 46 Z" fill="{AMBER}" fill-opacity="0.45" stroke="{AMBER}" stroke-width="2"/>'
        f'<circle cx="32" cy="32" r="3.5" fill="{WHITE}"/>'
    ),
    "gear_heartbeat.svg": wrap(
        f'<rect x="16" y="10" width="32" height="44" rx="5" fill="none" stroke="{CYAN}" stroke-width="3"/>'
        f'<circle cx="32" cy="26" r="10" fill="none" stroke="{GREEN}" stroke-width="2"/>'
        f'<polyline points="20,44 26,44 29,38 33,48 36,44 44,44" fill="none" stroke="{GREEN}" stroke-width="2.5"/>'
    ),
    "gear_lockpick.svg": wrap(
        f'<rect x="18" y="28" width="28" height="24" rx="3" fill="none" stroke="{RED}" stroke-width="3"/>'
        f'<path d="M24 28 V18 A8 8 0 0 1 40 18 V22" fill="none" stroke="{WHITE}" stroke-width="3"/>'
        f'<circle cx="32" cy="40" r="3" fill="{RED}"/>'
    ),
    "unit_friendly.svg": wrap(
        f'<rect x="10" y="16" width="44" height="32" fill="#0B0F14" stroke="{BLUE}" stroke-width="3.5"/>'
        f'<line x1="10" y1="16" x2="54" y2="48" stroke="{BLUE}" stroke-width="2"/>'
        f'<line x1="54" y1="16" x2="10" y2="48" stroke="{BLUE}" stroke-width="2"/>'
    ),
    "unit_hostile.svg": wrap(
        f'<polygon points="32,8 56,32 32,56 8,32" fill="#0B0F14" stroke="{RED}" stroke-width="3.5"/>'
        f'<circle cx="32" cy="32" r="5" fill="{RED}"/>'
    ),
    "unit_hostile_lkp.svg": wrap(
        f'<polygon points="32,8 56,32 32,56 8,32" fill="none" stroke="{RED}" stroke-width="2.5" stroke-dasharray="5,4"/>'
        f'<text x="32" y="40" text-anchor="middle" font-family="monospace" font-size="24" font-weight="bold" fill="{RED}">?</text>'
    ),
    "unit_hostage.svg": wrap(
        f'<rect x="14" y="14" width="36" height="36" fill="#0B0F14" stroke="{GREEN}" stroke-width="3.5"/>'
        f'<text x="32" y="40" text-anchor="middle" font-family="monospace" font-size="20" font-weight="bold" fill="{GREEN}">H</text>'
    ),
    "drone_uav.svg": wrap(
        f'<circle cx="16" cy="16" r="8" fill="none" stroke="{CYAN}" stroke-width="2.5"/>'
        f'<circle cx="48" cy="16" r="8" fill="none" stroke="{CYAN}" stroke-width="2.5"/>'
        f'<circle cx="16" cy="48" r="8" fill="none" stroke="{CYAN}" stroke-width="2.5"/>'
        f'<circle cx="48" cy="48" r="8" fill="none" stroke="{CYAN}" stroke-width="2.5"/>'
        f'<line x1="22" y1="22" x2="42" y2="42" stroke="{WHITE}" stroke-width="3"/>'
        f'<line x1="42" y1="22" x2="22" y2="42" stroke="{WHITE}" stroke-width="3"/>'
        f'<circle cx="32" cy="32" r="5" fill="{AMBER}"/>'
    ),
    "vehicle_apc.svg": wrap(
        f'<rect x="8" y="20" width="48" height="24" rx="4" fill="#0B0F14" stroke="{CYAN}" stroke-width="3"/>'
        f'<circle cx="20" cy="46" r="5" fill="{WHITE}"/>'
        f'<circle cx="44" cy="46" r="5" fill="{WHITE}"/>'
        f'<rect x="26" y="14" width="12" height="6" fill="{AMBER}"/>'
    ),
}


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, content in ICONS.items():
        (OUT_DIR / name).write_text(content, encoding="utf-8")
    print(f"Generated {len(ICONS)} SVG icons in {OUT_DIR}")


if __name__ == "__main__":
    main()
