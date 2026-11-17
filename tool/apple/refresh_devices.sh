#!/bin/bash
# Keeps the personal Czechify builds on this Mac and on the iPhone usable.
#
# Apps signed with a free Apple "Personal Team" carry a provisioning profile
# that expires after 7 days; after that macOS and iOS refuse to open them.
# This script rebuilds and reinstalls each app before its profile runs out.
#
# It builds from a separate worktree checked out at $CZECHIFY_REF, so
# uncommitted work in the main checkout never reaches a device. Run by the
# launchd agent installed with tool/apple/install_refresh_agent.sh, or by
# hand:  tool/apple/refresh_devices.sh [--force] [--mac-only|--iphone-only]
#
# Settings (environment variables, or ~/.config/czechify/refresh.env):
#   CZECHIFY_REPO          main checkout (default: this script's repository)
#   CZECHIFY_REF           branch or commit to build (default: curriculum/v1.2-plan)
#   CZECHIFY_IPHONE_UDID   iPhone to install on
#   CZECHIFY_MIN_DAYS_LEFT refresh when fewer days than this remain (default 2)

set -uo pipefail

CONFIG="$HOME/.config/czechify/refresh.env"
# shellcheck source=/dev/null
[ -f "$CONFIG" ] && . "$CONFIG"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${CZECHIFY_REPO:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
REF="${CZECHIFY_REF:-curriculum/v1.2-plan}"
UDID="${CZECHIFY_IPHONE_UDID:-00008140-000208AC1EA3001C}"
MIN_DAYS="${CZECHIFY_MIN_DAYS_LEFT:-2}"
WORK="${CZECHIFY_WORKTREE:-$(dirname "$REPO")/.czechify-device-build}"
BUNDLE_ID="com.eminentsite.czechify"
MAC_APP="/Applications/Czechify.app"
LOG_DIR="$HOME/Library/Logs/Czechify"
STATE="$LOG_DIR/iphone_expiry"
LOCK="$LOG_DIR/refresh.lock"

# launchd starts with a minimal PATH. Flutter's own bin comes first: the
# Homebrew `dart` on this Mac is too old for the project.
export PATH="/opt/homebrew/share/flutter/bin:/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG="en_US.UTF-8"

FORCE=0; DO_MAC=1; DO_IPHONE=1
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --mac-only) DO_IPHONE=0 ;;
    --iphone-only) DO_MAC=0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
notify() {
  osascript -e "display notification \"$2\" with title \"Czechify: $1\"" >/dev/null 2>&1 || true
  log "NOTIFY $1: $2"
}

# One run at a time; a lock older than 3 hours is from a run that died.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +180 2>/dev/null)" ]; then
    rm -rf "$LOCK" && mkdir "$LOCK"
  else
    log "Another refresh is running; skipping."; exit 0
  fi
fi
trap 'rm -rf "$LOCK"' EXIT

# Seconds until the profile embedded in an app expires; empty if unreadable.
profile_expiry_epoch() {
  local profile="$1" date
  [ -f "$profile" ] || return 0
  date="$(security cms -D -i "$profile" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null)" || return 0
  [ -n "$date" ] && date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$date" +%s 2>/dev/null
}
days_left() {  # $1 = expiry epoch (may be empty)
  [ -n "$1" ] || { echo -1; return; }
  echo $(( ($1 - $(date +%s)) / 86400 ))
}
needs_refresh() {  # $1 = days left
  [ "$FORCE" = 1 ] || [ "$1" -lt "$MIN_DAYS" ]
}

prepare_worktree() {
  [ -n "${PREPARED:-}" ] && return 0
  log "Preparing build worktree at $WORK ($REF)"
  if [ ! -d "$WORK/.git" ] && [ ! -f "$WORK/.git" ]; then
    git -C "$REPO" worktree add --detach "$WORK" "$REF" || return 1
  else
    git -C "$WORK" checkout --detach --force "$REF" || return 1
    git -C "$WORK" clean -fdq -e build -e .dart_tool -e Pods || true
  fi
  # Untracked config the build needs: the production backend's public keys.
  cp "$REPO/env/prod.json" "$WORK/env/prod.json" || return 1
  (cd "$WORK" && flutter pub get >/dev/null) || return 1
  log "Building $(git -C "$WORK" log --oneline -1)"
  PREPARED=1
}

refresh_mac() {
  local expiry left built new_expiry
  expiry="$(profile_expiry_epoch "$MAC_APP/Contents/embedded.provisionprofile")"
  left="$(days_left "$expiry")"
  log "Mac app: $left day(s) left"
  needs_refresh "$left" || return 0

  prepare_worktree || { notify "Mac refresh failed" "Could not prepare the source. See $LOG_DIR."; return 1; }
  (
    cd "$WORK" || exit 1
    # arm64 only: Xcode 27's lipo rejects Flutter's two-architecture check,
    # and this Mac is Apple Silicon.
    FLUTTER_XCODE_ARCHS=arm64 flutter build macos --config-only --release \
      --dart-define-from-file=env/prod.json &&
    xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
      -configuration Release -derivedDataPath build/macos \
      -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
  ) > "$LOG_DIR/mac-build.log" 2>&1
  built="$WORK/build/macos/Build/Products/Release/Czechify.app"
  if ! grep -q "BUILD SUCCEEDED" "$LOG_DIR/mac-build.log" || [ ! -d "$built" ]; then
    explain_failure "$LOG_DIR/mac-build.log" "Mac"
    return 1
  fi
  new_expiry="$(profile_expiry_epoch "$built/Contents/embedded.provisionprofile")"
  codesign --verify --deep --strict "$built" || { notify "Mac refresh failed" "The new build is not signed correctly."; return 1; }

  # Swap the bundle in place. A running copy keeps working; the new build is
  # used from its next launch. Learner data lives outside the bundle.
  rm -rf "$MAC_APP.new" && ditto "$built" "$MAC_APP.new" &&
    rm -rf "$MAC_APP" && mv "$MAC_APP.new" "$MAC_APP" ||
    { notify "Mac refresh failed" "Could not replace $MAC_APP."; return 1; }
  log "Mac app installed; valid for $(days_left "$new_expiry") day(s)"
  notify "Mac app refreshed" "Valid until $(date -r "$new_expiry" '+%a %d %b')."
}

iphone_available() {
  xcrun devicectl list devices 2>/dev/null | grep "$UDID" | grep -q "available"
}

refresh_iphone() {
  local expiry left built new_expiry
  expiry="$(cat "$STATE" 2>/dev/null)"
  left="$(days_left "$expiry")"
  log "iPhone app: $left day(s) left (last recorded install)"
  needs_refresh "$left" || return 0

  if ! iphone_available; then
    notify "iPhone needs a refresh" "Connect and unlock the iPhone (or put it on the same Wi-Fi). The app stops opening in $((left < 0 ? 0 : left)) day(s)."
    return 1
  fi
  prepare_worktree || { notify "iPhone refresh failed" "Could not prepare the source. See $LOG_DIR."; return 1; }
  (
    cd "$WORK" || exit 1
    flutter build ios --config-only --release --dart-define-from-file=env/prod.json &&
    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
      -configuration Release -destination "id=$UDID" \
      -derivedDataPath build/ios-device \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
  ) > "$LOG_DIR/iphone-build.log" 2>&1
  built="$WORK/build/ios-device/Build/Products/Release-iphoneos/Runner.app"
  if ! grep -q "BUILD SUCCEEDED" "$LOG_DIR/iphone-build.log" || [ ! -d "$built" ]; then
    explain_failure "$LOG_DIR/iphone-build.log" "iPhone"
    return 1
  fi
  new_expiry="$(profile_expiry_epoch "$built/embedded.mobileprovision")"
  if ! xcrun devicectl device install app --device "$UDID" "$built" \
      > "$LOG_DIR/iphone-install.log" 2>&1; then
    notify "iPhone install failed" "Unlock the iPhone and keep it nearby; it will be retried. See $LOG_DIR."
    return 1
  fi
  echo "$new_expiry" > "$STATE"
  log "iPhone app installed; valid for $(days_left "$new_expiry") day(s)"
  notify "iPhone app refreshed" "Valid until $(date -r "$new_expiry" '+%a %d %b')."
}

# Turns the usual failures into something actionable.
explain_failure() {
  local logfile="$1" what="$2"
  if grep -qiE "No Accounts|not signed in|account.*expired|authentication" "$logfile"; then
    notify "$what refresh failed" "Open Xcode > Settings > Accounts and sign in to your Apple ID again."
  elif grep -qiE "maximum number of|App ID limit|too many" "$logfile"; then
    notify "$what refresh failed" "Apple's free-account app limit was reached. See $LOG_DIR."
  else
    notify "$what refresh failed" "Build error. The current app keeps working until it expires. See $logfile."
  fi
  grep -E "error:" "$logfile" | head -5 | while read -r line; do log "  $line"; done
}

log "=== Czechify device refresh (force=$FORCE) ==="
status=0
[ "$DO_MAC" = 1 ] && { refresh_mac || status=1; }
[ "$DO_IPHONE" = 1 ] && { refresh_iphone || status=1; }
log "=== done (status $status) ==="
exit $status
