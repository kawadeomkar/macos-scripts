#!/bin/bash
# brew-app-scan.sh
# Daily scan: finds apps in /Applications not managed by Homebrew or MAS,
# checks for brew cask equivalents, installs them, and sends a notification.
#
# Usage:
#   brew-app-scan.sh          — full run: scan, install casks, notify, push Brewfile
#   brew-app-scan.sh --list   — dry run: print unmanaged apps only, no changes

set -uo pipefail

LIST_ONLY=false
[[ "${1:-}" == "--list" ]] && LIST_ONLY=true

HOMESERVER_DIR="$HOME/macos_scripts"

if $LIST_ONLY; then
  log() { echo "$*"; }
else
  LOG_FILE="/tmp/brew-app-scan-$(date +%Y%m%d).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  log() { echo "[$(date '+%H:%M:%S')] $*"; }
fi

$LIST_ONLY || log "── Brew App Scanner starting ──────────────────────────────────"

# ── Apps to always skip (system, built-in, no cask available) ────────────────
SKIP_APPS=(
  "Safari.app"
  "Numbers.app"
  "Pages.app"
  "Keynote.app"
  "Feedback Assistant.app"
  "Logitech Unifying Software.app"  # no cask available
  "Brother"                          # printer driver folder
  "Claude Code URL Handler.app"      # managed by Claude Code CLI
  "Utilities"                        # folder, not an app
)

# ── Step 1: Build map of brew-managed app names ──────────────────────────────
$LIST_ONLY || log "Building brew-managed app list..."
declare -A BREW_MANAGED  # "AppName.app" → "cask-name"

while IFS= read -r cask; do
  # Parse artifact app names from cask info (line format: "AppName.app (App)")
  while IFS= read -r app_name; do
    [[ -n "$app_name" ]] && BREW_MANAGED["$app_name"]="$cask"
  done < <(brew info --cask "$cask" 2>/dev/null \
    | grep -E '\.app \(App\)' \
    | awk '{print $1}')
done < <(brew list --cask 2>/dev/null)

$LIST_ONLY || log "Found ${#BREW_MANAGED[@]} brew-managed apps."

# ── Step 2: Build map of MAS-managed app names ───────────────────────────────
$LIST_ONLY || log "Building MAS-managed app list..."
declare -A MAS_MANAGED  # "AppName.app" → 1

while IFS= read -r line; do
  # mas list format: "1234567890  App Name  (version)"
  app_name=$(echo "$line" | sed 's/^[0-9 ]*//' | sed 's/ ([0-9.]*)$//')
  [[ -n "$app_name" ]] && MAS_MANAGED["${app_name}.app"]=1
done < <(mas list 2>/dev/null)

$LIST_ONLY || log "Found ${#MAS_MANAGED[@]} MAS-managed apps."

# ── Step 3: Scan /Applications for unmanaged apps ────────────────────────────
$LIST_ONLY || log "Scanning /Applications..."
UNMANAGED=()

while IFS= read -r app_path; do
  app_name=$(basename "$app_path")

  # Skip known exceptions
  skip=false
  for s in "${SKIP_APPS[@]}"; do
    [[ "$app_name" == "$s" ]] && skip=true && break
  done
  $skip && continue

  # Skip if already brew-managed
  [[ -n "${BREW_MANAGED[$app_name]+_}" ]] && continue

  # Skip if MAS-managed
  [[ -n "${MAS_MANAGED[$app_name]+_}" ]] && continue

  UNMANAGED+=("$app_path")
done < <(find /Applications ~/Applications -maxdepth 2 -name "*.app" 2>/dev/null | sort)

# ── --list mode: print results and exit ──────────────────────────────────────
if $LIST_ONLY; then
  echo "Apps not managed by Homebrew or MAS (${#UNMANAGED[@]} found):"
  echo ""
  if [[ ${#UNMANAGED[@]} -eq 0 ]]; then
    echo "  ✓ All apps are managed."
  else
    for app_path in "${UNMANAGED[@]}"; do
      app_name=$(basename "$app_path")
      cask_guess=$(echo "${app_name%.app}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      if brew info --cask "$cask_guess" &>/dev/null 2>&1; then
        echo "  $app_name  →  brew install --cask $cask_guess  (cask available)"
      else
        echo "  $app_name  →  no cask found"
      fi
    done
  fi
  exit 0
fi

log "${#UNMANAGED[@]} unmanaged app(s) found."

# ── Step 4: Check for brew cask equivalents and install ──────────────────────
NEWLY_INSTALLED=()
STILL_UNMANAGED=()

for app_path in "${UNMANAGED[@]}"; do
  app_name=$(basename "$app_path")
  # Derive cask name: strip .app, lowercase, spaces → hyphens
  cask_guess=$(echo "${app_name%.app}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  log "Checking brew for '$app_name' (trying cask: '$cask_guess')..."

  if brew info --cask "$cask_guess" &>/dev/null 2>&1; then
    log "  → Cask found: $cask_guess. Installing..."
    if brew install --cask "$cask_guess" 2>&1; then
      NEWLY_INSTALLED+=("$cask_guess")
      log "  → Installed: $cask_guess"
    else
      log "  → Install failed for $cask_guess"
      STILL_UNMANAGED+=("$app_name")
    fi
  else
    STILL_UNMANAGED+=("$app_name")
    log "  → No cask found for: $app_name"
  fi
done

# ── Step 5: Update Brewfile and commit to repo ───────────────────────────────
if [[ -d "$HOMESERVER_DIR/.git" ]]; then
  log "Updating Brewfile..."
  brew bundle dump --force --file="$HOMESERVER_DIR/Brewfile" 2>/dev/null
  cd "$HOMESERVER_DIR"
  git add Brewfile
  if ! git diff --cached --quiet; then
    git commit -m "chore(brew): update Brewfile from daily app scan $(date +%Y-%m-%d)"
    git push origin main
    log "Committed and pushed updated Brewfile to repo."
  else
    log "Brewfile unchanged — no commit needed."
  fi
fi

# ── Step 6: Send macOS notification ──────────────────────────────────────────
if [[ ${#NEWLY_INSTALLED[@]} -gt 0 ]]; then
  installed_list=$(printf '%s, ' "${NEWLY_INSTALLED[@]}" | sed 's/, $//')
  msg="Installed ${#NEWLY_INSTALLED[@]} new cask(s): $installed_list. Old .app files in /Applications can now be removed."
  osascript -e "display notification \"$msg\" with title \"Brew App Scanner\" subtitle \"New casks installed\""
  log "Notification sent: $msg"
elif [[ ${#STILL_UNMANAGED[@]} -gt 0 ]]; then
  unmanaged_list=$(printf '%s, ' "${STILL_UNMANAGED[@]}" | sed 's/, $//')
  msg="${#STILL_UNMANAGED[@]} app(s) have no brew cask: $unmanaged_list"
  osascript -e "display notification \"$msg\" with title \"Brew App Scanner\" subtitle \"No action needed\""
  log "Notification sent: $msg"
else
  log "All apps are managed. No notification needed."
fi

log "── Scan complete ───────────────────────────────────────────────"
log "  Newly installed : ${NEWLY_INSTALLED[*]:-none}"
log "  Still unmanaged : ${STILL_UNMANAGED[*]:-none}"
