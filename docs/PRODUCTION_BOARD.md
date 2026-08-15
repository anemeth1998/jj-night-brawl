# Production Board — JJ: Night Brawl

Living status board. Update statuses as work lands; keep the snapshot honest.

**Last updated:** 2026-08-15

## P0 — current milestone

**One wave that feels good:** playable feel + stable 60fps + readable JJ.

Live project: `Desktop/Projects/JJNightBrawl` (GitHub `anemeth1998/jj-night-brawl`). Not Ikemen-GO-JJ-side.

**Stage 1 (confirmed):** `p0OneTightWave` ON = 2 biz / FIST CHECK. Goth OFF until Andrew signs. Eric released for one sim-build. Socrates waits on that build.

| Surface | Owner | Job |
|---------|-------|-----|
| Combat knobs | Victor | `GameEngine` / `GameTypes` |
| Wave flag | Jimmy | `p0OneTightWave` — match Victor’s 2 biz |
| Jump / haptics | Bradford | Jump buffer, JUMP next to PUNCH, haptics — do not wipe Engine combat |
| Visuals | Kenny | No new visual patch |
| Sim-build | Eric | One sim-build; Socrates waits |

CoS wakes one or two of those for a single surface. JJ stays producer (this board) — no engine code.

**Parked until Andrew says go:** monetization, ASO, LiveOps, widgets, visionOS, TestFlight. Goth until Andrew signs.

## Legend

| Status | Meaning |
|--------|---------|
| 🔴 | Not started / missing / blocked |
| 🟡 | Partial / stubbed / external only |
| 🟢 | Recovered / in-repo / ready enough to build on |

## Snapshot (2026-08-11)

| Area | Status | Notes |
|------|--------|-------|
| Swift / iOS source | 🟡 | Partial — `ios/` stubs and sync notes; full engine not restored |
| Web engine | 🔴 | Missing |
| Art (sprites / FX) | 🟡 | Recovered; binaries live in external tar, not in git |
| Map / parallax | 🟡 | Recovered externally (`sky` / `far` / `mid`); not landed in git |
| Sound | 🔴 | Not started |
| UI | 🔴 | Not started |
| Levels | 🔴 | Not started (placeholders only in design) |
| Story / tone seeds | 🟢 | Slogan bubbles, cigarette break, gun line exist in design |
| Shipping | 🔴 | Not started |

## Next priorities

1. **P0 Stage 1:** `p0OneTightWave` ON = 2 biz / FIST CHECK (see [P0 — current milestone](#p0--current-milestone))
2. Land binary assets in **git / LFS** *(after P0)*
3. Lock **v0 level list** *(after P0)*
4. Fill **combat numbers** *(after P0)*
5. **Sound pass** plan *(after P0)*

## Blockers

- Full source not restored (complete Swift/Xcode + web TypeScript engine)
- Binary assets not in git (packaged as external `jj-night-brawl-assets-backup.tar.gz`)

## Levels status

| Level | Intent (v0 placeholder) | Status |
|-------|-------------------------|--------|
| L1 — Alley Opener | **P0 target:** 2 biz / FIST CHECK (`p0OneTightWave`) | 🔴 |
| L2 — Sidewalk Surge | Mix biz + MAGA pressure — parked until after P0 | 🔴 |
| L3 — Club Approach | Introduce goth; denser packs — parked until after P0 | 🔴 |
| L4 — Wave Break / Smoke | Cigarette break beat; heal vibe — parked until after P0 | 🔴 |
| L5 — Gun Unlock | Post–wave 3 gun; climax street — parked until after P0 | 🔴 |

## Enemy status

| Archetype | Role | Art | AI / combat | Status |
|-----------|------|-----|-------------|--------|
| Businessman (`biz`) | Trash mob / jabber | 🟡 sheets external | 🔴 | 🟡 |
| MAGA (`maga`) | Tanky / charge | 🟡 sheets external | 🔴 | 🟡 |
| Goth M (`gothm`) | Flanker / swipe | 🟡 sheets external | 🔴 | 🟡 |
| Goth F (`gothf`) | Flanker / swipe | 🟡 sheets external | 🔴 | 🟡 |

## Moveset status

| Move | Input (web) | Status |
|------|-------------|--------|
| Move | WASD / Arrows | 🔴 |
| Punch | J / Z | 🔴 |
| Kick | K / X | 🔴 |
| Jump | Space / Shift | 🔴 |
| Riff special | L / C (meter) | 🔴 |
| Gun | F / U / G (after wave 3) | 🔴 |

## Related docs

- [GAME_DESIGN.md](./GAME_DESIGN.md)
- [CHARACTER_BIBLE.md](./CHARACTER_BIBLE.md)
- [ASSET_TRACKER.md](./ASSET_TRACKER.md)
- [CHANGELOG.md](./CHANGELOG.md)
