#!/usr/bin/env python3
# Pack 128x128 JJ kick frames into Xcode sheets.
# Expects cells under frames/{snap,roundhouse,jump,sweep,axe,side,drop,back}/
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image

CELL = 128
ROOT = Path(__file__).resolve().parent

# Primary engine sheet uses the four existing production cells only.
PRIMARY = [
    ROOT / "frames-v1" / "jj_kick_front_00.png",
    ROOT / "frames-v1" / "jj_kick_front_01.png",
    ROOT / "frames-v1" / "jj_kick_front_02.png",
    ROOT / "frames-v1" / "jj_kick_front_03.png",
]

VARIANTS = {
    "roundhouse": {"cols": 4, "rows": 2, "xcasset": "jj_kick_roundhouse"},
    "jump":       {"cols": 4, "rows": 2, "xcasset": "jj_kick_jump"},
    "sweep":      {"cols": 3, "rows": 2, "xcasset": "jj_kick_sweep"},
    "axe":        {"cols": 3, "rows": 2, "xcasset": "jj_kick_axe"},
    "side":       {"cols": 3, "rows": 2, "xcasset": "jj_kick_side"},
    "drop":       {"cols": 2, "rows": 1, "xcasset": "jj_kick_drop"},
    "back":       {"cols": 2, "rows": 1, "xcasset": "jj_kick_back"},
}

def load_cell(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    if im.size == (CELL, CELL):
        return im
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    # fit inside cell, keep aspect, feet-biased
    scale = min(CELL / im.size[0], CELL / im.size[1])
    nw, nh = max(1, int(im.size[0] * scale)), max(1, int(im.size[1] * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (CELL - nw) // 2
    y = CELL - nh - 6
    canvas.paste(im, (x, max(0, y)), im)
    return canvas

def pack(frames, cols, rows):
    sheet = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        if i >= cols * rows:
            break
        col, row = i % cols, i // cols
        sheet.paste(fr, (col * CELL, row * CELL), fr)
    return sheet

def main():
    # primary 2x2
    frames = [load_cell(p) for p in PRIMARY if p.exists()]
    if len(frames) == 4:
        sheet = pack(frames, 2, 2)
        out = ROOT / "jj_kick.imageset" / "img.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(out, "PNG")
        (ROOT / "variant-sheets").mkdir(exist_ok=True)
        sheet.save(ROOT / "variant-sheets" / "jj_kick_snap_2x2.png", "PNG")
        print("[ok] primary 2x2", out, sheet.size)
    else:
        print("[skip] primary, found", len(frames))

    for kind, spec in VARIANTS.items():
        folder = ROOT / "frames" / kind
        if not folder.exists():
            print("[skip]", kind)
            continue
        paths = sorted(p for p in folder.glob("*.png"))
        if not paths:
            print("[skip]", kind)
            continue
        frames = [load_cell(p) for p in paths]
        sheet = pack(frames, spec["cols"], spec["rows"])
        out = ROOT / "variant-sheets" / ("%s.png" % spec["xcasset"])
        sheet.save(out, "PNG")
        print("[ok]", out, sheet.size, "frames=", len(frames))

if __name__ == "__main__":
    main()
