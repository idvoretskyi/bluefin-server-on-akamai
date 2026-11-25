# Overview

## What was probed (live nanode, us-ord)

| Check | Result |
|---|---|
| Firmware | Legacy BIOS (SeaBIOS on a Q35 machine; no `/sys/firmware/efi`; DMI vendor `Linode`) |
| Disks | virtio-scsi `sda`/`sdb` |
| Console | Lish on `ttyS0` |
| Metadata service | `PUT /v1/token`, then `GET /v1/user-data` with `Metadata-Token`; needs a Metadata region and an image uploaded with `--cloud-init` |

## Boot chain

1. `make bootdisk` downloads the release's `bluefin-server-netboot_<ver>.efi` (SHA256 checked against `SHA256SUMS`), extracts `.linux`, `.initrd` and `.cmdline`, rewrites `rd.systemd.pull` to the release's `bluefin-server_<ver>.raw` URL and writes a syslinux MBR disk.
2. The initrd pulls the image into RAM, verifies `SHA256SUMS.gpg` against the keyring baked into the initrd, and dm-verity pins `/usr` to the `usrhash=` on the command line.
3. `bluefin-ignition-credentials` reads user data from the Metadata service; Ignition applies it (root SSH key, `sshd.service`, hostname, the `/var` disk).

## Trust

- There is no Secure Boot on BIOS: the boot disk itself (kernel, initrd, command line) is the trust root, so keep the private image private. `IMAGE_KEYRING` lets `make bootdisk` verify `SHA256SUMS.gpg`.
- The OS image is verified on the node regardless of where it is served from.
- Ignition from the Metadata service is trusted unsigned (a per-instance link-local channel).

## Limits

No installed disk, no A/B `systemd-sysupdate`, no boot counting. RAM must hold the OS image plus the running system (`g6-standard-2` and larger).

## Boot disk overlay

`bootdisk/initrd-overlay/` is appended to the initrd. It currently adds `/etc/resolv.conf` (a symlink to the resolved stub): the stock initrd has none, so hostnames do not resolve and only IP-literal pull URLs worked. Debugged live: DHCP and the Linode DNS servers were fine, only the symlink was missing. The same fix is proposed for the server repo.
