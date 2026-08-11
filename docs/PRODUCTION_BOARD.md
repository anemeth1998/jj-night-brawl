# Production Board — JJ: Night Brawl

Living status board. Update statuses as work lands; keep the snapshot honest.

**Last updated:** 2026-08-11

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

1. Playable core: **move + punch/kick**
2. Land binary assets in **git / LFS**
3. Lock **v0 level list**
4. Fill **combat numbers**
5. **Sound pass** plan

## Blockers

- Full source not restored (complete Swift/Xcode + web TypeScript engine)
- Binary assets not in git (packaged as external `jj-night-brawl-assets-backup.tar.gz`)

## Levels status

| Level | Intent (v0 placeholder) | Status |
|-------|-------------------------|--------|
| L1 — Alley Opener | Tutorial wave, biz trash mobs | 🔴 |
| L2 — Sidewalk Surge | Mix biz + MAGA pressure | 🔴 |
| L3 — Club Approach | Introduce goth; denser packs | 🔴 |
| L4 — Wave Break / Smoke | Cigarette break beat; heal vibe | 🔴 |
| L5 — Gun Unlock | Post–wave 3 gun; climax street | 🔴 |

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
