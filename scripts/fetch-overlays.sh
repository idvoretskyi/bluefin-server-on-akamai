#!/usr/bin/env bash
#
# fetch-overlays.sh — download the homelab / home-server Butane templates from
# the projectbluefin/server release into butane/overlays/.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
load_env
require gh
: "${BLUEFIN_VERSION:=latest}"
tag=()
[ "$BLUEFIN_VERSION" = latest ] || tag=("v${BLUEFIN_VERSION#v}")
dest="${REPO_ROOT}/butane/overlays"
mkdir -p "$dest"
log "downloading *.bu templates from projectbluefin/server (${BLUEFIN_VERSION})"
gh release download "${tag[@]}" --repo projectbluefin/server --pattern '*.bu' --dir "$dest" --clobber \
  || die "no .bu assets found on that release"
ls "$dest"
