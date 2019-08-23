#!/bin/bash
# Copyright 2019 Maximilian Friedersdorff
#
# This file is part of 'disk_creator.sh'
#
# 'disk_creator.sh' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# disk_creator.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with disk_creator.sh.  If not, see <https://www.gnu.org/licenses/>.

usage() {
	echo "Usage:"
	echo "disk_creator.sh OS_IMAGE USB_DRIVE"
	echo
	echo "Example:"
	echo "disk_creator.sh ~/Downloads/xubuntu-18.04.2-desktop-amd64.iso /dev/sdd"
	echo
	echo "Create a live usb drive on the device '/dev/sdd' with the os found in"
	echo "~/Downloads/xubuntu-18.04.2-desktop-amd64.iso"
}

if [ $# -ne 2 ]; then
	echo "ERROR: expected exactly 2 arguments"
	usage
	exit 1
fi

if [ ! -b $2 ]; then
	echo "ERROR: $2 is not a block device"
	usage
	exit 1
fi

if [ ! -f $1 ]; then
	echo "ERROR: $1 is not a regular file"
	usage
	exit 1
fi

# The name of the USB drive you want to create
usb_drive="$2"

# The location of the linux distribution you want to use
os_image="$1"

# Removing leading directory/folder name
image_name="${os_image##*/}"
# Removing the filename extension
os_name="$(echo ${image_name%.*} | tr '-' ' ' | tr '_' ' ')"

# Querying the block size, the logical size of entities on the USB drive
block_size=$(cat /sys/block/${usb_drive#/dev/}/queue/hw_sector_size)

# Calculate the size of the partition to hold the iso and boot loader.  Allow
# 50MiB for the bootloader (this is way overkill).
live_part_size="$(ls -l ${os_image} | 
	awk -v block_size=${block_size} \
	'{print (($5/block_size) + (50*1024*1024/block_size))}')"

# Calculate the start of the 'usbdata' partition
let usbdata_part_start="${live_part_size} + 2048 + 3*1024*1024*1024/${block_size}"

main() {
	# Find out the location of the linux kernel and the initramfs (initial ramdisk
	# file system) in the os image file. We need these locations later when 
	# configuring grub
	modprobe loop
	loop_dev="$(losetup --show -f ${os_image})"
	l_mount="$(mktemp -d)"
	mount -o ro "${loop_dev}" "${l_mount}"
	kernel="$(find ${l_mount} -iname *vmlinuz* -printf '%P\n')"
	initramfs="$(find ${l_mount} -iname *initr* -printf '%P\n')"
	umount "${l_mount}"
	rmdir "${l_mount}"
	losetup -d "${loop_dev}"

	if [ $(echo "${kernel}" | wc -l) -gt 1 ]; then
		echo "Too many possible linux kernels found:"
		echo $kernel
	fi

	if [ $(echo "${initramfs}" | wc -l) -gt 1 ]; then
		echo "Too many possible initramfs found:"
		echo $initramfs
	fi

	# Partition the usb drive. The partition listed first can be read by linux
	# and windows operating systems.  It is located at the 'end' of the drive
	# The partition listed second contains the operating system and boot loader,
	# it is located at the 'beginning' of the drive. The partition listed last fills
	# the space between the other two, and is used to record changes made to the 
	# operating system
	sfdisk "${usb_drive}" <<- EOF

	label: gpt

	start=$usbdata_part_start, type=11
	start=2048, size=$live_part_size, type=1
	type=20
	EOF

	# waiting to ensure disk has been re recognised after partitioning
	sleep 10

	# Format each partition with the relevant filesystem.
	mkfs.ntfs --fast -L usbdata "${usb_drive}1"
	mkfs.fat -F 32 "${usb_drive}2"
	mkfs.ext4 -q -F -L casper-rw "${usb_drive}3"

	# Create a temporary directory
	m_point=$(mktemp -d)

	# Mount the drive to the temporary directory, create some folders/directories,
	# copy the os image, and install the boot loader.
	mount "${usb_drive}2" "${m_point}"
	mkdir "${m_point}"/{boot,iso_boot}
	cp "${os_image}" "${m_point}/iso_boot" && sync
	grub-install "${usb_drive}" \
		--target=x86_64-efi \
		--efi-directory="${m_point}" \
		--boot-directory="${m_point}/boot" \
		--removable

	# Install the configuration file for the bootloader
	cat <<-EOF> "${m_point}/boot/grub/grub.cfg"
	set timeout=10
	set default=0
	insmod loopback
	insmod all_video

	menuentry "Run ${os_name} Persistent, in RAM" {
		loopback loop /iso_boot/${image_name}
		set gfxpayload=keep
		linux (loop)/${kernel} boot=casper iso-scan/filename=/iso_boot/${image_name} quiet splash persistent toram ---
		initrd (loop)/${initramfs}
	}

	menuentry "Run ${os_name} - Persistent" {
		loopback loop /iso_boot/${image_name}
		set gfxpayload=keep
		linux (loop)/${kernel} boot=casper iso-scan/filename=/iso_boot/${image_name} quiet splash persistent ---
		initrd (loop)/${initramfs}
	}

	menuentry "Run ${os_name}" {
		loopback loop /iso_boot/${image_name}
		set gfxpayload=keep
		linux (loop)/${kernel} boot=casper iso-scan/filename=/iso_boot/${image_name} quiet splash ---
		initrd (loop)/${initramfs}
	}
	EOF

	# Clean up
	umount "${m_point}"
	rmdir "${m_point}"
}

main 2> >(sed $'s,.*,\e[31m&\e[m, '>&2)
