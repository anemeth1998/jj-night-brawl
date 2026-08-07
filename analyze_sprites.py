#!/usr/bin/env python3
"""Analyze enemy sprite PNGs for pink/magenta background pixels."""
from __future__ import annotations

import os
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "pillow", "-q"])
    from PIL import Image

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "JJNightBrawl")

FILES = [
    "Assets.xcassets/en_biz_walk.imageset/img.png",
    "Assets.xcassets/en_maga_walk.imageset/img.png",
    "Assets.xcassets/en_gothm_walk.imageset/img.png",
    "Assets.xcassets/en_gothf_walk.imageset/img.png",
    "Assets.xcassets/en_biz_idle.imageset/img.png",
    "Assets.xcassets/en_maga_idle.imageset/img.png",
    "Assets.xcassets/en_gothm_idle.imageset/img.png",
    "Assets.xcassets/en_gothf_idle.imageset/img.png",
    "Resources/Sprites/Enemies/biz_walk.png",
    "Resources/Sprites/Enemies/maga_walk.png",
    "Resources/Sprites/Enemies/gothm_walk.png",
    "Resources/Sprites/Enemies/gothf_walk.png",
    "Resources/Sprites/Enemies/biz_idle.png",
    "Resources/Sprites/Enemies/maga_idle.png",
    "Resources/Sprites/Enemies/gothm_idle.png",
    "Resources/Sprites/Enemies/gothf_idle.png",
]


def analyze(rel: str) -> dict:
    full = os.path.join(BASE, rel)
    if not os.path.exists(full):
        return {"path": rel, "error": "NOT FOUND"}

    st = os.stat(full)
    img = Image.open(full)
    mode = img.mode
    w, h = img.size
    rgba = img.convert("RGBA")
    pixels = list(rgba.getdata())
    total = len(pixels)

    near_magenta = 0  # R>200, B>200, G<100, a>=200
    hot_pink = 0  # R>220, G<120, B>150, a>=200
    fully_transparent = 0
    opaque = 0
    semi = 0
    color_counts: Counter = Counter()
    edge_magenta = 0
    edge_total = 0

    for i, (r, g, b, a) in enumerate(pixels):
        if a == 0:
            fully_transparent += 1
        elif a < 255:
            semi += 1
        else:
            opaque += 1

        if a >= 200:
            if r > 200 and b > 200 and g < 100:
                near_magenta += 1
            if r > 220 and g < 120 and b > 150:
                hot_pink += 1

        if a >= 250:
            key = (r // 16 * 16, g // 16 * 16, b // 16 * 16)
            color_counts[key] += 1

        x = i % w
        y = i // w
        if x == 0 or y == 0 or x == w - 1 or y == h - 1:
            edge_total += 1
            if a >= 200 and r > 200 and b > 200 and g < 100:
                edge_magenta += 1

    tl = pixels[0]
    samples = {
        "tl": pixels[0],
        "tr": pixels[w - 1],
        "bl": pixels[(h - 1) * w],
        "br": pixels[(h - 1) * w + w - 1],
        "center": pixels[(h // 2) * w + (w // 2)],
    }

    if fully_transparent > total * 0.3:
        if near_magenta < 10:
            bg = "transparent (no magenta)"
        else:
            bg = "transparent canvas + magenta patches"
    elif near_magenta > total * 0.1:
        bg = "SOLID PINK/MAGENTA background"
    elif near_magenta > 50:
        bg = "significant magenta patches"
    else:
        bg = "mostly clean / non-magenta"

    return {
        "path": rel,
        "size_bytes": st.st_size,
        "dims": f"{w}x{h}",
        "mode": mode,
        "total_px": total,
        "opaque": opaque,
        "semi": semi,
        "transparent": fully_transparent,
        "near_magenta": near_magenta,
        "hot_pink": hot_pink,
        "edge_magenta": f"{edge_magenta}/{edge_total}",
        "top_left_rgba": tl,
        "corners": samples,
        "top_colors": color_counts.most_common(8),
        "bg": bg,
        "magenta_pct_opaque": round(100 * near_magenta / max(opaque, 1), 2),
    }


def main() -> None:
    results = [analyze(f) for f in FILES]
    for r in results:
        print("=" * 70)
        if "error" in r:
            print(r)
            continue
        print(f"FILE: {r['path']}")
        print(f"  size={r['size_bytes']} bytes | dims={r['dims']} | mode={r['mode']}")
        print(
            f"  pixels: total={r['total_px']} opaque={r['opaque']} "
            f"semi={r['semi']} transparent={r['transparent']}"
        )
        print(
            f"  near-magenta (R>200,B>200,G<100,a>=200): {r['near_magenta']} "
            f"({r['magenta_pct_opaque']}% of opaque)"
        )
        print(f"  hot-pink (R>220,G<120,B>150,a>=200): {r['hot_pink']}")
        print(f"  edge magenta: {r['edge_magenta']}")
        print(f"  top-left RGBA: {r['top_left_rgba']}")
        print(f"  corners: {r['corners']}")
        print(f"  top opaque color buckets: {r['top_colors']}")
        print(f"  ASSESSMENT: {r['bg']}")

    print("\n" + "=" * 70)
    print("RANKING BY near-magenta count:")
    ranked = sorted(
        [r for r in results if "error" not in r],
        key=lambda x: -x["near_magenta"],
    )
    for i, r in enumerate(ranked, 1):
        print(
            f"  {i}. mag={r['near_magenta']:6d} hot={r['hot_pink']:6d} | "
            f"{r['path']}"
        )
        print(f"      tl={r['top_left_rgba']} | {r['bg']}")

    print("\nPER ENEMY TYPE:")
    for t in ("biz", "maga", "gothm", "gothf"):
        rs = [r for r in ranked if t in r["path"].lower()]
        walk = sum(r["near_magenta"] for r in rs if "walk" in r["path"])
        idle = sum(r["near_magenta"] for r in rs if "idle" in r["path"])
        print(f"  {t}: walk_mag={walk} idle_mag={idle} nfiles={len(rs)}")


if __name__ == "__main__":
    main()
