#!/usr/bin/env python3
"""Strip leftover magenta / dusty-rose chroma boxes from sprite sheets."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

CELL = 128
MIN_BOX_FRAC = 0.08
DIST = 38


def is_chroma_hue(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return False
    if r >= 200 and b >= 200 and g <= 90:
        return True
    return r >= 120 and b >= 70 and g <= 120 and (r - g) >= 40 and (b - g) >= 15


def dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def median_rgb(colors: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    rs = sorted(c[0] for c in colors)
    gs = sorted(c[1] for c in colors)
    bs = sorted(c[2] for c in colors)
    mid = len(colors) // 2
    return rs[mid], gs[mid], bs[mid]


def key_cell(pix, x0: int, y0: int, cw: int, ch: int) -> int:
    samples: list[tuple[int, int, int]] = []
    for y in range(y0, y0 + ch):
        for x in range(x0, x0 + cw):
            r, g, b, a = pix[x, y]
            if is_chroma_hue(r, g, b, a):
                samples.append((r, g, b))
    if len(samples) < MIN_BOX_FRAC * cw * ch:
        return 0
    key = median_rgb(samples)
    cleared = 0
    for y in range(y0, y0 + ch):
        for x in range(x0, x0 + cw):
            r, g, b, a = pix[x, y]
            if a < 8:
                continue
            if dist((r, g, b), key) <= DIST and is_chroma_hue(r, g, b, a):
                pix[x, y] = (0, 0, 0, 0)
                cleared += 1
    return cleared


FRINGE_SHEETS = {
    "enemies/biz/walk-sheet.png",
    "enemies/gothm/attack-sheet.png",
    "enemies/maga/attack-sheet.png",
}


def key_sheet(path: Path, sprites_root: Path) -> int:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    cols = max(1, w // CELL)
    rows = max(1, h // CELL)
    pix = im.load()
    cleared = 0
    for row in range(rows):
        for col in range(cols):
            cleared += key_cell(pix, col * CELL, row * CELL, CELL, CELL)
    rel = path.relative_to(sprites_root).as_posix()
    if rel in FRINGE_SHEETS:
        for y in range(h):
            for x in range(w):
                r, g, b, a = pix[x, y]
                if a < 8 or not is_chroma_hue(r, g, b, a):
                    continue
                edge = False
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        edge = True
                        break
                    if pix[nx, ny][3] < 8:
                        edge = True
                        break
                if edge:
                    pix[x, y] = (0, 0, 0, 0)
                    cleared += 1
    if cleared:
        im.save(path, "PNG")
    return cleared


def chroma_fraction(path: Path) -> float:
    im = Image.open(path).convert("RGBA")
    pix = im.getdata()
    n = max(1, len(pix))
    hits = sum(1 for r, g, b, a in pix if is_chroma_hue(r, g, b, a))
    return hits / n


def main() -> None:
    import sys

    root = Path(__file__).resolve().parents[2] / "assets" / "sprites"
    check = "--check" in sys.argv
    if check:
        bad: list[str] = []
        for path in sorted(root.rglob("*.png")):
            frac = chroma_fraction(path)
            if frac >= MIN_BOX_FRAC:
                bad.append(f"{path.relative_to(root.parents[1])}: {frac:.1%} leftover chroma")
        if bad:
            print("Leftover chroma-key boxes:")
            for line in bad:
                print(f"  - {line}")
            raise SystemExit(1)
        print("No leftover chroma-key boxes.")
        return

    total = 0
    for path in sorted(root.rglob("*.png")):
        n = key_sheet(path, root)
        if n:
            print(f"{path.relative_to(root.parents[1])}: cleared {n} chroma pixels")
            total += n
    print(f"done, {total} pixels keyed")


if __name__ == "__main__":
    main()
