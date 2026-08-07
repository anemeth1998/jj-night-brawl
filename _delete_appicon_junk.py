#!/usr/bin/env python3
"""Remove unassigned AppIcon test files and restore clean Contents.json."""
from __future__ import annotations

import json
import os
import sys

BASE = "/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset"
JUNK = ("test_binary_write.bin", "tiny2.png", "tiny_test.png")
CONTENTS = {
    "images": [
        {
            "filename": "AppIcon.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
        },
        {
            "appearances": [{"appearance": "luminosity", "value": "dark"}],
            "filename": "AppIcon.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
        },
        {
            "appearances": [{"appearance": "luminosity", "value": "tinted"}],
            "filename": "AppIcon.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
        },
    ],
    "info": {"author": "xcode", "version": 1},
}


def main() -> int:
    if not os.path.isdir(BASE):
        print(f"Missing directory: {BASE}", file=sys.stderr)
        return 1

    for name in JUNK:
        path = os.path.join(BASE, name)
        try:
            os.remove(path)
            print(f"Deleted: {path}")
        except FileNotFoundError:
            print(f"Already gone: {path}")
        except OSError as exc:
            print(f"Failed {path}: {exc}", file=sys.stderr)
            return 1

    contents_path = os.path.join(BASE, "Contents.json")
    with open(contents_path, "w", encoding="utf-8") as fh:
        json.dump(CONTENTS, fh, indent=2)
        fh.write("\n")
    print(f"Wrote clean Contents.json: {contents_path}")
    print("Remaining:", sorted(os.listdir(BASE)))
    print("SUCCESS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
