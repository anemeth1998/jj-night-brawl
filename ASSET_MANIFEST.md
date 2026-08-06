# Asset manifest (workspace backup)

Binary PNGs/GIFs (~1.7MB total) are **not** stored in this repo via the text connector.

They are packaged as:
- `jj-night-brawl-assets-backup.tar.gz` (download from Grok project artifacts)

## Layout under jj-night-brawl/

### Map
- map/sky.png, far-bg.png, mid-bg.png

### JJ sprites
- sprites/jj/idle|walk|attack|hurt/sheet-transparent.png (+ frames, meta)
- sprites/jj/reference.jpg

### Enemies
- sprites/enemy/idle|walk|attack/sheet-transparent.png

### FX
- sprites/fx/sheet-transparent.png

## Restore onto this repo (on a Mac)

```bash
tar -xzf jj-night-brawl-assets-backup.tar.gz
cd jj-night-brawl
git clone https://github.com/anemeth1998/jj-night-brawl.git
cp -R map sprites ../jj-night-brawl/assets/
cd ../jj-night-brawl
git add assets
git commit -m "Add binary sprite and map assets"
git push
```
