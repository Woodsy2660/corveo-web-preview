#!/usr/bin/env zsh
# §11 SPK-4 — anchor recovery against a REAL anchor and a POPULATED queue.
#
# The 12/12 store self-test already covers the M17 generation fallback and the hard INTERNAL
# when both generations are invalid, in a scratch directory. What it does not cover is §5.3's
# anchor-only reset: trigger (a), secure-unarchive failure at load, with real config, a real
# queue and real diagnostics that must all survive. That is M12, and P2 leans on it.
set -o pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEV="${1:-$(xcrun devicectl list devices 2>/dev/null | grep -i connected \
      | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)}"
READER=dev.lucab.bpspike
launch() {
  sleep 2
  xcrun devicectl --timeout 120 device process launch --device "$DEV" --console \
    --terminate-existing "$READER" -- -spikeNoAutoArm "$@" 2>&1 \
    | sed -n '/-CLI begin/,/-CLI end/p' | sed 's/^/    /'
}
step() { print -P "\n%F{cyan}── $1%f"; }

step "1 · baseline — record queue depth, anchor, config, diagnostics"
launch -spikeCatchUp -spikeStatus -spikeSources

step "2 · inject a corrupt anchorData, then terminate (trigger (a) fires at NEXT load)"
launch -spikeInjectCorruptAnchor -spikeStatus

step "3 · relaunch → loadStrict → the anchor-only reset must fire HERE"
launch -spikeStatus -spikeSources

step "4 · bounded importStart re-import must converge in foreground"
launch -spikeCatchUp -spikeStatus

step "5 · and settle — a second pass must add nothing"
launch -spikeCatchUp -spikeStatus

cat <<'EOF'

── Pass criteria (§5.3 anchor recovery / M12)
   step 3  anchorPersisted=false, bootstrapComplete=false, anchorResets=1,
           anchorResetReason=UNARCHIVE_FAILED
           AND config intact (state stays configured*), pending UNCHANGED from step 1,
           recentUuids UNCHANGED — the reset clears anchorData + bootstrapComplete and
           NOTHING else.
   step 4  re-import runs nil-anchor from importStart and re-queues nothing new:
           queued=0 because the recentUuids ring absorbs the replay, while returned>0
           shows the query really did re-read from importStart.
           REGRESSION GUARD (S3/D-002): anchorCommitted=true and bootstrapComplete=true
           MUST both hold here. If either is false the engine is stuck in bootstrap and
           will re-read the whole history on every wake — forever.
   step 5  returned=0 queued=0 bootstrapMode=false — converged, and the anchor is doing
           the work rather than the importStart re-read.
EOF
