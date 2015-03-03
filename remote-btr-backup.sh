#!/bin/sh
# Copyright (c) 2014 Daniel Illi-Zuberbühler
#
# The MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -e # we want to exit the script on error
#set -x # show all executed commands, for debugging only


usage()
{
cat << EOF
usage: $0 options

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
   -e      Optional: rsync exclude file
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
EOF
}

SOURCE_DIR=
TARGET_HOST=
TARGET_DIR=
CONFIG_FILE=

while getopts "hn:d:m:r:b:fs:c:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         n)
             BACKUP_NAME=$OPTARG
             ;;
         d)
             SOURCE_DIR=$OPTARG
             ;;
         m)
             MIRROR_DIR=$OPTARG
             ;;
         r)
             TARGET_HOST=$OPTARG
             ;;
         b)
             TARGET_DIR=$OPTARG
             ;;
         s)
             SNAPPER_CONFIG=$OPTARG
             ;;
         e)
             RSYNC_EXCLUDE=$OPTARG
             ;; 
         c)
             CONFIG_FILE=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [ -n "$CONFIG_FILE" ]
then
  if [ -f "$CONFIG_FILE" ]
  then
    source "$CONFIG_FILE"
  else
    echo "configuration file '$CONFIG_FILE' not found"; exit 1
  fi
fi

if [ -z $BACKUP_NAME ] || [ -z $SOURCE_DIR ] || [ -z $TARGET_DIR ]
then
     usage
     exit 1
fi

START_TIME=$(date +"%s")

duration() {
  end_time=$(date +"%s")
  diff=$(($end_time - $START_TIME))
  echo "duration: $(($diff / 3600))h, $(($diff % 3600 / 60))m, $(($diff % 60))s"
}

RSYNC_PARAMS="-rlptD -X --delete --exclude-from=$RSYNC_EXCLUDE"

if [ -n "$MIRROR_DIR" ]
then
  BACKUP_SOURCE=${MIRROR_DIR}/
else
  BACKUP_SOURCE=$SOURCE_DIR
fi

if [ -n "$TARGET_HOST" ]
then
  BACKUP_TARGET="${TARGET_HOST}:${TARGET_DIR}"
else
  BACKUP_TARGET=$TARGET_DIR
fi

SNAPPER_COMMAND=${SNAPPER_CONFIG+"snapper -c \"${SNAPPER_CONFIG?}\" create -t single -c timeline -d \"${BACKUP_NAME?}\""}

create_mirror() {
  echo "creating local mirror:"
  rsync ${RSYNC_PARAMS?} ${SOURCE_DIR?} ${MIRROR_DIR?}
  echo "local mirror completed."
}

create_backup() {
  echo "creating remote backup:"
  rsync ${RSYNC_PARAMS?} --rsync-path='rsync --fake-super' ${BACKUP_SOURCE?} ${BACKUP_TARGET?}
  echo "remote backup completed"
}

create_snapshot() {
  echo "creating snapshot:"
  if [ -n "${TARGET_HOST?}" ]
  then
    ssh ${TARGET_HOST?} "${SNAPPER_COMMAND}"
  else
    $SNAPPER_COMMAND
  fi
  echo "snapshot completed"
}

if [ -n "$MIRROR_DIR" ]
then
  create_mirror
fi

create_backup

if [ -n "$SNAPPER_CONFIG" ]
then
  create_snapshot
fi

echo "backup completed"
duration
