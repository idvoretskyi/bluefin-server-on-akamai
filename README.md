# bluefin-server-on-akamai

Zero-touch [Bluefin Server](https://github.com/projectbluefin/server) on [Akamai Cloud (Linode)](https://www.linode.com/), provisioned with [OpenTofu](https://opentofu.org/) and configured with Ignition compiled from [Butane](https://coreos.github.io/butane/). Inspired by [flatcar-on-akamai](https://github.com/idvoretskyi/flatcar-on-akamai).

> **Status:** verified live on Akamai (`us-ord`, `g6-standard-2`, release 26.11.2806): the node boots, pulls and verifies the OS image, applies Ignition from the Metadata service, SSH works, `/usr` is dm-verity erofs, and `/var` on the second disk survives a reboot. Until a server release ships the Linode Metadata source, the boot disk needs a one-line dev overlay (see [docs/02-deploy.md](docs/02-deploy.md)).

## Why diskless

Linode instances boot **legacy BIOS** (probed: no `/sys/firmware/efi`, `direct-disk` boots the MBR). Bluefin's UEFI install, A/B update and boot counting paths cannot run, so the node runs the supported diskless BIOS flow:

```
 make bootdisk                       make apply (OpenTofu)
┌──────────────────────────┐   ┌─────────────────────────────────────┐
│ syslinux boot disk (113M)│   │ sda  boot disk (private image)      │
│  kernel + initrd from the│   │ sdb  state disk  -> /var (xfs)      │
│  netboot UKI, its own    │   │ metadata.user_data = Ignition       │
│  cmdline, pull URL ->    │   └──────────────┬──────────────────────┘
│  GitHub release DDI      │                  │ boot
└──────────────────────────┘   initrd pulls bluefin-server_<ver>.raw into RAM,
                               verifies SHA256SUMS.gpg, dm-verity pins /usr;
                               Ignition user data comes from the Metadata
                               service; ssh root@<ip>
```

The OS is re-pulled on every boot; persistent data lives on `sdb`. Changing versions means building and uploading a new boot disk.

## Quick start

```sh
cp .env.example .env && $EDITOR .env      # SSH_AUTHORIZED_KEY, REGION, BLUEFIN_VERSION ...
export LINODE_TOKEN=...                   # Linodes RW + Images RW
make bootdisk                             # needs docker + gh
make image                                # prints IMAGE_ID=private/<id>; put it in .env
make ignition                             # OVERLAY=state-disk by default
cp tofu/terraform.tfvars.example tofu/terraform.tfvars   # set image_id
make init plan apply
make ssh
```

More: [docs/01-overview.md](docs/01-overview.md), [docs/02-deploy.md](docs/02-deploy.md), [docs/03-troubleshooting.md](docs/03-troubleshooting.md).

## Checks

`make validate` is offline. `make e2e` deploys, asserts over SSH (hostname, erofs `/usr`, `/var` on `sdb`, `/var` survives a reboot) and destroys (`ARGS=--keep` to keep it). A run costs a few cents.

MIT licensed.
