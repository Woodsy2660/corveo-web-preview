#!/usr/bin/env zsh
# Build and install the three §11 spike apps onto a paired device.
#
# Prerequisites this script does NOT do for you:
#   1. Developer Mode on the device: Settings → Privacy & Security → Developer Mode.
#   2. An Apple ID in Xcode → Settings → Accounts (free personal team is enough).
# It checks both and tells you which is missing rather than failing obscurely.
#
#   ./spike/run-on-device.sh                 # auto-pick the only connected device
#   ./spike/run-on-device.sh <device-udid>   # or name one
#   DEVELOPMENT_TEAM=XXXXXXXXXX ./spike/run-on-device.sh   # if you have several teams
set -e -o pipefail

# xcode-select on this Mac still points at the Command Line Tools; override until it is
# switched with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ROOT="${0:A:h}"
DERIVED="${TMPDIR:-/tmp}/bpspike-derived"
APPS=(BPSpikeQ BPSpikeC BPWriter)

# The signing certificate does NOT need to exist yet: -allowProvisioningUpdates mints it on
# the first device build. What xcodebuild cannot infer is the team, so that is the real gate.
TEAM="${DEVELOPMENT_TEAM:-$(grep -E '^DEVELOPMENT_TEAM *=' "$ROOT/Signing.xcconfig" \
        | head -1 | sed 's/.*= *//' | tr -d '[:space:]')}"
if [[ -z "$TEAM" ]]; then
  echo "!! No development team set."
  echo "   Put the 10-character Team ID on the DEVELOPMENT_TEAM line of"
  echo "     spike/Signing.xcconfig"
  echo "   (Xcode → Settings → Accounts → your Apple ID → the team row), or run:"
  echo "     DEVELOPMENT_TEAM=XXXXXXXXXX ./spike/run-on-device.sh"
  exit 1
fi
echo "Team:   $TEAM"

if security find-identity -v -p codesigning 2>/dev/null | grep -qE "^ *0 valid identities found"; then
  echo "Note:   no signing certificate yet — -allowProvisioningUpdates will create one."
fi

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  # The State column can be several words ("connected (no DDI)"), so match the identifier
  # by shape rather than by position.
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | grep -i connected \
           | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
           | head -1)
fi
if [[ -z "$DEVICE" ]]; then
  echo "!! No connected device found. Plug one in and trust this Mac."
  xcrun devicectl list devices
  exit 1
fi
echo "Device: $DEVICE"

for app in $APPS; do
  echo "=== $app ==="
  xcodebuild -project "$ROOT/$app.xcodeproj" -scheme "$app" \
    -destination "id=$DEVICE" -configuration Debug \
    -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM" build | tail -3
  xcrun devicectl device install app --device "$DEVICE" \
    "$DERIVED/Build/Products/Debug-iphoneos/$app.app"
done

echo
echo "Installed. Trust the developer profile on the device if prompted:"
echo "  Settings → General → VPN & Device Management."
echo
echo "Reminder (§9.4): unless this is the dev iPhone on iOS 26.6+, every result here is"
echo "SIDECAR — development testing only. Nothing from it enters ADR-0004."
echo
echo "If provisioning fails on com.apple.developer.healthkit.background-delivery, that is"
echo "worth knowing rather than working around: swap SPIKE_READER_ENTITLEMENTS in"
echo "Signing.xcconfig to the no-background-delivery file and you are running T14 early."
