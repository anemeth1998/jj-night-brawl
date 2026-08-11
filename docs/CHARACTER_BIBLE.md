# Character Bible — JJ: Night Brawl

## JJ — identity

| Field | Notes |
|-------|-------|
| Name | JJ |
| Role | Protagonist / player fighter |
| Aesthetic | Punk — street clothes, attitude-first silhouette |
| Fantasy | Cleaves a bad night with fists, boots, riff, then gun |
| Platform art | `assets/sprites/jj/` — idle, walk, attack, hurt (+ reference) |

### Voice

- Short, slogan-ready lines (speech bubbles on special)
- Sardonic, not monologue-heavy
- Wave-break vibe: cigarette smoke, quiet smirk energy
- Signature gun line: **"Counting or not counting gang violence?"**

### Placeholder frame-data (JJ)

Numbers are placeholders until combat fill-in. Align sheets with `pipeline-meta.json` grids.

| Anim | Sheet folder | Grid (meta) | Placeholder timing |
|------|--------------|-------------|--------------------|
| Idle | `jj/idle` | 2×2 @ 128 | Loop ~0.5–0.6s / cycle |
| Walk | `jj/walk` | per meta | Cycle while moving |
| Attack (punch/kick share sheet for now) | `jj/attack` | per meta | Punch: short startup; Kick: longer recovery |
| Hurt | `jj/hurt` | per meta | Brief invuln flash after |
| Jump / smoke / victory | TBD | — | Enum stubs exist in iOS `AnimName` |

| Move | Startup | Active | Recovery | Notes |
|------|---------|--------|----------|-------|
| Punch | TBD | TBD | TBD | Combo starter |
| Kick | TBD | TBD | TBD | More knockback |
| Riff | TBD | TBD | TBD | AOE; spends meter; slogan bubble |
| Gun | TBD | TBD | TBD | After wave 3 only |

## Enemy roster stubs

| ID | Name | Fantasy | Art | Moveset stub |
|----|------|---------|-----|--------------|
| `biz` | Businessman | White-collar jabber | Shared `enemy/` sheets (external binaries) | Approach → jab → fold |
| `maga` | MAGA | Tank / charge | Shared sheets | Approach → wind-up → shove |
| `gothm` | Goth (M) | Flanker | Shared sheets | Circle → swipe |
| `gothf` | Goth (F) | Flanker | Shared sheets | Circle → swipe |

HP / damage / score values: **TBD** (fill with combat numbers pass).

## Combat feel rules

1. **Readable hits** — impact FX + flash; no mushy overlapping swings
2. **Punch vs kick** — punch chains; kick creates space
3. **Special is a moment** — riff pauses the mind (slogan + AOE), not a spam button
4. **Gun changes the end** — unlock after wave 3; last-kill line lands once per qualifying kill moment
5. **Archetypes read at a glance** — biz soft, maga heavy, goth slippery
6. **Same fantasy on iOS + web** — inputs differ, cadence does not

## Downstream flags

Track in Production Board / Asset Tracker as these resolve:

| Flag | Meaning | Default |
|------|---------|---------|
| `needs_frame_data` | Placeholder timings not locked | ON |
| `needs_unique_enemy_sheets` | Enemies still share generic sheets | ON |
| `binaries_in_git` | PNGs landed via git/LFS | OFF |
| `gun_unlock_wave` | Wave index for gun | `3` |
| `slogan_bubbles` | Riff shows punk line | ON |
| `smoke_break` | Inter-wave cigarette beat | ON |
| `gun_last_kill_line` | Play signature line | ON |
| `web_engine` | Web target implemented | OFF |
| `full_source_restored` | Complete Swift + web recovered | OFF |
