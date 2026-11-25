# Butane configs

- `bluefin.bu`: base config (hostname, root SSH key, sshd enabled).
- `overlays/*.bu`: optional fragments deep-merged onto the base with
  `OVERLAY=<name>` (see `scripts/lib/merge-ignition.jq`; base and overlay must
  not define the same file path or unit name).

Fetch the server repo's own profile templates with `make overlays`
(`home-server`, `homelab-control-plane`, ...); they land in `overlays/server/` (use `OVERLAY=server/home-server`) and
are not committed.
