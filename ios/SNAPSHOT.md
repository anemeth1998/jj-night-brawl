# iOS snapshot (2026-08-07) — updated

## Local (source of truth)

| Item | Location |
|------|----------|
| **Full Xcode project** | `~/Downloads/JJNightBrawl` |
| **Local git** | initialized, branch `main`, remote `origin` → `anemeth1998/jj-night-brawl` |
| **Commits** | `bc78afa` full project; `a1e249a` push instructions |
| **Tar backup (binaries+sources)** | `~/Desktop/JJNightBrawl-backup-20260807-143737.tar.gz` (8.8 MB) |
| **Desktop fix pack** | `~/Desktop/jj-night-brawl-ios-fix` (patch only; Engine/Renderer already applied) |

## GitHub private repo status

Repo: https://github.com/anemeth1998/jj-night-brawl (private)

Synced via MCP (text):
- `ios/SNAPSHOT.md`, `ios/README-FIXES.md`, `ios/Game/GameTypes.swift`
- `ios/JJNightBrawl/.gitignore`, app entry, `GITHUB_PUSH.md`

**Not fully on GitHub yet** (need one `gh auth login` then git push for binaries + large Swift):
- Full `GameEngine` / `GameRenderer` / `GameCanvasView` / `GameAssets` / `GameAudio` (placeholders may remain under `ios/Game/`)
- PNG assets under `Assets.xcassets` and `Resources/`

## Code soundness

Playtest-ready with freeze mitigations applied. Not production-tight (hygiene nits only).

## Finish full GitHub sync (one-time auth)

```bash
# gh binary already at /tmp/gh/bin/gh (or install from cli.github.com)
/tmp/gh/bin/gh auth login

cd ~/Desktop
/tmp/gh/bin/gh repo clone anemeth1998/jj-night-brawl
rsync -a --exclude .git --exclude backups ~/Downloads/JJNightBrawl/ \
  ~/Desktop/jj-night-brawl/ios/JJNightBrawl/
cd ~/Desktop/jj-night-brawl
git add -A && git commit -m "Full Xcode project: freeze fixes + assets"
git push origin main
```
