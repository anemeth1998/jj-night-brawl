# Kenny promote — Act I parallax (assets-only)

Promoted transparent plates into `JJNightBrawl/Assets.xcassets` (Engine/CampaignData untouched).

| Stage index | Campaign | Background folder | Imagesets |
|-------------|---------|-------------------|-----------|
| 0 | i-1-alley | downtown | `map_i1_{sky,far,mid}` (+ default `map_*`) |
| 1 | i-2-dock | train-yard | `map_i2_*` |
| 2 | i-3-club | opera-alley | `map_i3_*` |
| 3 | i-4-midtown | geary-strip | `map_i4_*` |
| — | finale hold | water-tower | **not** imported |

`Background/stages.json` titles were **not** imported into CampaignData.
Pose JPGs under `art-drops/` not promoted (need transparent atlases).

Code: `GameAssets.maps(forStageIndex:)` + `GameRenderer.drawParallax(..., stageIndex:)`.
