# Changelog — JJ: Night Brawl

All notable project-level notes for this repo. Gameplay versioning can split later; for now this tracks bootstrap and docs.

## [Unreleased]

### Added

- `docs/` living production documentation set:
  - `docs/README.md` — index
  - `docs/PRODUCTION_BOARD.md` — status board, priorities, blockers, tables
  - `docs/GAME_DESIGN.md` — pitch, pillars, loop, combat, tone
  - `docs/CHARACTER_BIBLE.md` — JJ / enemies / feel / flags
  - `docs/ASSET_TRACKER.md` — pipeline + trackers + briefing template
  - `docs/CHANGELOG.md` — this file

## 2026-08-06 — Bootstrap

- Private repo bootstrap for **JJ: Night Brawl**
- Recovered art/assets layout under `assets/` (meta + paths; binaries in external tar)
- Root docs: `README.md`, `ASSET_MANIFEST.md`, `BACKUP_NOTES.md`, `HOW_TO_ADD_BINARIES.md`
- Partial iOS stubs / sync notes under `ios/`
- Note: full Swift/Xcode source and complete web engine not fully restored in-repo

## 2026-08-12 — Playable web backup

- Full title screen (`assets/ui/title-screen.png`)
- Menu Select brick-wall loop (`assets/ui/menu-select-loop.mp4`)
- Roster: JJ, Andrew, Han (Ash/Rex removed)
- Andrew hover: sit + laptop (`assets/ui/andrew-hover.mp4`)
- Han hover: phone (`assets/ui/han-hover.mp4`)
- Idle/walk sprites under `assets/sprites/andrew` and `assets/sprites/han`
- Latest canvas/menu source in `web/src/game/`
- Full playable snapshot on branch `backup/web-playable-20260812`
