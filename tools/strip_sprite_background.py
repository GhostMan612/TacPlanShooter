#!/usr/bin/env python3
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\TacPlan Shooter\assets\sprites")
NAMES = ["op_pointman.png", "op_breacher.png", "op_heavy.png", "op_tech.png"]


def key_out(path: Path) -> int:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = [[False] * h for _ in range(w)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    cleared = 0
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[x][y]:
            continue
        seen[x][y] = True
        r, g, b, a = px[x, y]
        if max(r, g, b) >= 40 or b - r > 24:
            continue
        px[x, y] = (r, g, b, 0)
        cleared += 1
        q.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    img.save(path)
    return cleared


if __name__ == "__main__":
    for name in NAMES:
        p = ROOT / name
        if p.exists():
            print(f"{name}: cleared {key_out(p)} edge pixels")
