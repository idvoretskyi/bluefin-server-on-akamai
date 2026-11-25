#!/usr/bin/env bash
#
# upload-image.sh — upload the boot disk built by build-bootdisk.sh as a private
# Linode image and print its `private/<id>` (set it as IMAGE_ID).
#
# IMAGE_FILE overrides the newest build/bluefin-server-akamai-boot_*.img.gz.
# The image is flagged cloud-init so the Metadata service (Ignition user data)
# is available. The upload limit is 6 GiB; the boot disk is ~100 MiB.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

load_env
require linode-cli du find
: "${REGION:?set REGION in .env}"

IMAGE_FILE="${IMAGE_FILE:-$(find "$BUILD_DIR" -name 'bluefin-server-akamai-boot_*.img.gz' 2>/dev/null | sort -V | tail -n1)}"
[ -f "$IMAGE_FILE" ] || die "no boot disk found; run 'make bootdisk' first (or set IMAGE_FILE)"
[ "$(du -b "$IMAGE_FILE" | cut -f1)" -le $((6 * 1024 * 1024 * 1024)) ] || die "image exceeds Linode's 6 GiB upload limit"

IMAGE_LABEL="${LABEL:-bluefin}-$(basename "$IMAGE_FILE" .img.gz | sed 's/^bluefin-server-akamai-boot_//')"
log "uploading ${IMAGE_FILE} as '${IMAGE_LABEL}' to ${REGION}"
linode-cli image-upload --label "$IMAGE_LABEL" --region "$REGION" --cloud-init \
  --description "Bluefin Server boot disk (bluefin-server-on-akamai)" "$IMAGE_FILE" >/dev/null \
  || die "image-upload failed"

# The CLI's table output is truncated; look the id up by label instead.
IMAGE_ID="$(linode-cli images list --is_public false --label "$IMAGE_LABEL" --text --no-headers --format id 2>/dev/null | tail -n1)"
[ -n "$IMAGE_ID" ] || die "could not find the uploaded image; run 'linode-cli images list'"
image_status() { linode-cli images view "$IMAGE_ID" --text --no-headers --format status 2>/dev/null | head -n1; }
log "waiting for ${IMAGE_ID} to become available"
for _ in $(seq 1 60); do
  [ "$(image_status)" = available ] && break
  sleep 10
done
[ "$(image_status)" = available ] || die "${IMAGE_ID} did not become available"
log "set IMAGE_ID in .env and tofu/terraform.tfvars"
printf 'IMAGE_ID=%s\n' "$IMAGE_ID"
