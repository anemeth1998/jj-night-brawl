# Andrew kick pack — Xcode drop

Primary combat kick (works in the current iOS engine today):

```
04-ios-drops/andrew-kick/andrew_kick.imageset/img.png
```

256×256 RGBA, 2×2 grid, 128px cells, facing right.

| cell | file | pose |
|------|------|------|
| (0,0) f0 | frames/snap/01_windup.png | chamber / snap start |
| (1,0) f1 | frames/snap/04_contact.png | CONTACT = uploaded reference |
| (0,1) f2 | frames/snap/06_recoil.png | fold-back |
| (1,1) f3 | frames/snap/08_recover.png | recover toward idle |

## Install in Xcode

1. Replace
   `JJNightBrawl/Assets.xcassets/andrew_kick.imageset/img.png`
   with `andrew_kick.imageset/img.png` from this folder.
2. Leave `Contents.json` as-is (already points at `img.png`, 1x universal).
3. One line in `GameAssets.swift` `load()`:

```swift
// OLD
let andrewKickSheet = opt("andrew_kick", 1, 1, stripChroma: stripChroma)
// NEW
let andrewKickSheet = opt("andrew_kick", 2, 2, stripChroma: stripChroma)
```

If you skip step 3 the 256×256 sheet draws as one mashed frame.

Also copy the sheet to
`assets/sprites/andrew/kick/sheet-transparent.png`
and `pipeline-meta.json` next to it (web + git pipeline).

## Why 4 frames, not 8

`GameEngine.updateAttackPlayer` hardcodes non-special attacks to 4 frames:

```swift
let frames = kind == .special ? max(1, playerSpecialFrames) : 4
```

An 8-frame sheet in `andrew_kick` will only play the top row. Extra snap in-betweens
(`01b`, `02`, `02b`, `03_extend_*`) live under `frames/snap/` for a later 8-frame bump.

v2 engine line (optional):

```swift
var playerKickFrames: Int = 4
// in updateAttackPlayer:
let frames = kind == .special ? max(1, playerSpecialFrames)
           : kind == .kick    ? max(1, playerKickFrames)
           : 4
```

Inject next to `playerSpecialFrames` in `GameCanvasView`:

```swift
engine.playerKickFrames = assets.sheetForPlayer(
    anim: .attack, attackKind: .kick, fighter: engine.state.selectedFighter
).frameCount
```

Then you can swap in a 4×2 512×256 sheet.

## Variants (not wired to the KICK button yet)

128² transparent cells under `frames/`:

- snap/     — front snap cycle + extras
- roundhouse/
- jump/
- sweep/
- axe/
- side/
- drop/
- back/

Strips: `variant-sheets/andrew_kick_{roundhouse,jump,axe}_strip.png`

Hires keyed RGBA sources: `02-art-drops/andrew-kick-pack/processed/hires/`

## Timing (unchanged)

Kick duration 0.44s. Active window is normalized t in 0.14–0.34, so the hit
lands on f0 late + f1. That is why CONTACT is cell 1, not cell 0.

## Style note

f1 is the original game sprite. f0/f2/f3 are generated stills keyed off white
and fit to 128. They will not pixel-match the original line weight. If a frame
pops, swap it for another file in `frames/snap/` and re-pack with
`pack_andrew_kick_sheets.py`.

## Fluid video loops (bonus)

I2V clips were generated from Andrew's idle sprite, then extracted to 24
transparent 128² frames each:

```
video-loops/snap/snap_01.png … snap_24.png
video-loops/roundhouse/roundhouse_01.png … _24.png
video-loops/jump/jump_01.png … _24.png
sheets-video/andrew_kick_{snap,roundhouse,jump}_video.png
sheets-video/andrew_kick_{snap,roundhouse,jump}_video_2x2.png
previews/*_{4,8,24}f.gif
source-videos/andrew_{front_snap,roundhouse,jump_kick}.mp4
```

These stay closer to the idle/walk look than the illustration stills. Use them
as in-between sources. Do not drop an 8-frame or 24-frame sheet into
`andrew_kick.imageset` until the v2 engine line above is in.
