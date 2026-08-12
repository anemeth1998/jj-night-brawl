# Feels-good controls checklist

Run on a landscape iPhone Simulator or device after **START BRAWL**.

## Stick

- [ ] Crawl near center (small throw → slow walk)
- [ ] Full speed at rim
- [ ] Diagonals are **not** faster than cardinals (normalized)
- [ ] Release returns knob home and **stops walk** (no stuck axis / walk anim)
- [ ] No facing flicker while stick sits near center
- [ ] Finger starting off-center still aims correctly (offset from pad center, not drag translation)

## Punch spam

- [ ] Mash punch during recovery → next punch comes out on the **first free frame**
- [ ] One press → one attack (no double-fire from a single press)
- [ ] Queue stays light (single pending move; no deep combo buffer)

## Jump-kick

- [ ] Tap jump slightly **before** landing still jumps (`jumpBuffer` ≈ 0.14s)
- [ ] Jump then kick in air works
- [ ] Landing has no long movement lock; can re-jump / attack quickly
- [ ] Jump during attack recovery is allowed (hurt-stun still blocks)

## Touch targets / safe area

- [ ] All action buttons ≥ **44pt** (shipped at **56pt** min height)
- [ ] Pad clears home indicator / landscape safe area (bottom padding `max(10, safeArea.bottom + 6)`, horizontal ≥ 16)
- [ ] Buttons fire **on press** (not on release)

## Tuning constants (`GameEngine.ControlTuning` + movement)

| Constant | Value | Role |
|----------|------:|------|
| `stickDeadzone` | 0.08 | Analog ignore radius |
| `stickDigitalMirror` | 0.25 | Coarse L/R/U/D bools from axes |
| `facingThreshold` | 0.2 | Facing flip hysteresis |
| `moveAnimSpeed` | 30 | Walk anim speed gate |
| `jumpBuffer` | 0.14 s | Early-press jump window |
| `attackBufferMax` | 1 | Single-slot punch/kick buffer |
| `minTouchPt` | 44 | Documented minimum hit target |
| `playerSpeed` | 210 | Ground X speed |
| `playerDepthSpeed` | 135 | Lane Y speed |
| `playerAccel` | 2200 | Ground accel |
| `playerDecel` | 2800 | Brake / reverse |
| `playerAirAccel` | 1400 | Air accel |
| `airControl` | 0.78 | Air move scale |

Files (keep mirrors identical):

- `ios/JJNightBrawl/JJNightBrawl/Game/GameEngine.swift`
- `ios/JJNightBrawl/JJNightBrawl/Game/GameCanvasView.swift`
- `ios/JJNightBrawl/JJNightBrawl/Game/GameTypes.swift`
- `ios/Game/` (same three files)
