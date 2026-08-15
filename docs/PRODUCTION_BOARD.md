# Production Board — JJ: Night Brawl

Living status board. Update statuses as work lands; keep the snapshot honest.

**Last updated:** 2026-08-15

## Legend

| Status | Meaning |
|--------|---------|
| 🔴 | Not started / missing / blocked |
| 🟡 | Partial / stubbed / external only |
| 🟢 | Recovered / in-repo / ready enough to build on |

## Snapshot (2026-08-15)

| Area | Status | Notes |
|------|--------|-------|
| Swift / iOS source | 🟡 | Partial — `ios/` stubs and sync notes; full engine not restored |
| Web engine | 🟢 | Vite app in `web/`; combat + menu + save in `web/src/game/` |
| Art (sprites / FX) | 🟢 | JJ / enemy / FX runtime sheets landed in git |
| Map / parallax | 🟢 | Downtown trio in `assets/map/` plus five stages in `assets/Background/` |
| Sound | 🟡 | Procedural SFX + TDM 8-bit menu theme |
| UI | 🟢 | Title, menu select, HUD, touch pad |
| Levels | 🟡 | Five story waves in engine; stage art exists, not uniquely wired per wave |
| Story / tone seeds | 🟢 | Slogan bubbles, cigarette break, gun line in engine |
| Shipping | 🔴 | Local `npm run dev` only |

## Next priorities

1. Wire Background stages to story waves
2. Restore or rebuild the iOS engine against the TypeScript model
3. Fill remaining Andrew/Han combat sheets
4. Lock combat numbers after playtest
5. **Sound pass** (hits already procedural; need a brawl bed)

## Blockers

- Full Swift/Xcode engine still missing (`ContentView`, `GameEngine.swift`)
- Andrew/Han only have idle + walk in-engine sheets

## Levels status

| Level | Intent (v0 placeholder) | Status |
|-------|-------------------------|--------|
| L1 — Alley Opener | Tutorial wave, biz trash mobs | 🟡 |
| L2 — Sidewalk Surge | Mix biz + MAGA pressure | 🟡 |
| L3 — Club Approach | Introduce goth; denser packs | 🟡 |
| L4 — Wave Break / Smoke | Cigarette break beat; heal vibe | 🟡 |
| L5 — Gun Unlock | Post–wave 3 gun; climax street | 🟡 |

## Enemy status

| Archetype | Role | Art | AI / combat | Status |
|-----------|------|-----|-------------|--------|
| Businessman (`biz`) | Trash mob / jabber | 🟢 | 🟡 in engine | 🟡 |
| MAGA (`maga`) | Tanky / charge | 🟢 | 🟡 in engine | 🟡 |
| Goth M (`gothm`) | Flanker / swipe | 🟢 | 🟡 in engine | 🟡 |
| Goth F (`gothf`) | Flanker / swipe | 🟢 | 🟡 in engine | 🟡 |

## Moveset status

| Move | Input (web) | Status |
|------|-------------|--------|
| Move | WASD / Arrows | 🟢 |
| Punch | J / Z | 🟢 |
| Kick | K / X | 🟢 |
| Jump | Space / Shift | 🟢 |
| Riff special | L / C (meter) | 🟢 |
| Gun | F / U / G (after wave 3) | 🟢 |

## Related docs

- [GAME_DESIGN.md](./GAME_DESIGN.md)
- [CHARACTER_BIBLE.md](./CHARACTER_BIBLE.md)
- [ASSET_TRACKER.md](./ASSET_TRACKER.md)
- [CHANGELOG.md](./CHANGELOG.md)
