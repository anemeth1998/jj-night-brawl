#!/bin/bash
# Remove leftover test files from AppIcon.appiconset that cause:
# warning: The app icon set "AppIcon" has 2 unassigned children.
set -euo pipefail
DIR="/Users/newcomputer/Downloads/JJNightBrawl/JJNightBrawl/Assets.xcassets/AppIcon.appiconset"
rm -f "$DIR/test_binary_write.bin" "$DIR/tiny2.png" "$DIR/tiny_test.png"
cat > "$DIR/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
ls -la "$DIR"
echo "SUCCESS: AppIcon.appiconset cleaned"
