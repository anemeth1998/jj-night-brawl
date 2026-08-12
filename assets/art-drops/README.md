# Art drops (character poses + cutscenes)

**Added 2026-08-12.** Pixel-art stills for the main cast and story cutscenes.

## Cast lock

| Folder | Character | Notes |
|---|---|---|
| `characters/jj/` | **JJ** | Pink/black hair, fishnets, energy can + cig, heavy piercings |
| `characters/andrew/` | **Andrew** | Brown hair, freckles, red/black striped hoodie, rainbow wristband, checker vans |
| `characters/han/` | **Han** | Grey cat-ear beanie, blonde/orange hair, quilted jacket, skull tee, black/orange/teal sneakers — **no** rainbow wristband |
| `characters/group/` | Trio | Group portraits |
| `cutscenes/` | Story stills | Numbered beat plates |

## Unpack binaries

From the Grok project download:

`05-backups/art-drops-characters-cutscenes-2026-08-12.tar.gz` (~9.3 MB)

```bash
# in a clone of anemeth1998/jj-night-brawl
tar -xzf art-drops-characters-cutscenes-2026-08-12.tar.gz
# creates assets/art-drops/characters/... and assets/art-drops/cutscenes/...
git add assets/art-drops
git commit -m "assets: add JJ/Andrew/Han pose sheets + cutscenes"
git push
```

Or drag-and-drop the folders in the GitHub web UI.
