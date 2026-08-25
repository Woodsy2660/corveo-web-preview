#!/usr/bin/env zsh
# §11 SPK-close — end-to-end mini-loop.
# configure -> authorise (set Q) -> install both quantity observers -> anchored query ->
# commit anchor+payload -> terminate -> writer: one current, one backdated, one deletion ->
# relaunch -> resume.
set -o pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEV="${1:-$(xcrun devicectl list devices 2>/dev/null | grep -i connected \
      | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)}"
READER=dev.lucab.bpspike
WRITER=dev.lucab.bpwriter
launch() {
  local bundle="$1"; shift; sleep 2
  local noarm=(); [[ "$bundle" == "$READER" ]] && noarm=(-spikeNoAutoArm)
  xcrun devicectl --timeout 120 device process launch --device "$DEV" --console \
    --terminate-existing "$bundle" -- "${noarm[@]}" "$@" 2>&1 \
    | sed -n '/-CLI begin/,/-CLI end/p' | sed 's/^/    /'
}
step() { print -P "\n%F{cyan}── $1%f"; }

step "1 · clean state, configure, arm both quantity observers, bootstrap"
launch "$READER" -spikeWipeStore -spikeConfigure -spikeImportStartDaysBack 30 \
                 -spikeStartObserving -spikeCatchUp -spikeStatus -spikeSources

step "2 · terminate. writer: one current, one backdated, one deletion"
launch "$WRITER" -writerSaveNow -writerSaveBackdated7d
launch "$WRITER" -writerDeleteLast

step "3 · relaunch → resume. exact UUIDs, deletion characterised"
launch "$READER" -spikeCatchUp -spikeStatus

step "4 · no repeats after commit"
launch "$READER" -spikeCatchUp -spikeStatus

cat <<'EOF'

── Pass criteria (§11 SPK-close)
   step 3  the two new correlation UUIDs returned exactly once; deletedReported names the
           correlation deleted in step 2
   step 4  returned=0 queued=0 deletedReported=0 — nothing repeats after the commit
EOF
