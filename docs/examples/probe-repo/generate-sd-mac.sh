#!/usr/bin/env bash
if [[ $# -ne 1 ]]; then
    echo "Usage: ./generate-sd-mac.sh [sd-card-block-device-name (e.g. mmcblk0)]"
    exit 1
fi

MAC_PREFIX="aa:91:36"
MAC_SUFFIX=$(cat /sys/block/$1/device/serial | md5sum | awk '{ print $1 }' | head -c 6 | sed -e 's/./&:/2' -e 's/./&:/5' | tr -d '\n')

echo "Generated MAC address: $MAC_PREFIX:$MAC_SUFFIX"