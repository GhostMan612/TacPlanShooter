#!/usr/bin/env python3
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
import json
from pathlib import Path

ROOT = Path(r"C:\TacPlan Shooter\data\maps")
THEMES = {
    2: "industrial_warehouse", 3: "industrial_warehouse", 4: "bank_vault",
    5: "tactical_compound", 6: "moonbase_lab", 7: "tactical_compound",
    8: "bank_vault", 9: "moonbase_lab", 10: "ancestral_crypt",
}
NAMES = {i: None for i in range(2, 11)}


def build(n: int) -> dict:
    old = json.loads((ROOT / [p.name for p in ROOT.glob(f"op{n:02d}_*.json")][0]).read_text(encoding="utf-8"))
    w = 40 if n in (7, 9, 10) else 32
    h = 28 if n in (7, 9, 10) else 24
    floors = int(old.get("floors", 1))
    walls = []
    doors = []
    mat = "CONCRETE" if n % 2 == 0 else "DRY_WALL"
    for f in range(floors):
        walls += [
            {"floor": f, "a": [0, 0], "b": [w, 0], "material": "CONCRETE"},
            {"floor": f, "a": [0, h - 1], "b": [w, h - 1], "material": "CONCRETE"},
            {"floor": f, "a": [0, 0], "b": [0, h], "material": "CONCRETE"},
            {"floor": f, "a": [w - 1, 0], "b": [w - 1, h], "material": "CONCRETE"},
        ]
        for x in (8, 16, 24):
            for y0, y1 in ((1, 7), (9, 15), (17, 23)):
                if y1 < h - 1:
                    walls.append({"floor": f, "a": [x, y0], "b": [x, y1], "material": mat})
        for y in (8, 16):
            for x0, x1 in ((1, 7), (9, 15), (17, 23), (25, w - 2)):
                if x1 > x0:
                    walls.append({"floor": f, "a": [x0, y], "b": [x1, y], "material": mat})
        dpts = [(8, 4), (16, 12), (24, 4), (8, 12), (16, 4), (24, 12), (4, 8), (12, 16), (20, 8), (28, 16)]
        for idx, (dx, dy) in enumerate(dpts):
            if dx < w and dy < h:
                doors.append({"id": f"d{n}_{idx:02d}", "floor": f, "cell": [dx, dy], "orientation": "H", "state": "OPEN"})
    if n == 3:
        doors.append({"id": "d03_locked", "floor": 0, "cell": [2, 2], "orientation": "H", "state": "LOCKED"})
        doors.append({"id": "d03_closed", "floor": 0, "cell": [10, 8], "orientation": "H", "state": "CLOSED_UNLOCKED"})
    ox, oy = 2, 2
    ex, ey = w - 4, h - 4
    objective = {"kind": "HOSTAGE_RESCUE" if n % 3 else "INTEL_GRAB", "floor": 0, "cell": [w - 7, h - 6], "timer_ticks": 0}
    return {
        "map_id": old["map_id"], "title": old["title"], "tileset_theme": THEMES[n],
        "floors": floors, "width_cells": w, "height_cells": h,
        "lighting": old.get("lighting", "DAY"), "rp_reward": old.get("rp_reward", 150),
        "walls": walls, "doors": doors,
        "stair_links": [{"from_floor": f, "from_cell": [6, 6], "to_floor": f + 1, "to_cell": [6, 6]} for f in range(floors - 1)],
        "insertion_zones": [{"id": f"ins{n}", "floor": 0, "vehicle_req": "VAN" if n >= 7 else "NONE", "cells": [[ox, oy], [ox + 1, oy], [ox, oy + 1], [ox + 1, oy + 1]]}],
        "extraction_zones": [{"id": f"ext{n}", "floor": 0, "cells": [[ex, ey], [ex + 1, ey]]}],
        "defender_zones": [{"id": f"def{n}_a", "floor": 0, "cells": [[12, 11], [13, 11], [14, 11]]}, {"id": f"def{n}_b", "floor": 0, "cells": [[20, 19], [21, 19], [22, 19]]}],
        "chokepoints": [{"floor": 0, "cell": [d["cell"][0], d["cell"][1]]} for d in doors[:4]],
        "objectives": [objective, {"kind": "INTEL_GRAB", "floor": 0, "cell": [w - 12, h - 10], "timer_ticks": 0}],
        "ai_spawns": [
            {"id": f"ai{n}_s1", "archetype": "hostage_guard", "floor": 0, "cell": [w - 6, h - 7], "facing_deg": 90, "patrol": []},
            {"id": f"ai{n}_s2", "archetype": "patrol_sentry", "floor": 0, "cell": [12, 18], "facing_deg": 0, "patrol": []},
        ],
        "hostage_spawns": [{"id": f"host{n}_1", "floor": 0, "cell": [w - 7, h - 6]}],
        "jammer_nodes": [{"id": f"jam{n}_1", "floor": 0, "cell": [18, 20]}],
    }


if __name__ == "__main__":
    for n in range(2, 11):
        matches = list(ROOT.glob(f"op{n:02d}_*.json"))
        if not matches:
            continue
        matches[0].write_text(json.dumps(build(n), indent=2) + "\n", encoding="utf-8")
        print(f"op{n:02d}: {matches[0].name} upgraded")
