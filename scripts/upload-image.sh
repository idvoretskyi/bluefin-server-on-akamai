#!/usr/bin/env bash
#
# upload-image.sh — one-time upload of the Bluefin Server Akamai disk image as a
# private Linode image. Prints `private/<id>` for IMAGE_ID.
#
# The image is a raw whole-disk image (ESP + A/B /usr + verity + root), gzipped,
# at most 6 GiB. Source: IMAGE_SOURCE (local file or URL), else the
# bluefin-server-akamai_<ver>.img.gz asset of the server release, whose
# SHA256SUMS.gpg is verified when gpg and the image keyring are available.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

load_env
require linode-cli du
: "${REGION:?set REGION in .env}"
: "${LABEL:=bluefin}"
: "${BLUEFIN_VERSION:=latest}"
: "${IMAGE_SOURCE:=}"

mkdir -p "$BUILD_DIR"
if [ -z "$IMAGE_SOURCE" ]; then
  require gh
  tag=()
  [ "$BLUEFIN_VERSION" = latest ] || tag=("v${BLUEFIN_VERSION#v}")
  log "downloading Akamai image from projectbluefin/server (${BLUEFIN_VERSION})"
  gh release download "${tag[@]}" --repo projectbluefin/server \
    --pattern 'bluefin-server-akamai_*.img.gz' --pattern 'SHA256SUMS' --pattern 'SHA256SUMS.gpg' \
    --dir "$BUILD_DIR" --clobber \
    || die "release has no Akamai image yet; set IMAGE_SOURCE to a local file or URL"
  if [ -n "${IMAGE_KEYRING:-}" ] && command -v gpg >/dev/null 2>&1; then
    gpg --no-default-keyring --keyring "$IMAGE_KEYRING" --verify "${BUILD_DIR}/SHA256SUMS.gpg" "${BUILD_DIR}/SHA256SUMS" \
      || die "SHA256SUMS signature check failed"
  else
    warn "IMAGE_KEYRING not set: skipping SHA256SUMS signature check"
  fi
  ( cd "$BUILD_DIR" && grep -F 'bluefin-server-akamai_' SHA256SUMS | sha256sum -c - ) || die "checksum mismatch"
  IMAGE_FILE="$(find "$BUILD_DIR" -name "bluefin-server-akamai_*.img.gz" | sort | tail -n1)"
elif [[ "$IMAGE_SOURCE" =~ ^https?:// ]]; then
  require curl
  IMAGE_FILE="${BUILD_DIR}/$(basename "$IMAGE_SOURCE")"
  curl -fL -o "$IMAGE_FILE" "$IMAGE_SOURCE" || die "download failed"
else
  IMAGE_FILE="$IMAGE_SOURCE"
fi
[ -f "$IMAGE_FILE" ] || die "image file not found: ${IMAGE_FILE}"

SIZE="$(du -b "$IMAGE_FILE" | cut -f1)"
[ "$SIZE" -le $((6 * 1024 * 1024 * 1024)) ] || die "image exceeds Linode's 6 GiB upload limit"

IMAGE_LABEL="${LABEL}-$(date +%Y%m%d)"
log "uploading ${IMAGE_FILE} as '${IMAGE_LABEL}' to ${REGION} (--cloud-init for the Metadata service)"
OUT="$(linode-cli image-upload --label "$IMAGE_LABEL" --region "$REGION" --cloud-init \
  --description "Bluefin Server (bluefin-server-on-akamai)" "$IMAGE_FILE" 2>&1)" \
  || die "image-upload failed:\n${OUT}"
printf '%s\n' "$OUT" >&2
IMAGE_ID="$(printf '%s\n' "$OUT" | grep -oE 'private/[0-9]+' | head -n1 || true)"
[ -n "$IMAGE_ID" ] || die "could not parse image id; run 'linode-cli images list'"
log "set IMAGE_ID in .env and tofu/terraform.tfvars"
printf 'IMAGE_ID=%s\n' "$IMAGE_ID"
