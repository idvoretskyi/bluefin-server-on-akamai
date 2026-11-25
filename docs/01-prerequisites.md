# Prerequisites and open questions

This repo only deploys; the OS-side work lives in `projectbluefin/server`.

## 1. Firmware: UEFI or BIOS (decides everything)

Bluefin's install, A/B update and boot-counting paths need UEFI (signed UKI, systemd-boot). Linode instances have historically booted legacy BIOS. Test first with a minimal UEFI-only image on a nanode.

| Result | Consequence |
|---|---|
| UEFI works | Upload the installed-disk image directly (this repo's design). |
| BIOS only | Only the diskless path (iPXE boots the UKI kernel and initrd) is possible: no install, no sysupdate, no boot counting. This repo's `linode_instance_config` would need a different boot method. |

## 2. Server-side changes needed

1. An Akamai disk image element (`bluefin-server-akamai_<ver>.img.gz`, at most 6 GiB, `console=ttyS0,19200n8` for Lish, virtio drivers in the initrd).
2. An Akamai source in `bluefin-ignition-credentials`: when the SMBIOS vendor is Linode/Akamai, fetch `user_data` from `http://169.254.169.254` (token PUT first) and stage it as `/run/ignition/user.ign`. Open question: require an Ignition-key signature, or trust the per-tenant Metadata service.
3. A short skill doc in the server repo, listed in `docs/skills/index.md`.

Until the image exists, point `IMAGE_SOURCE` at a locally built disk image.
