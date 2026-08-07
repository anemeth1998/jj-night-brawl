#!/bin/bash
set -euo pipefail
SRC="/Users/newcomputer/.grok/sessions/%2FUsers%2Fnewcomputer%2FDownloads%2FJJNightBrawl/019fd831-3db3-7312-a5f2-922f3a31f2e1/images/1.jpg"
DEST1="/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
DEST2="/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon 1.appiconset/AppIcon.png"
/usr/bin/sips -s format png -z 1024 1024 "$SRC" --out "$DEST1"
/bin/cp -f "$DEST1" "$DEST2"
/bin/ls -la "$DEST1" "$DEST2"
/usr/bin/sips -g pixelWidth -g pixelHeight -g hasAlpha "$DEST1" "$DEST2"
echo SUCCESS
