# Adding binary assets to this private repo

The Grok GitHub connector uploads **text** files reliably. Image binaries (PNG/JPG) need a Mac/git or GitHub web upload.

## Character poses + cutscenes (2026-08-12)

1. Download **`art-drops-characters-cutscenes-2026-08-12.tar.gz`** from the Grok project (`05-backups/`).
2. In a local clone of this repo:

```bash
tar -xzf art-drops-characters-cutscenes-2026-08-12.tar.gz
git add assets/art-drops
git commit -m "assets: JJ/Andrew/Han pose sheets + cutscenes"
git push
```

3. Or drag-and-drop `assets/art-drops/characters` and `assets/art-drops/cutscenes` in the GitHub web UI.

## Older sprite/background packs

1. Download `jj-night-brawl-assets-backup.tar.gz` from the Grok project.
2. Unpack and copy into `assets/`.
3. `git add` / `commit` / `push`.
