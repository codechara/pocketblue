#!/usr/bin/env bash

set -uexo pipefail

which adb
which fastboot

echo 'waiting for device appear in fastboot'
fastboot getvar product 2>&1 | grep nabu
fastboot flash vbmeta_ab images/vbmeta_disabled.img
fastboot flash   dtbo_ab images/dtbo.img
fastboot flash   boot_ab images/twrp.img
fastboot reboot

echo 'waiting for device appear in adb'
adb wait-for-recovery
adb shell getprop ro.product.device | grep nabu
adb shell 'until twrp unmount /data ; do sleep 1; done'
adb push images/sgdisk /bin/sgdisk
adb push images/parted /bin/parted
adb shell sgdisk --resize-table 64 /dev/block/sda

# validating that sda31 partition is userdata
adb shell parted /dev/block/sda print | grep userdata | grep -qE '^31'

# partitioning
adb shell "if [ -e /dev/block/sda31 ]; then sgdisk --delete=31 /dev/block/sda; fi"
adb shell "if [ -e /dev/block/sda32 ]; then sgdisk --delete=32 /dev/block/sda; fi"
adb shell "if [ -e /dev/block/sda33 ]; then sgdisk --delete=33 /dev/block/sda; fi"
adb shell "if [ -e /dev/block/sda34 ]; then sgdisk --delete=34 /dev/block/sda; fi"
adb shell "if [ -e /dev/block/sda35 ]; then sgdisk --delete=35 /dev/block/sda; fi"
export start=$(adb shell parted -m /dev/block/sda print free | tail -1 | cut -d: -f2)
adb shell parted -s /dev/block/sda -- mkpart userdata    ext4 $start -3GB
adb shell parted -s /dev/block/sda -- mkpart fedora_boot ext4   -3GB -1GB
adb shell parted -s /dev/block/sda -- mkpart fedora_esp  fat32  -1GB 100%
adb reboot bootloader

echo 'waiting for device appear in fastboot'
fastboot getvar product 2>&1 | grep nabu
fastboot erase dtbo_ab
fastboot flash boot_ab     images/uboot.img
fastboot flash fedora_esp  images/esp.raw
fastboot flash fedora_boot images/boot.raw
fastboot flash userdata    images/root.raw

echo 'done flashing, rebooting now'
fastboot reboot
