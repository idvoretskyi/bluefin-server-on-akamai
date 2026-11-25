# Deploy

Prerequisites: `tofu`, `linode-cli`, `docker`, `gh`, `jq`, `envsubst`; a token with Linodes RW and Images RW.

1. **Configure** `.env` (copy `.env.example`): `SSH_AUTHORIZED_KEY`, `REGION` (a Metadata region such as `us-ord`), `INSTANCE_TYPE` (`g6-standard-2` or larger).
2. **Boot disk**: `make bootdisk` builds `build/bluefin-server-akamai-boot_<ver>.img.gz` (about 70 MB).
   - Until a server release includes the Linode Metadata source: `scripts/dev-initrd-overlay.sh ~/git/projectbluefin/server`, then `EXTRA_INITRD=build/dev-overlay.img make bootdisk`.
3. **Upload**: `make image` uploads it as a private cloud-init-flagged image, waits until it is available and prints `IMAGE_ID=private/<id>`.
4. **Ignition**: `make ignition` compiles `butane/bluefin.bu` plus `OVERLAY` (default `state-disk`). Other overlays: `make overlays` fetches the server's `home-server`/`homelab-*` templates into `butane/overlays/server/`; use `OVERLAY=server/home-server`.
5. **Apply**: copy `tofu/terraform.tfvars.example`, set `image_id`, then `make init plan apply`. The boot disk is `sda` (1 GB); `sdb` takes the rest of the plan's disk (`state_disk_mb`, 0 disables it).
6. **Connect**: `make ssh` (root, key only). First boot takes a few minutes while the image is pulled.

Update: build and upload a new boot disk, change `image_id`, apply. Tear down: `make destroy`, then delete the image with `linode-cli images delete`.
