#!/usr/bin/env zsh
# §11 SPK-1 — resumable correlation anchor, one process launch per step.
#
# Each step is a separate launch, so the "terminate the process for real" between the anchor
# commit and the resume is structural rather than remembered. Run it verbatim on the
# acceptance device later; the sequence does not change.
#
# The two authorisation sheets are NOT scripted — open each app once and grant, then re-run.
#
#   ./spike/spk1.sh [device-udid]
set -o pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DEV="${1:-$(xcrun devicectl list devices 2>/dev/null | grep -i connected \
      | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
      | head -1)}"
[[ -z "$DEV" ]] && { echo "!! no connected device"; exit 1; }

READER=dev.lucab.bpspike
WRITER=dev.lucab.bpwriter

launch() {
  local bundle="$1"; shift
  sleep 2   # let the previous process finish exiting; --terminate-existing races it otherwise
  local noarm=()
  [[ "$bundle" == "$READER" ]] && noarm=(-spikeNoAutoArm)
  xcrun devicectl --timeout 120 device process launch --device "$DEV" --console \
    --terminate-existing "$bundle" -- "${noarm[@]}" "$@" 2>&1 \
    | sed -n '/-CLI begin/,/-CLI end/p' | sed 's/^/    /'
}

step() { print -P "\n%F{cyan}── $1%f"; }

step "0 · environment"
xcrun devicectl --timeout 120 device process launch --device "$DEV" --console \
  --terminate-existing "$READER" -- -spikeEnvReport 2>&1 \
  | sed -n '/SPIKE-ENV begin/,/SPIKE-ENV end/p' | sed 's/^/    /'

sleep 2
step "1 · reader: authorisation status + initial state"
launch "$READER" -spikeAuthStatus -spikeStatus

step "2 · reader: wipe store, configure(enrolmentRef, importStart = 30 d back), arm"
launch "$READER" -spikeWipeStore -spikeConfigure -spikeImportStartDaysBack 30 \
                 -spikeStartObserving -spikeConfigureConflict -spikeStatus

step "3 · writer: seed one synthetic correlation so the bootstrap rule can complete (§5.3)"
launch "$WRITER" -writerSaveNow

step "4 · reader: nil-anchor catch-up — commits the anchor into the real EngineState JSON"
launch "$READER" -spikeCatchUp -spikeStatus -spikeSources

print -P "\n%F{yellow}   ↑ process terminated. Everything below is a fresh process.%f"

step "5 · writer: one CURRENT and one 7-DAY-BACKDATED correlation"
launch "$WRITER" -writerSaveNow -writerSaveBackdated7d -writerList

step "6 · reader: relaunch → strict-load → resume anchored query  ← LOAD-BEARING"
launch "$READER" -spikeCatchUp -spikeStatus -spikeSources

step "7 · reader: third query must be empty"
launch "$READER" -spikeCatchUp -spikeStatus

cat <<'EOF'

── Pass criteria (§11 SPK-1)
   step 6  queued=2, and the two correlation UUID prefixes differ from step 4's
   step 7  returned=0 queued=0, anchorCommitted=true (anchors advance on empty deltas)
   steps 6-7  anchorPersisted=true throughout, load=ok — the anchor survived a real
              terminate/relaunch through the two-generation store

   Anything else: stop, keep the raw output, and do not build on it.
EOF
