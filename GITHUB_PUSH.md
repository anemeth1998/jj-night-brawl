# Push this project to private GitHub

Remote: https://github.com/anemeth1998/jj-night-brawl (private)

Local git is initialized at `~/Downloads/JJNightBrawl` (commit bc78afa+).
Full binary backup: `~/Desktop/JJNightBrawl-backup-20260807-143737.tar.gz`

## Recommended: auth once, then push full tree under ios/JJNightBrawl

```bash
# Install GitHub CLI (if needed)
# https://cli.github.com/  OR  download release binary

gh auth login

# Option A — push Downloads project as its own history (new branch)
cd ~/Downloads/JJNightBrawl
git remote add origin https://github.com/anemeth1998/jj-night-brawl.git  # if missing
git fetch origin
git checkout -b ios-full-sync
# Optionally restructure: put everything under ios/JJNightBrawl/
git push -u origin ios-full-sync

# Option B — clone remote, copy project in, push main
cd ~/Desktop
gh repo clone anemeth1998/jj-night-brawl
rsync -a --exclude .git --exclude backups ~/Downloads/JJNightBrawl/ \
  ~/Desktop/jj-night-brawl/ios/JJNightBrawl/
cd ~/Desktop/jj-night-brawl
git add -A
git commit -m "Add full Xcode project with freeze fixes and assets"
git push origin main
```

MCP already updated text stubs on `main` (GameTypes, app entry, SNAPSHOT, gitignore).
PNG assets still need git push (local tar has them).
