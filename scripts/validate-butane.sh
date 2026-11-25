#!/usr/bin/env bash
# Offline check: base and each fetched overlay compile; merged output has the essentials.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
load_env
require jq envsubst
mkdir -p "$BUILD_DIR"
if [ ! -x "${BUILD_DIR}/butane" ] && ! command -v butane >/dev/null 2>&1; then
  [ "$(uname -s)" = Linux ] || { warn "butane unavailable; skipping"; exit 0; }
  ensure_butane >/dev/null
fi
export NODE_HOSTNAME="ci-test"
export SSH_AUTHORIZED_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA ci@test"
base="${BUILD_DIR}/validate-base.json"
compile_butane "${REPO_ROOT}/butane/bluefin.bu" "$base" NODE_HOSTNAME SSH_AUTHORIZED_KEY
jq -e '.passwd.users[0].name == "root" and (.passwd.users[0].sshAuthorizedKeys | length) == 1
  and ([.systemd.units[].name] | index("sshd.service") != null)' "$base" >/dev/null \
  || die "base Ignition is missing the root key or sshd.service"
for f in "${REPO_ROOT}"/butane/overlays/*.bu "${REPO_ROOT}"/butane/overlays/server/*.bu; do
  [ -e "$f" ] || continue
  compile_butane "$f" "${BUILD_DIR}/validate-overlay.json"
  jq -n --slurpfile base "$base" --slurpfile overlay "${BUILD_DIR}/validate-overlay.json" \
    -f "${SCRIPT_DIR}/lib/merge-ignition.jq" >/dev/null || die "merge failed: $f"
  log "overlay OK: $(basename "$f")"
done
log "butane validation passed"
