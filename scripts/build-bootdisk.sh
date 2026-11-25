#!/usr/bin/env bash
#
# build-bootdisk.sh — build the BIOS boot disk for a Bluefin Server release.
#
# Akamai/Linode boots legacy BIOS, so the signed-UKI/systemd-boot install path
# is unavailable. The supported shape is diskless: this disk carries the
# release's netboot kernel and initrd (taken from the netboot UKI, whose
# SHA256 is checked against SHA256SUMS) and the UKI's own kernel command line
# with rd.systemd.pull pointing at the release DDI. The initrd pulls the DDI
# into RAM and verifies SHA256SUMS.gpg against the keyring it ships; dm-verity
# pins /usr to the usrhash on the command line.
#
# Env: BLUEFIN_VERSION (default: latest release)  DDI_BASE_URL (default: the
# GitHub release)  EXTRA_INITRD (optional cpio overlay appended to the initrd,
# for testing an unreleased initrd change)  IGNITION_FILE (optional: embed this
# Ignition JSON as the ignition.config credential instead of using Metadata)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
load_env
require gh docker sha256sum gzip

: "${BLUEFIN_VERSION:=latest}"
repo=projectbluefin/server
if [ "$BLUEFIN_VERSION" = latest ]; then
  BLUEFIN_VERSION="$(gh release view --repo "$repo" --json tagName -q .tagName)"
fi
tag="v${BLUEFIN_VERSION#v}"; ver="${tag#v}"
: "${DDI_BASE_URL:=https://github.com/${repo}/releases/download/${tag}}"

dl="${BUILD_DIR}/release-${ver}"
mkdir -p "$dl"
uki="bluefin-server-netboot_${ver}.efi"
log "downloading ${uki} and SHA256SUMS from ${repo} ${tag}"
gh release download "$tag" --repo "$repo" --pattern "$uki" --pattern SHA256SUMS --pattern SHA256SUMS.gpg --dir "$dl" --clobber
( cd "$dl" && grep -F " *${uki}" SHA256SUMS | sha256sum -c - ) || die "UKI checksum mismatch"
if [ -n "${IMAGE_KEYRING:-}" ] && command -v gpgv >/dev/null 2>&1; then
  gpgv --keyring "$IMAGE_KEYRING" "$dl/SHA256SUMS.gpg" "$dl/SHA256SUMS" || die "SHA256SUMS signature check failed"
else
  warn "IMAGE_KEYRING not set: SHA256SUMS authenticity not verified here (the node still verifies the DDI)"
fi

img="bluefin-akamai-bootdisk:1"
docker build -q -t "$img" "${REPO_ROOT}/bootdisk" >/dev/null

out="bluefin-server-akamai-boot_${ver}.img"
envs=(-e "UKI=/work/release-${ver}/${uki}" -e "DDI_URL=${DDI_BASE_URL}/bluefin-server_${ver}.raw" -e "OUT=/work/${out}")
mounts=(-v "${BUILD_DIR}:/work" -v "${REPO_ROOT}/bootdisk/initrd-overlay:/initrd-overlay:ro" -v "${REPO_ROOT}/bootdisk/build-inner.sh:/build-inner.sh:ro")
if [ -n "${EXTRA_INITRD:-}" ]; then
  mounts+=(-v "$(readlink -f "$EXTRA_INITRD"):/extra.img:ro"); envs+=(-e EXTRA_INITRD=/extra.img)
fi
if [ -n "${IGNITION_FILE:-}" ]; then
  envs+=(-e "IGNITION_B64=$(base64 -w0 < "$IGNITION_FILE")")
fi
docker run --rm "${envs[@]}" "${mounts[@]}" -u "$(id -u):$(id -g)" "$img" /build-inner.sh
gzip -f -k "${BUILD_DIR}/${out}"
log "boot disk: ${BUILD_DIR}/${out}.gz ($(du -h "${BUILD_DIR}/${out}.gz" | cut -f1))"
