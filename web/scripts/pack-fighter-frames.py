#!/usr/bin/env python3
"""Key chroma backgrounds and pack fighter frames onto a transparent sheet."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

CELL = 128
TARGET_H = 112
FEET_Y = 121


def is_chroma(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    if r >= 180 and b >= 180 and g <= 90:
        return True
    if r >= 200 and b >= 150 and g <= 110 and (r - g) >= 70 and (b - g) >= 50:
        return True
    return False


def key_image(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    pix = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            if is_chroma(r, g, b, a):
                pix[x, y] = (0, 0, 0, 0)
    return im


def bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    px = im.load()
    w, h = im.size
    xs: list[int] = []
    ys: list[int] = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 12:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def fit_cell(im: Image.Image) -> Image.Image:
    box = bbox(im)
    if box is None:
        return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    cw, ch = crop.size
    scale = TARGET_H / max(ch, 1)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    if nw > CELL - 8:
        scale = (CELL - 8) / cw
        nw = max(1, int(round(cw * scale)))
        nh = max(1, int(round(ch * scale)))
    resized = crop.resize((nw, nh), Image.Resampling.NEAREST)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    dx = (CELL - nw) // 2
    dy = FEET_Y - nh
    dy = max(2, min(CELL - nh - 2, dy))
    cell.paste(resized, (dx, dy), resized)
    return cell


def pack(frames: list[Path], dest_dir: Path, stem: str, cols: int, rows: int) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    cells: list[Image.Image] = []
    for i, src in enumerate(frames, start=1):
        keyed = fit_cell(key_image(Image.open(src)))
        out = dest_dir / f"{stem}-{i}.png"
        keyed.save(out, "PNG")
        cells.append(keyed)
    sheet = Image.new("RGBA", (CELL * cols, CELL * rows), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        col = i % cols
        row = i // cols
        sheet.paste(cell, (col * CELL, row * CELL), cell)
    sheet.save(dest_dir / "sheet-transparent.png", "PNG")
    meta = {
        "grid": f"{cols}x{rows}",
        "cell": CELL,
        "frames": len(cells),
        "stem": stem,
    }
    (dest_dir / "pipeline-meta.json").write_text(json.dumps(meta, indent=2) + "\n")


def crop_thumb(src: Path, dest: Path, cx: int, size: int) -> None:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    size = min(size, w, h)
    x0 = max(0, min(w - size, cx - size // 2))
    y0 = max(0, min(h - size, (h - size) // 2))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.crop((x0, y0, x0 + size, y0 + size)).resize((512, 512), Image.Resampling.LANCZOS).save(
        dest, "JPEG", quality=90
    )


if __name__ == "__main__":
    import shutil
    import tempfile

    root = Path(__file__).resolve().parents[2]
    art = Path("/opt/cursor/artifacts/assets")
    sprites = root / "assets/sprites"
    tmp = Path(tempfile.mkdtemp(prefix="jj-combat-"))
    for who, move in (("andrew", "attack"), ("andrew", "kick"), ("han", "attack"), ("han", "kick")):
        src = sprites / who / move / "sheet-transparent.png"
        shutil.copy2(src, tmp / f"{who}-{move}.png")

    pack(
        [
            art / "andrew-punch-1.png",
            art / "andrew-punch-2.png",
            tmp / "andrew-attack.png",
            art / "andrew-punch-4.png",
        ],
        sprites / "andrew/attack",
        "punch",
        2,
        2,
    )
    pack(
        [
            art / "andrew-kick-1.png",
            art / "andrew-kick-2.png",
            tmp / "andrew-kick.png",
            art / "andrew-kick-4.png",
        ],
        sprites / "andrew/kick",
        "kick",
        2,
        2,
    )
    pack(
        [
            art / "han-punch-1.png",
            art / "han-punch-2.png",
            tmp / "han-attack.png",
            art / "han-punch-4.png",
        ],
        sprites / "han/attack",
        "punch",
        2,
        2,
    )
    pack(
        [
            art / "han-kick-1.png",
            art / "han-kick-2.png",
            tmp / "han-kick.png",
            art / "han-kick-4.png",
        ],
        sprites / "han/kick",
        "kick",
        2,
        2,
    )

    thumbs = root / "assets/ui/thumbs"
    crop_thumb(root / "assets/ui/jj-frames/f001.jpg", thumbs / "jj.jpg", 640, 720)
    crop_thumb(root / "assets/ui/andrew-frames/f001.jpg", thumbs / "andrew.jpg", 700, 720)
    crop_thumb(root / "assets/ui/han-frames/f001.jpg", thumbs / "han.jpg", 680, 720)
    print("packed combat sheets and character thumbs")
