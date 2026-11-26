#!/usr/bin/env python3
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(r"C:\TacPlan Shooter\assets\sprites\8dir")
OUT.mkdir(parents=True, exist_ok=True)


def sprite(angles: int, body: tuple, vest: tuple, visor: tuple, weapon: tuple, shield: bool = False, highvis: bool = False) -> Image.Image:
    sheet = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
    for f in range(8):
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse((9, 27, 23, 31), fill=(0, 0, 0, 110))
        facing_right = f in (0, 1, 7)
        facing_left = f in (4, 5, 3)
        d.rounded_rectangle((10, 6, 21, 24), radius=3, fill=body)
        d.rounded_rectangle((11, 12, 20, 21), radius=2, fill=vest)
        d.ellipse((11, 4, 21, 12), fill=body)
        d.rectangle((12, 7, 20, 9), fill=visor)
        if highvis:
            d.rectangle((10, 6, 21, 7), fill=(255, 245, 80, 255))
        wx = 23 if facing_right else 3
        d.line((wx, 15, wx + (4 if facing_right else -4), 9), fill=weapon, width=3)
        if shield:
            sx = 25 if facing_right else 3
            d.rectangle((sx, 8, sx + 4, 26), fill=(70, 105, 130, 255))
        if not facing_right and not facing_left:
            d.line((16, 15, 16, 8), fill=weapon, width=3)
        sheet.paste(im, (f * 32, 0), im)
    return sheet


SPECS = {
    "op_pointman_8dir": ((46, 52, 58, 255), (32, 40, 48, 255), (80, 230, 255, 255), (24, 28, 32, 255), False, False),
    "op_breacher_8dir": ((58, 48, 44, 255), (40, 32, 30, 255), (120, 200, 255, 255), (22, 24, 28, 255), False, False),
    "op_shield_8dir": ((44, 52, 60, 255), (30, 38, 46, 255), (70, 220, 255, 255), (20, 24, 30, 255), True, False),
    "op_tech_8dir": ((42, 50, 58, 255), (28, 36, 44, 255), (100, 240, 220, 255), (24, 28, 34, 255), False, False),
    "hostile_sentry_8dir": ((90, 28, 30, 255), (36, 28, 30, 255), (255, 120, 90, 255), (24, 22, 24, 255), False, False),
    "hostage_8dir": ((90, 160, 220, 255), (75, 130, 180, 255), (240, 245, 255, 255), (200, 200, 200, 255), False, True),
}


if __name__ == "__main__":
    for name, spec in SPECS.items():
        img = sprite(*spec)
        path = OUT / (name + ".png")
        img.save(path)
        print(f"{path.name}: {img.size}, alpha_extrema={img.getchannel('A').getextrema()}")
