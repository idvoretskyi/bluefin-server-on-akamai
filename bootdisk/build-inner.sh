#!/usr/bin/env bash
# Runs inside the bootdisk container (or natively with the same tools).
# Inputs (env): UKI, DDI_URL, OUT, [EXTRA_INITRD], [IGNITION_B64]
# Builds a BIOS-bootable raw disk: MBR + one FAT32 partition + syslinux + the
# netboot UKI's kernel and initrd, booted with the UKI's own cmdline whose
# rd.systemd.pull points at the release's DDI.
set -euo pipefail
: "${UKI:?}" "${DDI_URL:?}" "${OUT:?}"
w="$(mktemp -d)"; trap 'rm -rf "$w"' EXIT

for s in linux initrd cmdline; do
  objcopy -O binary --only-section=".$s" "$UKI" "$w/$s"
  [ -s "$w/$s" ] || { echo "UKI has no .$s section" >&2; exit 1; }
done

cmd="$(tr -d '\0\n' < "$w/cmdline")"
# <options>,bootorigin:rootdisk:<name>.raw -> <options>:rootdisk:<explicit URL>
case "$cmd" in
  *,bootorigin:rootdisk:*) ;;
  *) echo "unexpected UKI cmdline (no bootorigin pull): $cmd" >&2; exit 1 ;;
esac
cmd="$(printf '%s' "$cmd" | sed -E "s#,bootorigin:rootdisk:[^ ]+#:rootdisk:${DDI_URL}#")"
# Lish is a virtual serial line: ttyS0 first so it is /dev/console.
cmd="$(printf '%s' "$cmd" | sed -E 's# console=tty0##; s#console=ttyS0,115200#console=tty0 console=ttyS0,115200#')"
if [ -n "${IGNITION_B64:-}" ]; then
  cmd="$cmd systemd.set_credential_binary=ignition.config:${IGNITION_B64}"
fi

cp "$w/linux" "$w/vmlinuz"; cp "$w/initrd" "$w/initrd.img"
# Boot-disk overlay: a cpio appended to the UKI's initrd (the kernel unpacks
# concatenated archives in order, so these files win).
( cd /initrd-overlay && find . | cpio -o -H newc --quiet ) > "$w/akamai.img"
initrds=initrd.img,akamai.img
if [ -n "${EXTRA_INITRD:-}" ]; then
  cp "$EXTRA_INITRD" "$w/extra.img"; initrds="$initrds,extra.img"
fi

{
  echo "SERIAL 0 115200"
  echo "CONSOLE 0"
  echo "DEFAULT bluefin"
  echo "TIMEOUT 1"
  echo "LABEL bluefin"
  echo "  KERNEL vmlinuz"
  echo "  INITRD $initrds"
  echo "  APPEND $cmd"
} > "$w/syslinux.cfg"
[ "$(wc -c < "$w/syslinux.cfg")" -lt 8192 ] || { echo "syslinux.cfg too large" >&2; exit 1; }

files=("$w/vmlinuz" "$w/initrd.img" "$w/akamai.img")
[ -z "${EXTRA_INITRD:-}" ] || files+=("$w/extra.img")
bytes=$(stat -c %s "${files[@]}" | awk '{s+=$1} END{print s}')
mib=$(( bytes / 1048576 + 40 ))          # slack for FAT overhead and syslinux
total=$(( mib + 2 ))                      # 1 MiB MBR gap + 1 MiB tail

rm -f "$OUT"
truncate -s "${total}M" "$OUT"
echo 'start=2048, type=c, bootable' | sfdisk --quiet "$OUT"
off=$(( 2048 * 512 ))
mkfs.vfat --offset 2048 -n BLUEFIN "$OUT" $(( (total - 1) * 1024 )) >/dev/null
export MTOOLS_SKIP_CHECK=1
for f in "${files[@]}" "$w/syslinux.cfg"; do
  mcopy -i "${OUT}@@${off}" "$f" "::$(basename "$f")"
done
syslinux --install --offset "$off" "$OUT"
dd if=/usr/lib/syslinux/mbr/mbr.bin of="$OUT" bs=440 count=1 conv=notrunc status=none
echo "wrote $OUT (${total} MiB); cmdline: $cmd" | sed -E 's#(ignition.config:)[A-Za-z0-9+/=]+#\1<redacted>#' >&2
