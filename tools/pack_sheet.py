#!/usr/bin/env python3
"""Key, normalise and pack extracted clip frames into a JJ Night Brawl sprite sheet.

    python3 tools/pack_sheet.py <frames-dir> --name jj_punch1 --fighter jj --move punch1 \
        [--frames 8] [--cols 4] [--cell 128] [--cell-w 128] [--target-h 108] [--baseline 119] \
        [--anchor first|median] [--trim-start 0] [--trim-end 0] [--preview /tmp/preview.png]

* frames-dir holds frame_###.png from tools/clip2sheet.swift (flat #00FF00 background).
* Picks `--frames` frames spread across the clip by motion (bbox change) so the strike and
  recovery both survive, not just evenly spaced stills.
* Every frame gets ONE scale (from the anchor frame's body height -> --target-h) and is pinned
  to a fixed baseline / centre, so the body never slides between cells.
* Writes JJNightBrawl/Assets.xcassets/<name>.imageset/{img.png,Contents.json} and
  assets/sprites/<fighter>/<move>/{sheet-transparent.png,pipeline-meta.json}.
"""
import argparse
import json
import math
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XCASSETS = os.path.join(REPO, "JJNightBrawl", "Assets.xcassets")
SPRITES = os.path.join(REPO, "assets", "sprites")


def key_green(im):
    """Chroma-key flat #00FF00 with edge despill. Returns RGBA."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = g - max(r, b)
            if d > 80:
                px[x, y] = (0, 0, 0, 0)
            elif d > 28:
                t = (d - 28) / 52.0
                px[x, y] = (r, max(r, b), b, int(a * (1 - t)))
            elif g > r + 12 and g > b + 12 and r < 120:
                px[x, y] = (r, max(r, b), b, a)
    return im


def bbox(im, thresh=40):
    a = im.split()[3].point(lambda v: 255 if v >= thresh else 0)
    return a.getbbox()


def pick_frames(boxes, n):
    """Spread n picks over the clip, weighted toward frames whose bbox moves the most."""
    total = len(boxes)
    if n >= total:
        return list(range(total))
    motion = [0.0]
    for i in range(1, total):
        a, b = boxes[i - 1], boxes[i]
        if a is None or b is None:
            motion.append(0.0)
            continue
        motion.append(sum(abs(a[k] - b[k]) for k in range(4)))
    # cumulative "motion time" with a floor so still stretches still get coverage
    floor = max(1.0, (sum(motion) / total) * 0.35)
    cum = [0.0]
    for m in motion[1:]:
        cum.append(cum[-1] + max(m, floor))
    picks = []
    for k in range(n):
        target = cum[-1] * k / (n - 1) if n > 1 else 0
        j = min(range(total), key=lambda idx: abs(cum[idx] - target))
        if j not in picks:
            picks.append(j)
    # top up if collisions dropped some
    for j in range(total):
        if len(picks) >= n:
            break
        if j not in picks:
            picks.append(j)
    return sorted(picks[:n])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frames_dir")
    ap.add_argument("--name", required=True, help="imageset name, e.g. jj_punch1")
    ap.add_argument("--fighter", required=True, help="jj | andrew | han | enemy")
    ap.add_argument("--move", required=True, help="punch1, kick2, hurt, ...")
    ap.add_argument("--frames", type=int, default=8)
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--cell", type=int, default=128, help="cell height (px)")
    ap.add_argument("--cell-w", type=int, default=None, help="cell width (px), default = --cell")
    ap.add_argument("--target-h", type=int, default=108, help="anchor body height inside the cell")
    ap.add_argument("--baseline", type=int, default=119, help="feet row inside the cell")
    ap.add_argument("--anchor", choices=["first", "median"], default="first")
    ap.add_argument("--trim-start", type=int, default=0, help="drop N leading frames")
    ap.add_argument("--trim-end", type=int, default=0, help="drop N trailing frames")
    ap.add_argument("--pick", default=None,
                    help="explicit 1-based frame numbers (after trim), e.g. 3,6,8,10 — skips motion picking")
    ap.add_argument("--ref", type=int, default=None,
                    help="1-based frame used for scale / centre (default: first pick). Point it at an idle pose.")
    ap.add_argument("--preview", default=None, help="write an enlarged contact sheet here")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    cell_h = args.cell
    cell_w = args.cell_w or args.cell

    files = sorted(f for f in os.listdir(args.frames_dir) if f.lower().endswith(".png"))
    files = files[args.trim_start: len(files) - args.trim_end if args.trim_end else None]
    if not files:
        sys.exit("no frames found")

    keyed = [key_green(Image.open(os.path.join(args.frames_dir, f))) for f in files]
    boxes = [bbox(k) for k in keyed]
    valid = [i for i, b in enumerate(boxes) if b is not None]
    if not valid:
        sys.exit("every frame keyed to nothing — is the background flat #00FF00?")
    keyed = [keyed[i] for i in valid]
    boxes = [boxes[i] for i in valid]

    if args.pick:
        wanted = [int(p) - 1 for p in args.pick.split(",") if p.strip()]
        picks = [i for i in wanted if 0 <= i < len(keyed)]
        if len(picks) != len(wanted):
            sys.exit(f"--pick out of range (have {len(keyed)} keyed frames)")
    else:
        picks = pick_frames(boxes, args.frames)
    picked = [(keyed[i], boxes[i]) for i in picks]

    heights = [b[3] - b[1] for _, b in picked]
    if args.ref is not None:
        ri = args.ref - 1
        if not 0 <= ri < len(keyed):
            sys.exit("--ref out of range")
        rb = boxes[ri]
        ref_h = rb[3] - rb[1]
        ref_cx = (rb[0] + rb[2]) / 2
    elif args.anchor == "first":
        ref_h = heights[0]
        ref_cx = (picked[0][1][0] + picked[0][1][2]) / 2
    else:
        ref_h = sorted(heights)[len(heights) // 2]
        ref_cx = sorted((b[0] + b[2]) / 2 for _, b in picked)[len(picked) // 2]
    scale = args.target_h / max(1, ref_h)

    # Never let a frame spill out of the cell: clamp the shared scale to the widest / tallest pick.
    max_w = max((b[2] - b[0]) for _, b in picked) * scale
    max_h = max(heights) * scale
    limit = min(cell_w / max(1, max_w), args.baseline / max(1, max_h), 1.0)
    if limit < 1.0:
        print(f"[pack] clamping scale {scale:.3f} -> {scale * limit:.3f} to fit {cell_w}x{cell_h}")
        scale *= limit

    n = len(picked)
    cols = min(args.cols, n)
    rows = int(math.ceil(n / cols))
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    labels = []
    for idx, (im, b) in enumerate(picked):
        sub = im.crop(b)
        sw, sh = max(1, int(round(sub.width * scale))), max(1, int(round(sub.height * scale)))
        sub = sub.resize((sw, sh), Image.LANCZOS)
        # pin: feet on the baseline, body centre on the anchor centre (so lunges read as lunges)
        cx = (b[0] + b[2]) / 2
        dx = (cx - ref_cx) * scale
        x = int(round(cell_w / 2 - sw / 2 + dx))
        y = int(round(args.baseline - sh))
        x = max(0, min(cell_w - sw, x))
        y = max(0, min(cell_h - sh, y))
        col, row = idx % cols, idx // cols
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        cell.alpha_composite(sub, (x, y))
        sheet.alpha_composite(cell, (col * cell_w, row * cell_h))
        labels.append(f"{args.move}-{idx + 1}")

    meta = {
        "mode": args.move,
        "rows": rows,
        "cols": cols,
        "cell_size": cell_h,
        "cell_w": cell_w,
        "frame_labels": labels,
        "source": os.path.relpath(args.frames_dir, REPO),
        "picked_frames": [files[valid[i]] for i in picks],
        "ref_frame": files[valid[args.ref - 1]] if args.ref is not None else None,
        "scale": round(scale, 4),
        "anchor": args.anchor,
    }

    if args.preview:
        pv = Image.new("RGBA", sheet.size, (40, 20, 60, 255))
        pv.alpha_composite(sheet)
        pv.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(args.preview)
        print("[pack] preview ->", args.preview)

    if args.dry_run:
        print(json.dumps(meta, indent=2))
        return

    imageset = os.path.join(XCASSETS, f"{args.name}.imageset")
    os.makedirs(imageset, exist_ok=True)
    sheet.save(os.path.join(imageset, "img.png"), optimize=True)
    with open(os.path.join(imageset, "Contents.json"), "w") as f:
        json.dump({
            "images": [
                {"filename": "img.png", "idiom": "universal", "scale": "1x"},
                {"idiom": "universal", "scale": "2x"},
                {"idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)

    src_dir = os.path.join(SPRITES, args.fighter, args.move)
    os.makedirs(src_dir, exist_ok=True)
    sheet.save(os.path.join(src_dir, "sheet-transparent.png"), optimize=True)
    with open(os.path.join(src_dir, "pipeline-meta.json"), "w") as f:
        json.dump(meta, f, indent=2)

    print(f"[pack] {args.name}: {n} frames as {cols}x{rows} @ {cell_w}x{cell_h} -> {imageset}")
    if cell_w == cell_h and cell_h in (128, 160, 192, 256):
        print("[pack] square cells: GameAssets.optAuto picks the grid up automatically — rebuild and play.")
    else:
        print(f"[pack] non-square cell: register explicitly with opt(\"{args.name}\", {cols}, {rows})")


if __name__ == "__main__":
    main()
