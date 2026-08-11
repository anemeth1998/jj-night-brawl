# Game Design — JJ: Night Brawl

## Pitch

**JJ: Night Brawl** is a 32-bit Streets of Rage–style side-scrolling beat-em-up. You play JJ — a punk who clears the night street with fists, boots, a guitar-riff special, and (eventually) a gun. Tone is loud, sardonic, and slogan-first.

## Pillars

1. **Readable brawling** — chunky silhouettes, clear hit feedback, Streets of Rage cadence
2. **Punk JJ** — attitude in every special and wave break
3. **Wave pressure** — packs of archetypes, not endless identical trash
4. **Unlock drama** — gun arrives after wave 3; it changes the last kills
5. **Ship both** — same fantasy on **iOS** and **web**

## Platforms

| Platform | Status |
|----------|--------|
| iOS (Swift / SpriteKit-ish stubs) | Partial source under `ios/` |
| Web | Missing; controls designed for keyboard + touch mirrors |

## Core loop

1. Enter wave on a scrolling street strip
2. Move, punch, kick, jump; build special meter
3. Clear pack → optional cigarette smoke break beat
4. Next wave; after wave 3 unlock **gun**
5. Finish stage / victory pose

## Combat

| Action | Keys | Notes |
|--------|------|-------|
| Move | WASD / Arrows | 8-way on lane plane |
| Punch | J / Z | Fast, low damage, combo starter |
| Kick | K / X | Slower, more knockback |
| Jump | Space / Shift | Hop for air / avoid |
| Riff special | L / C | Metered AOE; punk slogan bubble |
| Gun | F / U / G | Unlocks **after wave 3** |

Touch mirrors: virtual stick + PUNCH / KICK / JUMP / RIFF / GUN.

### Gun line

On a qualifying last kill with the gun:

> "Counting or not counting gang violence?"

## Enemy archetypes

| Archetype | ID | Fantasy |
|-----------|-----|---------|
| Businessman | `biz` | White-collar trash mob; jabby, foldable |
| MAGA | `maga` | Conservative bruiser; tankier / charge-y |
| Goth | `gothm` / `gothf` | Night-crowd flankers; swipe pressure |

## v0 level placeholders

Not locked — see Production Board for status.

1. **Alley Opener** — teach move + punch/kick on biz
2. **Sidewalk Surge** — add MAGA pressure
3. **Club Approach** — introduce goth packs
4. **Smoke Break** — cigarette break between waves (heal / tone beat)
5. **Gun Street** — post–wave 3 gun climax

## Tone

- **Slogan bubbles** on riff special (punk one-liners)
- **Cigarette smoke break** between waves — pause, atmosphere, not a full cutscene
- **Gun last-kill line** as above; keep it dry, not preachy
- Visual language: 32-bit side-scroller; magenta-keyed sheets for runtime

## Open questions

- Exact combat numbers (damage, hitstun, meter rates) — fill after playable core
- Final v0 level count and names
- Whether goth M/F share one moveset with palette swap or diverge
- Gun ammo vs infinite after unlock
- Web tech target (canvas / engine choice) once source is re-assembled
- How much story beyond slogan + smoke break for v0
