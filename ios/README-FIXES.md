# JJ Night Brawl — freeze / white-screen fixes (iPhone 16 Pro Max)

## What you were seeing

1. **Freeze right after START BRAWL**  
2. **White screen when reopening** the app (watchdog / crash recovery)

## Root causes

| # | Bug | Why it froze on device |
|---|-----|------------------------|
| 1 | **Audio thread detach** | `AVAudioPlayerNode` completion ran on the **audio** thread and called `engine.detach`. That is illegal. START plays `uiConfirm` + `waveStart` immediately → hang/crash ~0.1s after start. |
| 2 | **120Hz ProMotion redraw** | `CADisplayLink` uncapped on iPhone 16 Pro Max (120Hz) + full-screen Core Graphics every tick. Main thread overload → freeze → iOS kills app. |
| 3 | **Sprite re-crop every frame** | Every draw did `cgImage.cropping` + new `UIImage` per fighter. Huge alloc pressure on retina. |
| 4 | **SwiftUI HUD thrash** | Phase/special/hasGun bindings written **every** tick even when unchanged → constant SwiftUI layout. |
| 5 | **Main-thread asset chroma key** | Enemy sheet pink-key ran on main during init; large sheets make launch/resume hang → white screen. |
| 6 | **Force-unwrap `jjIdle!` on title** | Missing asset crashed renderer → white screen on relaunch. |

## Files to replace in Xcode

Copy these over `JJNightBrawl/Game/`:

- `GameAudio.swift`
- `GameAssets.swift`
- `GameCanvasView.swift`
- `GameEngine.swift`
- `GameRenderer.swift`
- `GameTypes.swift`

Then **Product → Clean Build Folder**, delete the app from the phone, rebuild & run.

## What changed (high level)

- Audio: attach/play/detach **only on main**; cap concurrent one-shot nodes; safe sample-rate fallback.
- Canvas: lock **60 fps**, cap content scale to 2×, pause display link in background, load assets async.
- Sprites: cache cropped frames once; no force-unwraps.
- HUD: only push SwiftUI state when values actually change.
- Engine: safer hit application (no force-unwrap of enemy index); particle cap.

## Asset tip

Use the **small transparent sheets** (~256×256) in `Assets.xcassets`, not the raw 1024×1024 generation sheets. If Console shows:

```text
[JJ] chroma-key on large sheet …
```

swap those images for the pre-keyed `sheet-transparent.png` versions.

## Quick retest checklist

1. Launch → title (not white).
2. Tap **START BRAWL** → combat runs, no freeze.
3. Punch / kick / move stick → responsive.
4. Background app 5s → resume → still running.
5. Force-quit and reopen → title again, not white.
