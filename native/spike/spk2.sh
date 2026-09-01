#!/usr/bin/env zsh
# §11 SPK-2 — deletion characterisation ONLY.
#
# Standing order (§8.3): deletions are out of V1 by decision. No tombstone persistence, no
# dormant contract, the anchor advances past deletion events. This step feeds the §8.3
# reconciliation fast-follow design and nothing else.
#
# The question: does the deleted set carry the CORRELATION uuid, or the child quantity uuids?
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

step "1 · settle: drain any outstanding delta so the anchor is current"
launch "$READER" -spikeCatchUp -spikeStatus

step "2 · writer: save one correlation — this is the one that gets deleted"
launch "$WRITER" -writerSaveNow -writerList

step "3 · reader: capture it (note the correlation UUID prefix), then terminate"
launch "$READER" -spikeCatchUp -spikeStatus

step "4 · writer: delete that correlation"
launch "$WRITER" -writerDeleteLast

step "5 · reader: relaunch → strict-load → resume. WHAT DOES THE DELETED SET CARRY?"
launch "$READER" -spikeCatchUp -spikeStatus

step "6 · reader: does the deletion repeat after the commit?"
launch "$READER" -spikeCatchUp -spikeStatus

cat <<'EOF'

── What to read off this
   step 5  deletedReported=N and the deletedUuid prefix(es).
           If a prefix equals step 3's queuedCorrelationUuid -> the deleted set carries the
           CORRELATION uuid, which is the fact the §8.3 fast-follow needs.
           If it does not -> the child quantity uuids are being reported instead, which is
           exactly the child->correlation mapping trap round one identified.
   step 6  deletedReported=0 expected — the anchor advanced past it.
   throughout  pending must NOT drop: V1 ignores deletions, the row stays queued (§8.3).
EOF
