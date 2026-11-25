# Prerequisites and findings

This repo only deploys; the OS-side work lives in `projectbluefin/server`.

## Phase 1 findings (probed on a live nanode, us-ord, Debian 13)

| Check | Result |
|---|---|
| Firmware | **Legacy BIOS only.** No `/sys/firmware/efi`; the e820 map is SeaBIOS-style on a Q35 machine, DMI vendor `Linode`. Linode's docs say `direct-disk` boots the disk's MBR. |
| Disks | virtio-scsi (`QEMU_HARDDISK`), `sda`/`sdb` |
| Console | `ttyS0,19200n8` (Lish) |
| Metadata service | Works from the guest: `PUT /v1/token` (64-byte token), then `GET /v1/instance`, `/v1/user-data` with `Metadata-Token`. Needs a Metadata-capable region (us-ord is) and an image uploaded with `--cloud-init`. |

Consequence: the UEFI design (installed disk, systemd-boot, A/B updates, boot counting) cannot run on Akamai today. Only the diskless path Booty already supports for BIOS is possible: iPXE boots the netboot UKI's kernel and initrd sections, and the initrd pulls the signed OS DDI into RAM. No install, no sysupdate, no boot counting.

## Revised design

- A tiny BIOS-bootable boot disk (iPXE with an embedded script) replaces the full Akamai disk image. The script fetches the kernel and initrd (extracted from the release's netboot UKI) and passes the UKI's own `.cmdline` with the `rd.systemd.pull` URL pointing at the release.
- Persistent data lives on a second disk (`state-disk` overlay, `/dev/sdb` as `/var`); the OS itself is re-pulled on every boot. The instance needs enough RAM for the DDI (see the server's diskless-troubleshooting skill; `g6-standard-2` or larger).
- Ignition still arrives from the Metadata service, through a Linode source added to `bluefin-ignition-credentials` (trusted unsigned, only on a Linode).

## Server-side changes needed (separate PR, not started)

1. A Linode/Akamai Metadata source in `bluefin-ignition-credentials` (SMBIOS vendor `Linode`; token PUT, `user-data`, stage as `/run/ignition/user.ign`), with a unit test.
2. A way to build or publish the iPXE boot disk and the extracted kernel/initrd (or a Booty-style endpoint), plus a skill doc.
3. Serial console `ttyS0,19200n8` on the netboot cmdline for Lish.
