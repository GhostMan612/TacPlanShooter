#!/usr/bin/env python3
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
from pathlib import Path

from PIL import Image

OUT = Path(r"C:\TacPlan Shooter\assets\sprites\glow")
OUT.mkdir(parents=True, exist_ok=True)

GLOWS = {
    "glow_amber": (255, 170, 60),
    "glow_white": (255, 245, 220),
    "glow_cyan": (90, 220, 255),
    "glow_red": (255, 90, 60),
}


def radial(name: str, rgb: tuple, size: int = 64) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        for yd in (y - c,):
            for x in range(size):
                d = ((x - c) ** 2 + yd ** 2) ** 0.5 / c
                a = max(0.0, 1.0 - d)
                a = a * a * a
                px[x, y] = (*rgb, int(255 * a))
    img.save(OUT / (name + ".png"))
    imp = f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\nuid="uid://glow{name}"\npath="res://.godot/imported/{name}.png.ctex"\nmetadata={{\n"vram_texture": false\n}}\n\n[deps]\n\n'
    Path(str(OUT / (name + ".png")) + ".import").write_text(imp, encoding="utf-8")
    print(name, img.size)


if __name__ == "__main__":
    for name, rgb in GLOWS.items():
        radial(name, rgb)
