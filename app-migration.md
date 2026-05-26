# macOS App Migration to Homebrew
**Date:** 2026-05-26  
**Goal:** Standardize all macOS app management under Homebrew Cask for unified versioning and updates.

---

## Already Managed by Homebrew ✅
These apps were already installed and tracked via `brew install --cask` prior to this migration.

| App | Cask / Formula | Type |
|-----|---------------|------|
| Docker | `docker`, `docker-desktop` | cask |
| iTerm2 | `iterm2` | cask |
| Multipass | `multipass` | cask |
| Stats | `stats` | cask |
| VirtualBox | `virtualbox` | cask |
| Vagrant | `vagrant` | cask |
| Java (AdoptOpenJDK 8) | `adoptopenjdk8` | cask |
| Java (AdoptOpenJDK 11) | `adoptopenjdk11` | cask |
| Java (AdoptOpenJDK 16) | `adoptopenjdk16` | cask |
| Java (latest) | `java` | formula |

---

## Migrated to Homebrew ✅
Apps that were manually installed and have been migrated to Homebrew Cask management.  
**Migration completed: 2026-05-26**

| App | Cask | Status | Notes |
|-----|------|--------|-------|
| Bitwarden | `bitwarden` | ✅ Done | auto_updates |
| Claude | `claude` | ✅ Done | auto_updates |
| Discord | `discord` | ✅ Done | auto_updates |
| Google Chrome | `google-chrome` | ✅ Done | auto_updates |
| Spotify | `spotify` | ✅ Done | auto_updates |
| Tailscale | `tailscale-app` | ✅ Done | auto_updates |
| Visual Studio Code | `visual-studio-code` | ✅ Done | auto_updates |
| Windscribe | `windscribe` | ⚠️ Installer Only | Cask downloads installer only — `WindscribeInstaller.app` launched from `/usr/local/Caskroom/windscribe/2.22.10/`. Complete GUI install to finish. |
| iStat Menus | `istat-menus` | ✅ Done | Paid app — license unaffected by cask migration |
| Disk Inventory X | `disk-inventory-x` | ⚠️ Deprecated | Installed but cask deprecated (Gatekeeper check failure) — will be disabled 2026-09-01. Find replacement before then. |
| WinBox | `winbox` | ✅ Done | |
| UniFi Network Controller | `ubiquiti-unifi-controller` | ⚠️ Deprecated | Installed as `UniFi.app`. Cask deprecated (Gatekeeper check failure) — will be disabled 2026-09-01. Monitor for updated cask. |

---

## Cannot Be Migrated ❌
Apps with no Homebrew Cask equivalent. Must be updated manually or via their own updater.

| App | Reason | Update Method |
|-----|--------|--------------|
| UniFi OS Server | No cask — differs from `ubiquiti-unifi-controller` | Manual download from Ubiquiti |
| Brother (printer driver) | No cask for Brother printer software | System Preferences / Brother update tool |
| Magic Disk Benchmark | No cask available | Manual download |
| Numbers | Built-in macOS / Mac App Store | System/App Store updates |
| Pages | Built-in macOS / Mac App Store | System/App Store updates |
| Safari | Built-in macOS | macOS system updates |

---

## Validation Checklist
After migration, run these to confirm everything is clean:

```sh
# Confirm all casks are installed
brew list --cask

# Confirm no orphaned apps in /Applications
ls /Applications/

# Run brew doctor to check for issues
brew doctor

# Generate/update Brewfile to snapshot current state
brew bundle dump --force --file=~/Brewfile
```

---

## Next Steps
- [x] Install `mas` (Mac App Store CLI) — already installed (v7.0.0)
- [x] Install `topgrade` for unified one-command updates — already installed (v17.5.1)
- [x] Install `latest` cask for GUI update dashboard — installed 2026-05-26
- [x] Generate `Brewfile` — saved to `~/macos_scripts/Brewfile` (80 formulae, 22 casks, 3 MAS apps, 20 VS Code extensions)

## Ongoing Maintenance

### One-command update everything
```sh
topgrade
```
Runs `brew upgrade`, `mas upgrade`, `npm update`, `pip` upgrades, and more in one pass.

### Restore full environment on a new Mac
```sh
brew bundle install --file=~/path/to/Brewfile
```

### Update Brewfile after installing new apps
```sh
brew bundle dump --force --file=~/macos_scripts/Brewfile
```

### GUI update dashboard
Open **Latest.app** from `/Applications` to see a visual list of all outdated apps.
