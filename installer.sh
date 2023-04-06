#!/bin/sh -e
printf 'Welcome to the Iglunix guided installer\n'

prompt() {
	# usage:
	# prompt <prompt> <default> <var> [options ...]
	q="$1"
	default="$2"
	d_prompt="$default"
	if [ -z "$d_prompt" ]
	then
		d_prompt=none
	fi

	var="$3"
	shift; shift; shift;
	answer=''
	while [ -z "$answer" ]
	do
		printf '%s: ' "$q"
		[ ! -z "$1" ] && printf '%s ' "$@"
		printf '[%s]: ' "$d_prompt"
		read answer
		if [ -z "$answer" ]
		then
			answer=$default
		fi
	done
	read "$var" << EOF
$answer
EOF
}

glob_exists() {
	while true
	do
		if [ -e "$1" ]
		then
			printf '%s\n' "$1"
		fi
		shift 2>/dev/null >/dev/null || break
	done
}

confirm() {
	while true
	do
		printf 'please press Y to confirm or N to exit: '
		read X
		[ "$X" == "Y" ] && break
		if [ "$X" == "N" ]
		then
			printf 'installation aborted!\n'
			exit
		fi
	done
}

#disks=$(glob_exists /dev/sd? /dev/nvme?n?)
disks='/dev/sda
/dev/sdb'
prompt 'Select Disk' '' disk $disks
prompt 'Enter Hostname' 'iglunix' hostname

printf 'You are about to install iglunix with the following configuration:%s\n'
printf '\n'
printf '    to the disk : %s\n' "$disk"
printf '  with hostname : %s\n' "$hostname"
printf '\n'
printf 'WARNING: this will WIPE ALL DATA on %s\n' "$disk"
printf '\n'

confirm

printf 'Disk %s will be partitioned with the following layout: \n' "$disk"
printf '\n'
printf '     first 512B : MBR\n'
printf '     next 1536B : Empty space\n'
printf '    next 512MiB : EFI system partition  mount : /boot  format: VFAT\n'
printf '   rest of disk : root partition        mount : /      format: EXT4\n'
printf '\n'
printf 'Would you like to commit these changes to the disk?\n'

confirm

printf 'Writing partition table'

fdisk "$disk" << EOF
o
n
p
1
2048
1048575
t
ef
n
p
2
1048576

w
EOF

sync

printf 'Formatting ESP  /boot\n'

set -- $disk*1

if [ ! -e "$1" ]
then
	printf 'WTF went wrong. The boot partition does not exist!\n'
	exit 1
fi

BOOT="$1"

mkfs.vfat -n "IGLUNIX_BOOT" "$BOOT"

printf 'Formatting Root /\n'

set -- $disk*2

if [ ! -e "$1" ]
then
	printf 'WTF went wrong. The root partition does not exist!\n'
	exit 1
fi

ROOT="$1"

mkfs.ext4 -L "IGLUNIX_ROOT" "$ROOT"

printf 'Mounting file systems\n'

mkdir -p /mnt/new-root
mount -t ext4 "$ROOT" /mnt/new-root
mkdir -p /mnt/new-root/boot
mount -t vfat "$BOOT" /mnt/new-root/boot

boot_disk=$(blkid -L 'IGLUNIX_IMG')

printf 'Extracting packages'
mkdir -p /mnt/boot-disk
mount -t vfat $boot_disk /mnt/boot-disk
pkgs=$(tar -I zstd -tf /mnt/boot-disk/pkgs.tar.zst)
for pkg in $pkgs
do
	tar -xf /mnt/boot-disk/pkgs.tar.zst $pkg -C /tmp
	tar -xf /tmp/$pkg -C /mnt/new-root
done

mkdir -p /mnt/new-root/etc
printf 'Setting hostname'

printf '%s\n' "$hostname" > /mnt/new-root/etc/hostname

printf 'Setting fstab'

printf 'LABEL=IGLUNIX_ROOT\t/\text4\tdefaults\t0\t0\n' > /mnt/new-root/etc/fstab
printf 'LABEL=IGLUNIX_BOOT\t/boot\tvfat\tdefaults\t0\t0\n' >> /mnt/new-root/etc/fstab

printf 'Adding root user'
cat > /mnt/new-root/etc/passwd << EOF
root:x:0:0:Admin,,,:/root:/bin/sh
EOF

cat > /mnt/new-root/etc/group << EOF
root:x:0:
EOF

printf 'Installation should now be finished!\n'
printf 'Chroot into your new system to inspect everything before rebooting\n'
