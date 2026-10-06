#!/usr/bin/env python3
"""Export start-still references for image-to-video clip generation (Grok Imagine).

Each fighter / enemy idle frame 0 is upscaled (nearest) onto a flat #00FF00 1024x1024 plate,
facing right, feet near the bottom — the exact framing the clip should keep.

    python3 tools/export_refs.py            # -> assets/art-drops/video-refs/*.png
"""
import glob
import os

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XCASSETS = os.path.join(REPO, "JJNightBrawl", "Assets.xcassets")
OUT = os.path.join(REPO, "assets", "art-drops", "video-refs")

# imageset -> (cols, rows)
SOURCES = {
    "jj": ("jj_idle", 2, 2),
    "andrew": ("andrew_idle", 1, 1),
    "han": ("han_idle", 1, 1),
    "biz": ("en_biz_idle", 2, 2),
    "maga": ("en_maga_idle", 2, 2),
    "gothm": ("en_gothm_idle", 2, 2),
    "gothf": ("en_gothf_idle", 2, 2),
}
PLATE = 1024
GREEN = (0, 255, 0, 255)


def frame0(name, cols, rows):
    files = [p for p in glob.glob(os.path.join(XCASSETS, f"{name}.imageset", "*.png")) if " 2." not in p]
    if not files:
        return None
    im = Image.open(files[0]).convert("RGBA")
    fw, fh = im.width // cols, im.height // rows
    return im.crop((0, 0, fw, fh))


def main():
    os.makedirs(OUT, exist_ok=True)
    for who, (name, cols, rows) in SOURCES.items():
        cell = frame0(name, cols, rows)
        if cell is None:
            print("skip", who, "(missing", name + ")")
            continue
        box = cell.split()[3].point(lambda v: 255 if v >= 40 else 0).getbbox()
        if box is None:
            print("skip", who, "(empty)")
            continue
        body = cell.crop(box)
        # body ~ 72% of the plate height, nearest-neighbour so the pixel art stays crisp
        scale = int(max(1, round(PLATE * 0.72 / body.height)))
        big = body.resize((body.width * scale, body.height * scale), Image.NEAREST)
        plate = Image.new("RGBA", (PLATE, PLATE), GREEN)
        x = (PLATE - big.width) // 2
        y = int(PLATE * 0.90) - big.height
        plate.alpha_composite(big, (x, max(0, y)))
        path = os.path.join(OUT, f"{who}_idle_ref.png")
        plate.convert("RGB").save(path)
        print("wrote", os.path.relpath(path, REPO), f"(x{scale})")


if __name__ == "__main__":
    main()
