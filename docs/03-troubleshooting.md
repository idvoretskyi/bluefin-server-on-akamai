# Troubleshooting

## Watch the boot (Lish)

`ssh -t <linode-username>@lish-<region>.linode.com <instance-label>`. Lish only accepts the keys in your profile's "Lish" authorized keys (`linode-cli profile update --authorized_keys ...`), not the account SSH keys; changes can take a minute. Attach before rebooting to see the whole boot: the node prints a failure summary and reboots after 60 s.

## Symptoms

| Symptom | Cause |
|---|---|
| `Could not resolve hostname` in the pull | The initrd has no `/etc/resolv.conf`; use a boot disk from this repo (it ships the symlink) |
| Connection refused on :22 after boot | Ignition did not run (no user data, or not base64): check `journalctl -b -u bluefin-ignition-credentials` on the node, and that the image was uploaded with `--cloud-init` |
| `fetching the Linode Metadata token failed` | Region without Metadata, or image not cloud-init flagged |
| `NOT ENOUGH RAM FOR A DISKLESS BOOT` | Use a larger plan |
| Linode shows `offline` after a failed boot | The guest rebooted and Linode did not restart it; `linode-cli linodes boot <id>` |
| `Invalid count argument` in tofu | Fixed: the state disk size comes from the instance type, not the instance |
