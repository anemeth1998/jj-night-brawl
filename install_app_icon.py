#!/usr/bin/env python3
"""Install 1024x1024 AppIcon.png from source potato icon."""
from pathlib import Path
import shutil
import sys
import subprocess

SRC = Path("/Users/newcomputer/.grok/sessions/%2FUsers%2Fnewcomputer%2FDownloads%2FJJNightBrawl/019fd831-3db3-7312-a5f2-922f3a31f2e1/images/2.jpg")
DEST1 = Path("/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
DEST2 = Path("/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon 1.appiconset/AppIcon.png")
STATUS = Path("/Users/newcomputer/Downloads/JJNightBrawl/icon_install_status.txt")
JUNK = [
    Path("/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset/test_binary_write.bin"),
    Path("/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset/tiny2.png"),
    Path("/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset/tiny_test.png"),
]


def main() -> int:
    lines = []
    method = None
    try:
        from PIL import Image

        im = Image.open(SRC).convert("RGB")
        im = im.resize((1024, 1024), Image.Resampling.LANCZOS)
        DEST1.parent.mkdir(parents=True, exist_ok=True)
        DEST2.parent.mkdir(parents=True, exist_ok=True)
        im.save(DEST1, format="PNG", optimize=True)
        shutil.copyfile(DEST1, DEST2)
        method = "PIL"
    except Exception as e:
        try:
            DEST1.parent.mkdir(parents=True, exist_ok=True)
            subprocess.check_call(
                ["sips", "-s", "format", "png", "-z", "1024", "1024", str(SRC), "--out", str(DEST1)]
            )
            shutil.copyfile(DEST1, DEST2)
            method = f"sips (PIL failed: {e})"
        except Exception as e2:
            lines = [
                "result=FAILURE",
                f"error=pil:{e};sips:{e2}",
                f"src_exists={SRC.exists()}",
            ]
            STATUS.write_text("\n".join(lines) + "\n")
            print("\n".join(lines))
            return 1

    deleted = 0
    for j in JUNK:
        if j.exists():
            j.unlink()
            deleted += 1

    s1 = DEST1.stat().st_size if DEST1.exists() else 0
    s2 = DEST2.stat().st_size if DEST2.exists() else 0
    ok = DEST1.exists() and DEST2.exists() and s1 > 1000 and s2 > 1000
    lines = [
        f"result={'SUCCESS' if ok else 'FAILURE'}",
        f"method={method}",
        f"source={SRC}",
        f"dest1={DEST1}",
        f"dest1_size={s1}",
        f"dest1_dims=1024x1024",
        f"dest2={DEST2}",
        f"dest2_size={s2}",
        f"junk_deleted={deleted}",
    ]
    STATUS.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"FINAL: {'SUCCESS' if ok else 'FAILURE'} size1={s1} size2={s2}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
