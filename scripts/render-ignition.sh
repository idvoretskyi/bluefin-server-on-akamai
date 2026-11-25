#!/usr/bin/env bash
#
# render-ignition.sh — compile butane/bluefin.bu (+ optional overlay) into
# build/ignition.json, injecting NODE_HOSTNAME and SSH_AUTHORIZED_KEY from .env.
#
# Usage: scripts/render-ignition.sh [--overlay NAME]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

load_env
: "${OVERLAY:=}"
while [ $# -gt 0 ]; do
  case "$1" in
    --overlay) OVERLAY="${2:?--overlay needs a value}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

need_var SSH_AUTHORIZED_KEY
: "${NODE_HOSTNAME:=bluefin-akamai}"
export NODE_HOSTNAME SSH_AUTHORIZED_KEY

require jq
mkdir -p "$BUILD_DIR"
ensure_butane >/dev/null
OUT="${BUILD_DIR}/ignition.json"

log "compiling base Butane -> Ignition"
compile_butane "${REPO_ROOT}/butane/bluefin.bu" "$OUT" NODE_HOSTNAME SSH_AUTHORIZED_KEY

if [ -n "$OVERLAY" ]; then
  src="${REPO_ROOT}/butane/overlays/${OVERLAY}.bu"
  [ -f "$src" ] || die "overlay not found: ${src} (try 'make overlays')"
  log "compiling overlay ${OVERLAY}"
  compile_butane "$src" "${BUILD_DIR}/overlay.json"
  jq -n --slurpfile base "$OUT" --slurpfile overlay "${BUILD_DIR}/overlay.json" \
    -f "${SCRIPT_DIR}/lib/merge-ignition.jq" > "${BUILD_DIR}/merged.json" || die "merge failed"
  mv "${BUILD_DIR}/merged.json" "$OUT"
fi

jq -e '.ignition.version' "$OUT" >/dev/null || die "output is not valid Ignition JSON"
log "wrote ${OUT} (overlay: ${OVERLAY:-none}, spec $(jq -r '.ignition.version' "$OUT"))"
