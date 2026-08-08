# Push local commits to GitHub

Local repo is clean with all changes committed. `git push` needs one-time auth.

```bash
# Option A — GitHub CLI (tools/gh is already downloaded)
cd ~/Downloads/JJNightBrawl
./tools/gh auth login
# choose GitHub.com → HTTPS → Login with browser
git push -u origin main
```

```bash
# Option B — paste a Personal Access Token (classic) with `repo` scope
cd ~/Downloads/JJNightBrawl
git push -u origin main
# Username: anemeth1998
# Password: <paste PAT>
```

Remote: https://github.com/anemeth1998/jj-night-brawl (private)

Local HEAD: b2778bc (includes 08200a0 device black-screen fix)
