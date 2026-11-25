# merge-ignition.jq — merge an overlay Ignition 3.x document onto a base.
#
#   jq -n --slurpfile base base.json --slurpfile overlay overlay.json \
#     -f scripts/lib/merge-ignition.jq > merged.json
#
# Rules:
#   - objects merge recursively; scalars: the overlay wins
#   - storage.{files,directories,links}: keyed by path, the overlay replaces
#   - storage.{disks,filesystems}: keyed by device, the overlay replaces
#   - systemd.units, passwd.users/groups: keyed by name; dropins and
#     sshAuthorizedKeys are unioned (dropins by name), other fields: overlay wins
#   - ignition.version: the higher of the two

def vkey: split(".") | map(tonumber);

def merge_entry($o):
  . as $b
  | ($b + $o)
  | if ($b.dropins or $o.dropins) then
      .dropins = ([($b.dropins // [])[], ($o.dropins // [])[]]
                  | reduce .[] as $d ({}; .[$d.name] = $d) | [.[]])
    else . end
  | if ($b.sshAuthorizedKeys or $o.sshAuthorizedKeys) then
      .sshAuthorizedKeys = ((($b.sshAuthorizedKeys // []) + ($o.sshAuthorizedKeys // [])) | unique)
    else . end;

def merge_list(a; b; k):
  ((a // []) + (b // [])) as $all
  | reduce $all[] as $e ({order: [], map: {}};
      ($e[k] | tostring) as $id
      | if .map[$id] then .map[$id] = (.map[$id] | merge_entry($e))
        else .order += [$id] | .map[$id] = $e end)
  | . as $r | [$r.order[] | $r.map[.]];

($base[0]) as $b | ($overlay[0]) as $o |
($b * $o)
| .ignition.version = ([$b.ignition.version, $o.ignition.version] | max_by(vkey))
| if ($b.storage.files or $o.storage.files) then .storage.files = merge_list($b.storage.files; $o.storage.files; "path") else . end
| if ($b.storage.directories or $o.storage.directories) then .storage.directories = merge_list($b.storage.directories; $o.storage.directories; "path") else . end
| if ($b.storage.links or $o.storage.links) then .storage.links = merge_list($b.storage.links; $o.storage.links; "path") else . end
| if ($b.storage.disks or $o.storage.disks) then .storage.disks = merge_list($b.storage.disks; $o.storage.disks; "device") else . end
| if ($b.storage.filesystems or $o.storage.filesystems) then .storage.filesystems = merge_list($b.storage.filesystems; $o.storage.filesystems; "device") else . end
| if ($b.systemd.units or $o.systemd.units) then .systemd.units = merge_list($b.systemd.units; $o.systemd.units; "name") else . end
| if ($b.passwd.users or $o.passwd.users) then .passwd.users = merge_list($b.passwd.users; $o.passwd.users; "name") else . end
| if ($b.passwd.groups or $o.passwd.groups) then .passwd.groups = merge_list($b.passwd.groups; $o.passwd.groups; "name") else . end
