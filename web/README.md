# JJ: Night Brawl — Web

Playable Vite + React build of the canvas engine in `src/game/`.

## Run

```bash
cd web
npm install
npm run dev
```

Open http://localhost:5173

```bash
npm run build        # typecheck + production bundle
npm run check:assets # confirm runtime PNGs / audio / loops exist
```

Repo `assets/` is served at `/assets/…` (title card, sheets, TDM theme, character loops).

## Layout

| Path | Role |
|------|------|
| `src/game/engine.ts` | Combat, waves, AI, render |
| `src/game/GameCanvas.tsx` | Title / menu / HUD / input |
| `src/game/MainMenu.tsx` | Story, endless, shop, roster |
| `src/game/assets.ts` | Sheet map + missing-file fallbacks |
| `src/game/audio.ts` | Procedural SFX + menu theme |
| `src/game/save.ts` | localStorage profile |
| `preview-20260812/` | Older Grok preview snapshot (not the live app) |
