Simple script to create persistent Live USB drive
=================================================

Will create a live usb drive with persistence and a mass storage area useable
by windows OSs.

Installation
------------
Clone this repository, or download the 'disk_creator.sh' file.

Dependencies
############

* bash
* sfdisk
* losetup
* ntfs3g 
* dosfstools
* awk
* bc

The linux kernel must be compiled with support for iso9660 file systems.

On debian based distributions most of these will be installed already, just in
case here is how to install them:

.. code-block:: console

   $ sudo apt update
   $ sudo apt install ntfs-3g util-linux dosfstools bash gawk bc

Usage
-----

Identify USB device
###################

List all currently plugged in block devices, you might see something like this:

.. code-block:: console

   $ lsblk
   loop0              7:0    0  54.4M  1 loop /snap/core18/1055
   loop1              7:1    0     4M  1 loop /snap/gnome-calculator/352
   loop2              7:2    0  1008K  1 loop /snap/gnome-logs/57
   loop3              7:3    0 140.7M  1 loop /snap/gnome-3-26-1604/90
   loop4              7:4    0  35.3M  1 loop /snap/gtk-common-themes/1198
   loop5              7:5    0  14.8M  1 loop /snap/gnome-characters/292
   loop6              7:6    0  88.4M  1 loop /snap/core/7169
   loop7              7:7    0  54.4M  1 loop /snap/core18/1049
   loop8              7:8    0 149.9M  1 loop /snap/gnome-3-28-1804/67
   loop9              7:9    0 149.9M  1 loop /snap/gnome-3-28-1804/63
   loop10             7:10   0   3.7M  1 loop /snap/gnome-system-monitor/100
   loop11             7:11   0  14.8M  1 loop /snap/gnome-characters/296
   loop12             7:12   0   3.7M  1 loop /snap/gnome-system-monitor/95
   loop13             7:13   0   2.3M  1 loop /snap/gnome-calculator/260
   loop14             7:14   0  1008K  1 loop /snap/gnome-logs/61
   loop15             7:15   0  88.5M  1 loop /snap/core/7270
   loop16             7:16   0  14.5M  1 loop /snap/gnome-logs/45
   loop17             7:17   0     4M  1 loop /snap/gnome-calculator/406
   loop18             7:18   0  42.8M  1 loop /snap/gtk-common-themes/1313
   loop19             7:19   0 140.7M  1 loop /snap/gnome-3-26-1604/88
   sda                8:0    0   7.3T  0 disk
   ├─sda1             8:1    0   128M  0 part
   └─sda2             8:2    0   7.3T  0 part
   sdb                8:16   0   9.1T  0 disk
   └─sdb1             8:17   0   9.1T  0 part
     ├─mass-swap    253:0    0   128G  0 lvm  [SWAP]
     └─mass-storage 253:1    0     8T  0 lvm  /mnt/mass/storage
   sdc                8:32   0   9.1T  0 disk
   └─sdc1             8:33   0   9.1T  0 part
     └─mass-scratch 253:2    0     2T  0 lvm  /mnt/mass/scratch
   nvme0n1          259:0    0 238.5G  0 disk
   ├─nvme0n1p1      259:1    0   512M  0 part /boot/efi
   └─nvme0n1p2      259:2    0   238G  0 part /

Plug in your usb drive and list all block devices again:

.. code-block:: console

   $ lsblk
   .
   .
   .
   nvme0n1          259:0    0 238.5G  0 disk
   ├─nvme0n1p1      259:1    0   512M  0 part /boot/efi
   └─nvme0n1p2      259:2    0   238G  0 part /
   sdd                8:48   1   7.5G  0 disk

Notice the new device, `sdd`.  It may be called differently on your machine, but
will likely be named `sdX` where `X` is a letter.  The full name of your usb
device is `/dev/sdX`.

Be absolutely that you have correctly identified the USB device at this point.
If you have misidentified it, you will cause irreparable loss of data.

Linux install image
###################

Find the installer image for your favourite debian based distribution.  You can
typically find these things by searching 'get <distribution_name>',
'download <distribution_name>' or 'install <distribution_name>' with your 
favourite search engine.  You can also look for tutorials about how to install
that distribution.  They will likely include instructions about getting the 
installer image. Download the image and make a note of it's location.

Running disk_creator
--------------------

Run 'disk_creator.sh' with root privileges:

.. code-block:: console

   $ sudo /path/to/disk_creator.sh /path/to/installer/image.iso /dev/sdX

For instance, if your usb device is '/dev/sdd' and your installer image is
located at '/home/user/Downloads/ubuntu-18.04-amd64.iso' run:

.. code-block:: console

   $ sudo /path/to/disk_creator.sh \
   > /home/user/Downloads/ubuntu-18.04-amd64.iso \
   > /dev/sdd

The disk_creator will now run for some time while it copies things to the usb 
drive.  Once it is done, read through the output it produced.  If there are no
obvious error messages, it should have completed successfully.

Testing it worked
-----------------

The USB drive should now have three partitions. One each of NTFS, ext4 and
FAT32.  When plugged into a windows machine, one of them should appear as a large
empty partition labeled 'usbdata'.

You should be able to boot from the USB drive, into whatever installer image you
provided.  If it does so, test that a test file created on the desktop remains 
there after a reboot.

If all these tests are successful, everything should have worked.

If not, read the contents of the 'disk_creator.sh' script and try to understand
what it is doing.  It is heavily commented.
