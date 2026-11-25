#!/usr/bin/env bash
#
# e2e-linode.sh — deploy with OpenTofu, wait for SSH, assert, always destroy.
# Needs LINODE_TOKEN, IMAGE_ID and SSH_AUTHORIZED_KEY (+ the matching private key
# in the agent). Costs a few cents. Pass --keep to skip teardown.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
load_env
require tofu ssh jq
need_var LINODE_TOKEN; need_var IMAGE_ID
KEEP=0; [ "${1:-}" = "--keep" ] && KEEP=1

"${SCRIPT_DIR}/render-ignition.sh"
suffix="$(date +%s)"
TF=(tofu -chdir="${REPO_ROOT}/tofu")
VARS=(-var "image_id=${IMAGE_ID}" -var "region=${E2E_REGION:-${REGION:-us-ord}}"
      -var "label=bluefin-e2e-${suffix}" -var "instance_type=${INSTANCE_TYPE:-g6-standard-2}"
      -var "ignition_path=${BUILD_DIR}/ignition.json")

teardown() {
  if [ "$KEEP" -eq 1 ]; then warn "--keep set: leaving bluefin-e2e-${suffix} running"; return; fi
  log "destroying e2e resources"
  "${TF[@]}" destroy -auto-approve "${VARS[@]}" >/dev/null || warn "destroy failed; check 'linode-cli linodes list'"
}
trap teardown EXIT

"${TF[@]}" init -input=false >/dev/null
"${TF[@]}" apply -auto-approve -input=false "${VARS[@]}"
IP="$("${TF[@]}" output -raw ip_address)"
SSH=(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes "root@${IP}")

log "waiting for SSH on ${IP}"
for _ in $(seq 1 60); do "${SSH[@]}" true 2>/dev/null && break; sleep 10; done
"${SSH[@]}" true || die "SSH never came up (check the Lish console)"

h="$("${SSH[@]}" hostname)"
[ "$h" = "${NODE_HOSTNAME:-bluefin-akamai}" ] || die "hostname mismatch: ${h}"
"${SSH[@]}" 'grep -q ^ID=bluefin-server /etc/os-release || grep -q bluefin /etc/os-release' || die "not a Bluefin Server node"
"${SSH[@]}" 'findmnt -no FSTYPE /usr | grep -qx erofs' || die "/usr is not erofs"
log "e2e passed"
