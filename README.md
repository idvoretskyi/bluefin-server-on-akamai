# bluefin-server-on-akamai

Zero-touch [Bluefin Server](https://github.com/projectbluefin/server) on [Akamai Cloud (Linode)](https://www.linode.com/), provisioned with [OpenTofu](https://opentofu.org/) and configured with Ignition compiled from [Butane](https://coreos.github.io/butane/). Modelled on [flatcar-on-akamai](https://github.com/idvoretskyi/flatcar-on-akamai).

> **Status: scaffold.** The tooling validates offline (`make validate`) but has not been run against a live Linode yet. It depends on two changes in `projectbluefin/server` (see [docs/01-prerequisites.md](docs/01-prerequisites.md)): an Akamai disk image and a Metadata-service source for Ignition.

```
 one-time               per deploy
┌────────────┐   ┌───────────────────────────────────────────┐
│ make image │   │ make ignition  -> build/ignition.json      │
│ upload the │   │ make apply (OpenTofu):                     │
│ Akamai     │   │   linode_instance  metadata.user_data <----┘
│ disk image │   │   linode_instance_disk  <- private/<id>   │
│ private/id │   │   linode_instance_config  direct-disk     │
└────────────┘   │ first boot: node reads user_data, Ignition│
                 │ applies, then: ssh root@<ip>               │
                 └───────────────────────────────────────────┘
```

## Quick start

```sh
cp .env.example .env && $EDITOR .env     # REGION, SSH_AUTHORIZED_KEY, IMAGE_SOURCE ...
export LINODE_TOKEN=...                  # Linodes RW + Images RW
make image                               # then set IMAGE_ID in .env and tofu/terraform.tfvars
make ignition                            # OVERLAY=home-server after `make overlays`
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
make init plan apply
make ssh
```

## Differences from the Flatcar version

- **No Afterburn, no knuckle.** Bluefin ignores `ignition.*` kernel arguments (the command line is sealed in the signed UKI); configs arrive as credentials or from the Metadata service via a server-side source. Butane is the only generator.
- **No password, sshd off by preset.** The base config sets the root key and enables `sshd.service`.
- **Overlays** are the server's own `home-server` / `homelab-*` Butane templates (`make overlays`), merged onto the base.
- **Optional state disk** (`state_disk_mb`) for a persistent `/var`; pair it with an overlay that formats `/dev/sdb`.

## Docs

1. [Prerequisites and open questions](docs/01-prerequisites.md)

## Offline checks and e2e

`make validate` never contacts Linode. `make e2e` deploys, asserts over SSH, and always destroys (`ARGS=--keep` to debug).

MIT licensed.
