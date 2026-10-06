# JJ kick pack — Xcode drop

Primary combat kick **already ships** in the iOS engine. Do not replace it.

```
04-ios-drops/jj-kick/jj_kick.imageset/img.png
```

256×256 RGBA, 2×2 grid, 128px cells, facing right.

This file **is** the current
`JJNightBrawl/Assets.xcassets/jj_kick.imageset/img.png`
(same bytes as the 2×2 you attached).

| cell | file | pose |
|------|------|------|
| (0,0) f0 | frames-v1/jj_kick_front_00.png | chamber / right knee up, left fist guard |
| (1,0) f1 | frames-v1/jj_kick_front_01.png | mid-extend (hit window lives here) |
| (0,1) f2 | frames-v1/jj_kick_front_02.png | full front snap / max extension |
| (1,1) f3 | frames-v1/jj_kick_front_03.png | recover-chamber |

## Install in Xcode

**v1 needs no GameAssets change.** Kick is already:

```swift
let kick = must("jj_kick", 2, 2, stripChroma: stripChroma)
```

1. Only replace `jj_kick.imageset/img.png` if you rebuild the 2×2.
   The copy in this folder is identical to what is already in the project.
2. Leave `Contents.json` alone — it already points at `img.png`.
3. Also keep `assets/sprites/jj/kick/sheet-transparent.png` in sync
   for the web/git pipeline.

Do **not** drop an 8-frame or 24-frame sheet into `jj_kick.imageset`
until the v2 engine line below is in. `GameEngine.updateAttackPlayer`
hardcodes non-special attacks to 4 frames:

```swift
let frames = kind == .special ? max(1, playerSpecialFrames) : 4
```

## Why these 4 frames stay

Kick duration = 0.44s. Active window = normalized t in 0.14–0.34.

| frame | t range | in hit window? |
|-------|---------|----------------|
| f0 chamber     | 0.00–0.25 | late f0 yes |
| f1 mid-extend  | 0.25–0.50 | early f1 yes |
| f2 full-extend | 0.50–0.75 | no |
| f3 recover     | 0.75–1.00 | no |

Reordering so full-extend is f1 would change the feel of a shipping move.

## Variants (not wired to the KICK button yet)

128² transparent cells under `frames/`:

| folder | files | source |
|--------|-------|--------|
| snap/ | 01_chamber, 02_mid, 04_contact, 08_recover | **production cells** |
| snap/ | 02b_mid | extra still |
| jump/ | 00_crouch, 01_coil, 01b_crouch, 04_contact | extra stills |
| side/ | 03_contact, 03b_guard | extra stills |
| sweep/ | 03_contact | extra still |
| axe/ | 03_contact | extra still |
| drop/ | 04_contact | extra still |
| roundhouse/ | 01_turn, 02_chamber, 04_contact, 08_recover | video-loop picks 06/08/12/16 |
| back/ | 01_turn | video-derived turn — NOT a real donkey/back kick |

Strips: `variant-sheets/jj_kick_{snap,jump,side,sweep,axe,drop,roundhouse}_strip.png`

Hires keyed sources: `02-art-drops/jj-kick-pack/processed/hires/`

`generated-stills/` keeps the raw imagine IDs for reference. Do not drop
those into the engine sheet — some flood-keys fragmented.

## Fluid video loops

I2V from a single JJ cell, extracted to 24 transparent 128² frames:

```
video-loops/snap/snap_01.png … snap_24.png          (source 27F1j)
video-loops/roundhouse/roundhouse_01.png … _24.png  (source MbW5J)
video-loops/jump/jump_01.png … _24.png              (source muUsz)
sheets-video/jj_kick_{snap,roundhouse,jump}_video.png
sheets-video/jj_kick_{snap,roundhouse,jump}_video_2x2.png
sheets-video/jj_kick_{snap,roundhouse,jump}_video_8f.png
previews/*_{4,8,24}f.gif
source-videos/jj_{front_snap,roundhouse,jump_kick}.mp4
```

Use loops as in-between sources. Do not ship them as `jj_kick` until v2.

## v2 engine line (optional, 8-frame kick)

Same patch Andrew uses. After this lands you can swap in a 4×2 / 8-frame sheet.

See `JJ_KICK_XCODE_PATCH.swift`.

## Style lock

- Character: JJ — magenta/pink spikes + dark roots, black cropped jacket,
  dark mini skirt, black fishnets, black combat boots.
- Left fist often raised. **No spray can** on the kick sheet.
- Clean cartoon lines matching **this** 2×2, not the painted idle/walk look.
- Facing 3/4 RIGHT. Engine flipX mirrors for left.
- 128×128 RGBA, transparent, no drop shadow, no ground, no magenta key.
- Feet near bottom, head near top, ~8–12px margin.
  Existing kick bbox ≈ (19–33, 11)–(94–109, 119).

## GitHub

GitHub connector is text-only. PNG binaries go via Mac git or GitHub web UI.
