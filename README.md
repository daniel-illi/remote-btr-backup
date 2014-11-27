remote-btr-backup
=========

```
usage: remote-btr-backup.sh options

This script creates a copy of a local folder as a snapshot on a remote btrfs volume or a thin provisioned LVM volume.
Dependencies on the local system are ssh (with shared key setup) and any bourne shell (i.e. busybox ash).
On the remote system snapper (snapper.io) must be installed and configured.

OPTIONS:
   -h      Show this message
   -n      Backup name
   -d      The directory to back up
   -b      The backup directory
   -m      Optional: A local directory to create an intermediate mirror of the directory to back up
           before sending the data to the remote system. This will improve the consistency of the backup
           as the local mirroring is usually a lot quicker than writing to a remote system.
   -r      Optional: Backup host (hostname or ip or ssh alias)
   -s      Optional: Snapper configuration on the remote system to use for snapshots.
   -c      Optional: absolute path to a configuration file with the required options.
           Following variables must be set:
             BACKUP_NAME
             SOURCE_DIR
             MIRROR_DIR
             TARGET_DIR
           Optional variables:
             MIRROR_DIR
             TARGET_HOST
             SNAPPER_CONFIG
```

Dependencies
-----------
* **rsync**: must be installed on both the local and the remote host.
* **ssh**: The remote host must run an ssh daemon. The backup user on the local system must be able to log in
  to the remote system automatically (key authentication, any required ssh arguments must be set in the ssh client
  config under `~/.ssh/config`)

License
----
MIT

*Free Software, Hell Yeah!*
