#!/usr/bin/env bash
#
# dev-initrd-overlay.sh — pack bluefin-ignition-credentials from a local
# projectbluefin/server checkout into build/dev-overlay.img, for
#   EXTRA_INITRD=build/dev-overlay.img make bootdisk
# Needed only until a release ships the Linode Metadata source.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
require cpio find
server="${1:?usage: dev-initrd-overlay.sh <path to projectbluefin/server>}"
src="${server}/files/initrd-ignition/usr/libexec/bluefin-ignition-credentials"
[ -f "$src" ] || die "not found: ${src}"
mkdir -p "$BUILD_DIR"
w="$(mktemp -d)"; trap 'rm -rf "$w"' EXIT
install -D -m 0755 "$src" "${w}/usr/libexec/bluefin-ignition-credentials"
( cd "$w" && find . | cpio -o -H newc --quiet ) > "${BUILD_DIR}/dev-overlay.img"
log "wrote ${BUILD_DIR}/dev-overlay.img"
