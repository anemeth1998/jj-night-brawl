# Push this project to private GitHub

Remote: https://github.com/anemeth1998/jj-night-brawl (private)

Local git is initialized at `~/Downloads/JJNightBrawl`.
Full binary backup: `~/Desktop/JJNightBrawl-backup-20260807-143737.tar.gz`

## Recommended: auth once, then push full tree under ios/JJNightBrawl

```bash
gh auth login

cd ~/Desktop
gh repo clone anemeth1998/jj-night-brawl
rsync -a --exclude .git --exclude backups ~/Downloads/JJNightBrawl/ \
  ~/Desktop/jj-night-brawl/ios/JJNightBrawl/
cd ~/Desktop/jj-night-brawl
git add -A
git commit -m "Add full Xcode project with freeze fixes and assets"
git push origin main
```

PNG assets need git push (local tar has them).
Local project is the source of truth for playtesting.
