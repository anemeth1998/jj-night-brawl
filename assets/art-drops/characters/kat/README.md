# Kat — character art drop

**Added 2026-09-19.** Pixel-art stills + first combat frames for **Kat**, new playable / ally candidate.

## Lock

| Field | Value |
|---|---|
| Name | Kat |
| Role | Goth-alt brawler (roster add) |
| Hair | Jet black, thick straight bangs, wavy shoulder layers |
| Face | Pale, light blue-grey eyes, heavy purple shadow, wine-red lips, nose stud + labret |
| Jewelry | Silver hoops, layered chain with O-ring / crescent |
| Top | Black sleeveless zip-front crop, large silver grommets, buckled shoulder straps |
| Bottom | Black ripped denim short-shorts |
| Legs | White wide-diamond fishnets |
| Boots | Tall black studded platform combat boots |
| Marks | Dark abstract tattoo, right upper arm; color tattoos on thighs through fishnets |

Outfit lock is the grommet zip crop from the standing reference photos (not the velvet lace-up from the brick-wall selfie). That silhouette reads at sprite scale and does not collide with JJ’s hoodie + black fishnets.

## Files (16:9, 1792×1008, black field — same as JJ / Andrew / Han)

| File | Pose |
|---|---|
| `front-idle.jpg` | Front stand |
| `peace-stand.jpg` | Peace sign |
| `kneel.jpg` | One-knee kneel |
| `walk-right.jpg` | Walk, facing right |
| `punch.jpg` | Foreshortened punch |
| `run.jpg` | Sprint right |
| `back.jpg` | Back / over-shoulder |
| `jump-fists.jpg` | Jump, fists up |
| `crouch.jpg` | Low squat |
| `sit-cross-legged.jpg` | Sit |
| `closeup.jpg` | Head-and-shoulders |
| `look-up.jpg` | Looking up |
| `over-shoulder.jpg` | Look-back smirk |
| `combat-idle.jpg` | Side-view guard |
| `kick.jpg` | Side-view roundhouse |
| `hurt.jpg` | Hit reaction |
| `idle-sheet-2x2.jpg` | 4-cell idle / step sheet |
| `raw/` | Unletterboxed Imagine outputs |

Photo refs live in `06-reference/kat/photo-ref-01.jpg` … `05`.

## Game sprites

`jj-night-brawl/sprites/kat/{idle,walk,attack,kick,hurt,jump,run}/`

- `sheet-transparent.png` — 256×256 (2×2 of 128 cells), engine-shaped like JJ
- `{action}-1.png` — single 128×128 cell
- idle also has `idle-1.png` … `idle-4.png` split from the 2×2 sheet

These are first-pass keyed frames, not a finished atlas. Kick / idle still need a real 4-frame cycle before iOS `GameAssets` wiring.


## Combat pack v1 (2026-09-19)

Real 4-frame cycles (unique cells, not duplicated singles):

- combat-idle-sheet-2x2.jpg
- walk-sheet-2x2.jpg
- run-sheet-2x2.jpg
- attack-sheet-2x2.jpg
- kick-sheet-2x2.jpg
- hurt-sheet-2x2.jpg

Extra combat stills: block jab hook uppercut kick-jump kick-side kick-roundhouse knockback downed downed-sit get-up victory

Engine sheets: jj-night-brawl/sprites/kat/{idle,walk,run,attack,kick,hurt}/ now have 4 unique 128 cells + 256 2x2 sheet-transparent.png.

Xcode drop: 04-ios-drops/kat-combat/ + 04-ios-drops/kat-combat-xcode-drop.zip

Jump is still the first-pass single pose. 8-frame walk/run/special and a true roundhouse/sweep cycle are next.
