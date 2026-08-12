# JJ: Night Brawl — Xcode / iOS

Native **SwiftUI + UIKit + Core Graphics** port of the beat-em-up.  
Open this project in **Xcode** (or hand it to **Grok Coding Agents**).

---

## Where is it?

| Path | What |
|------|------|
| **`ios/JJNightBrawl/`** | Full Xcode project (open this) |
| **`ios/JJNightBrawl/JJNightBrawl.xcodeproj`** | Double-click this in Finder |
| **`ios/JJNightBrawl-Xcode.tar.gz`** | Packed copy of the same project |
| **`ios/README.md`** | Short index for the `ios/` folder |

On this workspace:

```text
/workspace/ios/JJNightBrawl/JJNightBrawl.xcodeproj
```

---

## How to open in Xcode (Mac)

### Option A — folder on your Mac

1. Copy the **`JJNightBrawl`** folder to your Mac.
2. Double-click **`JJNightBrawl.xcodeproj`**.
3. Pick an **iPhone simulator** (landscape — the app is landscape-only).
4. Target → **Signing & Capabilities** → your **Team** (device builds).
5. **Run** (⌘R).

### Option B — tarball

```bash
tar -xzf JJNightBrawl-Xcode.tar.gz
open JJNightBrawl/JJNightBrawl.xcscheme 2>/dev/null || open JJNightBrawl/JJNightBrawl.xcodeproj
```

### Option C — Grok Coding Agents

Open the **`JJNightBrawl`** project folder and ask for gameplay / UI changes.

---

## Touch controls (iPhone / iPad)

The game is **landscape** and ships with a full on-screen pad:

| Control | What it does |
|---------|----------------|
| **Left virtual stick** | Walk / lane depth (drag; spring back on release) |
| **PUNCH** | Primary attack (fires on press) |
| **KICK** | Heavy attack |
| **JUMP** | Jump |
| **RIFF** | Guitar special (needs meter; bright when ready) |
| **GUN** | Appears after wave 3; fire pistol |
| **PAUSE / RESUME** | Top-left chip |
| **SOUND ON/OFF** | Top-right chip |
| **START BRAWL** | Title / retry / play again |

Buttons are large, fire-on-press (not wait-for-release), and the stick clears cleanly so movement doesn’t stick.

External keyboard still works (WASD / J K L F / Space).

---

## Keyboard (iPad / Mac Catalyst)

| Action | Keys |
|--------|------|
| Move | WASD / Arrows |
| Punch | J / Z |
| Kick | K / X |
| Jump | Space / Shift |
| Guitar riff | L / C (meter ≥ 40%) |
| Gun | F / U / G (after wave 3) |
| Pause | P / Esc |
| Start / retry | Enter |

### Gun

- Clear **wave 3** → **GUN UNLOCKED**
- Wave 4+: pistol + **GUN READY (F)** HUD
- Last enemy of a wave killed by a bullet →  
  **“Counting or not counting gang violence?”**

---

## Layout

```
JJNightBrawl/
├── JJNightBrawl.xcodeproj
├── README.md
└── JJNightBrawl/
    ├── JJNightBrawlApp.swift
    ├── Assets.xcassets/          32-bit sprites + map
    ├── Resources/
    └── Game/
        ├── GameTypes.swift
        ├── GameEngine.swift      waves, combat, riff, gun, smoke
        ├── GameRenderer.swift
        ├── GameAssets.swift
        ├── GameAudio.swift
        └── GameCanvasView.swift  loop + touch pad + stick + UI
```

## Requirements

- Xcode 15+  
- iOS 16+  
- Landscape Left / Right  
- No SPM deps
