# Clip → sprite-sheet pipeline

Turns short generated video clips (Grok Imagine or similar) into the 128px-cell sprite sheets
the game loads via `GameAssets.must/opt("<name>", cols, rows)`.

## 1. Generate a clip

Use **image-to-video** from the matching start still in `assets/art-drops/video-refs/`
(`jj_idle_ref.png`, `andrew_idle_ref.png`, `han_idle_ref.png`, `biz_…`, `maga_…`, `gothm_…`, `gothf_…`).
Regenerate those stills any time with `python3 tools/export_refs.py`.

Prompt rules (the packer depends on them):

- Flat solid **#00FF00** background, no floor, no shadow, no props, no text.
- Side view, character faces **right**, camera locked, no zoom or pan.
- **One action per clip**, 2–3 s: return to the idle pose at the end. Idle / walk clips should loop.
- Keep the whole body in frame, roughly the same size as the start still.

Save as `assets/art-drops/video/<fighter>/<move>.mp4`, e.g. `assets/art-drops/video/jj/punch1.mp4`.

Move names the engine looks for:

| Fighters (jj / andrew / han) | Enemies (biz / maga / gothm / gothf) |
|---|---|
| `idle`, `walk`, `hurt`, `knockdown` | `hurt`, `knockdown` |
| `punch1` jab, `punch2` cross, `punch3` hook | `attack` (telegraph + punch) |
| `kick1`, `kick2` roundhouse, `airkick`, `dash` | |

## 2. Extract frames

```sh
xcrun swift tools/clip2sheet.swift assets/art-drops/video/jj/punch1.mp4 /tmp/jj_punch1 --fps 12
```

## 3. Key + pack

```sh
python3 tools/pack_sheet.py /tmp/jj_punch1 --name jj_punch1 --fighter jj --move punch1 \
    --frames 8 --cols 4 --preview /tmp/jj_punch1.png
```

- `--frames 8 --cols 4` → 4×2 sheet (8 frames). Use `--frames 4 --cols 2` for 2×2 idle / hurt.
- Keep cells **square** at `--cell 128`: `GameAssets` infers the grid from the PNG size
  (128 → 160 → 192 → 256 px cells), so no code edit is needed per sheet. A bigger *square* cell does
  not buy horizontal room — the renderer maps the whole cell to the same on-screen height, so the body
  just shrinks. The bbox-centred layout keeps an extended kick inside 128 px anyway.
- `--pick 3,6,8,10,13,16,18,21` hand-picks frames (1-based, after trim) instead of motion picking;
  `--ref 1` scales / centres every frame off that one (point it at an idle pose so the body matches
  `andrew_idle`'s 108 px). Already-keyed transparent frames (e.g. a Grok pack's `video-loops/`) work
  as input too — the green key is a no-op on them.
- `--trim-start / --trim-end` drop dead frames; `--dry-run` prints the pick without writing.

Outputs `JJNightBrawl/Assets.xcassets/<name>.imageset/` (no pbxproj change needed — folder catalog)
and `assets/sprites/<fighter>/<move>/` (source copy + `pipeline-meta.json`). Rebuild in Xcode and the
engine picks the sheet up: `jj_punch2` for the cross, `han_airkick` for Han's air kick, and so on —
a missing sheet keeps using the fighter's base `attack` / `kick` / `hurt` atlas.

Enemy sheets use the `en_` prefix: `--name en_biz_hurt --fighter enemy --move biz-hurt`
(`en_<type>_hurt`, `en_<type>_knockdown`; `_dead` is accepted as an alias for knockdown).
