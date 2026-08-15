# Backup notes

## What is here
Asset pack from project workspace as of 2026-08-06.

## What is not fully here yet
- Complete Swift/Xcode project (GameEngine.swift, ContentView, etc.)

Web engine is in `web/src/game/` with a Vite app shell (`cd web && npm run dev`).

If you still have JJNightBrawl-FOR-XCODE.tar.gz on a device or in chat downloads, add it under releases/ or the repo root in a follow-up commit.

## Preferred sheet files
Use **/sheet-transparent.png for runtime. Raw sheets are optional source art.


Latest playable web snapshot: branch `backup/web-playable-20260812` (2026-08-12).

## 2026-08-12 — title / menu 8-bit theme

- Track: `assets/audio/tdm-8bit.mp3` (TDM 8-bit mix, ~3:07, loops).
- Wired in `web/src/game/audio.ts` as `playMenuTheme()` — a singleton so the
  song starts on the title card and **continues into menu select** without
  restarting. Fades out when a brawl starts; fades back in on return to menu.
- Live Grok preview source for this drop: `web/preview-20260812/`.
