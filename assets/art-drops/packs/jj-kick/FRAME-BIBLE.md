# JJ Kick Animation Pack — frame bible
# JJ Night Brawl / Xcode drop
# Source sheet: Assets.xcassets/jj_kick.imageset/img.png (256×256, 2×2)
# That file IS the attached reference. MD5 matches Resources/Sprites/JJ/kick.png.

## Art lock (do not drift)
- Character: JJ — magenta/pink spiked hair + dark roots, short sides,
  black cropped jacket over a pink-ish inner shirt, dark mini skirt,
  black fishnets, black combat boots.
- Left fist often raised near the face / chest. No spray can. No cigarette.
- Style: clean cartoon lines, same as the existing jj_kick 2×2.
  Not pixel. Not photo. Not the painted idle/walk sheets.
- Facing: 3/4 side, RIGHT. Engine flipX mirrors for left.
- Canvas: 128×128 RGBA, transparent. No drop shadow, no ground, no magenta key.
- Padding: feet near bottom, head near top, ~8–12px margin.
  Match current kick bbox (19–33, 11)–(94–109, 119).
- Hair follows motion (spikes drag opposite the kick).
- Jacket hem + skirt kick with the motion.

## Engine timing
- Kick duration = 0.44s
- Active / hit window = 0.14–0.34s
- Current iOS load: `must("jj_kick", 2, 2)` in GameAssets.swift  ← already correct
- Engine hardcodes kick to 4 frames (`updateAttackPlayer`)
- Recommended future playback: 8 frames @ ~18 fps = 0.44s exactly
- Target load after v2: `must("jj_kick", 4, 2)` or SpriteSheet(frames:)

## Primary combat sheet (ships as jj_kick) — DO NOT REPLACE
Existing production 2×2. Packed row-major.

| # | label        | phase     | time (s) | pose |
|---|--------------|-----------|----------|------|
| 0 | snap-01      | start     | 0.00     | **EXISTING CELL (0,0).** Chamber. Weight on left, right knee up to hip, left fist guard, slight lean. |
| 1 | snap-02      | startup   | 0.11     | **EXISTING CELL (1,0).** Mid-extend. Shin unfolding forward, toes pointing, fist still up. HIT WINDOW. |
| 2 | snap-03      | CONTACT   | 0.22     | **EXISTING CELL (0,1).** Full front snap, max extension, chest-height-ish. After current hit window. |
| 3 | snap-04      | recovery  | 0.33     | **EXISTING CELL (1,1).** Recover-chamber. Knee folding back, arms returning to guard. |

Hit confirm today lives on late f0 + early f1 (inside 0.14–0.34).

## Extra snap in-betweens (do not overwrite primary 4)
Generate only if identity holds. Pack later as 8-frame 4×2.

| # | label            | pose |
|---|------------------|------|
| 01b | chamber-high   | Knee higher than f0, hips start to square, left arm opens a hair |
| 02b | unfold         | Leg unfolding between f1 and f2, heel coming forward |
| 03b | held-contact   | Same as f2, toes flexed more, jacket/skirt kicked by motion |
| 06  | recoil         | Knee unlocks ~10°, shoulders recover forward |
| 07  | drop           | Kicking foot dropping toward ground, torso upright |

## Variant sheets (export separately; do not overwrite primary)

### Kick B — Roundhouse (8f)  `jj_kick_roundhouse`  4×2
1. chamber: right knee across body, hips closed
2. hips start to open, kicking shin still bent
3. thigh horizontal, shin whipping
4. CONTACT: full roundhouse, hips open, kicking foot at chest height
5. held contact, skirt + jacket flare
6. recoil, standing leg planted
7. foot dropping, torso unwinding
8. recover toward idle-adjacent chamber

### Kick C — Jump / flying (8f)  `jj_kick_jump`  4×2
1. coil: both knees bend, arms down-back
2. leave ground, knees tucked
3. flying chamber, right knee forward
4. CONTACT: flying front snap, body almost horizontal-lean
5. held flying contact
6. recoil in air
7. fall, kicking leg dropping
8. land recover

### Kick D — Low sweep (6f)  `jj_kick_sweep`  3×2
1. drop stance, weight on left
2. torso drops, right leg starts to whip low
3. CONTACT: boot at shin height, body crouched
4. follow-through, sweeping past
5. plant / catch balance
6. rise recover

### Kick E — Axe (6f)  `jj_kick_axe`  3×2
1. high chamber, right knee / foot above hip
2. foot almost overhead, torso lean
3. CONTACT: descending chop, heel down toward collarbone line
4. follow through past contact
5. foot dropping
6. recover

### Kick F — Side thrust (6f)  `jj_kick_side`  3×2
1. chamber side-on, knee up, hips closed
2. piston unfolding
3. CONTACT: heel thrust, leg locked
4. held thrust
5. recoil fold
6. recover

### Kick G — Dropkick  `jj_kick_drop`
Both legs out, body airborne, boots first.

### Kick H — Back / donkey  `jj_kick_back`
Look back over shoulder, heel driving backward (still drawn facing right;
engine flip handles the other side).

## Pack rules
- 128×128 cells, transparent
- Row-major sheets
- Primary `jj_kick` stays 2×2 / 4 frames until GameEngine v2
- Variants get their own imagesets; do not steal the `jj_kick` name
