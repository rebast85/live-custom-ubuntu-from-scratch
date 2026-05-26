#!/bin/bash

set -e                  # exit on error
set -o pipefail         # exit on pipeline error
set -u                  # treat unset variable as error

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

CMD=(setup_host install_pkg build_image finish_up)

# This variable gets set by each part of the script (setup_host, debootstrap, run_chroot, build_iso)
# It is used in a status message upon a succesfull run of a part.
script_stage="unset"

function help() {
    # if $1 is set, use $1 as headline message in help()
    if [[ -z ${1+x} ]]; then
        printf "This script builds a bootable ubuntu ISO image\n\n"
    else
        printf "%s\n" "${1}"
    fi
    printf "Supported commands : %s\n\n" "${CMD[*]}"
    printf "Syntax: %s [start_cmd] [-] [end_cmd]\n" "${0}"
    printf "\trun from start_cmd to end_end\n"
    printf "\tif start_cmd is omitted, start from first command\n"
    printf "\tif end_cmd is omitted, end with last command\n"
    printf "\tenter single cmd to run the specific command\n"
    printf "\tenter '-' as only argument to run all commands\n\n"
    exit 0
}

function find_index() {
    local ret;
    local i;
    for ((i=0; i<${#CMD[*]}; i++)); do
        if [[ "${CMD[i]}" == "${1}" ]]; then
            index="${i}";
            return;
        fi
    done
    help "Command not found : ${1}"
}

function check_host() {
    if [[ $(id -u) -ne 0 ]]; then
        printf "This script should be run as 'root'\n"
        exit 1
    fi

    export HOME=/root
    export LC_ALL=C
}

function setup_host() {
    printf "=====> running setup_host ...\n"
    script_stage="setup_host"

   cat <<EOF > /etc/apt/sources.list
deb ${TARGET_UBUNTU_MIRROR} ${TARGET_UBUNTU_VERSION} main restricted universe multiverse
deb-src ${TARGET_UBUNTU_MIRROR} ${TARGET_UBUNTU_VERSION} main restricted universe multiverse

deb ${TARGET_UBUNTU_MIRROR} ${TARGET_UBUNTU_VERSION}-security main restricted universe multiverse
deb-src ${TARGET_UBUNTU_MIRROR} ${TARGET_UBUNTU_VERSION}-security main restricted universe multiverse

deb ${TARGET_UBUNTU_MIRROR} ${TARGET_UBUNTU_VERSION}-updates main restricted universe multiverse
deb-src ${TARGET_UBUNTU_MIRROR} ${TARGET_UBUNTU_VERSION}-updates main restricted universe multiverse
EOF

    echo "${TARGET_NAME}" > /etc/hostname

    # we need to install systemd first, to configure machine id
    apt-get update
    apt-get install -y libterm-readline-gnu-perl systemd-sysv

    #configure machine id
    dbus-uuidgen > /etc/machine-id
    ln -fs /etc/machine-id /var/lib/dbus/machine-id

    # don't understand why, but multiple sources indicate this
    dpkg-divert --local --rename --add /sbin/initctl
    ln -fs /bin/true /sbin/initctl
}

# Load configuration values from file
function load_config() {
    if [[ -f "${SCRIPT_DIR}/config.sh" ]]; then
        . "${SCRIPT_DIR}/config.sh"
    elif [[ -f "${SCRIPT_DIR}/default_config.sh" ]]; then
        . "${SCRIPT_DIR}/default_config.sh"
    else
        >&2 printf "Unable to find default config file '%s/default_config.sh', aborting.\n" "${SCRIPT_DIR}"
        exit 1
    fi
}

function install_pkg() {
    printf "=====> running install_pkg ... will take a long time ...\n"
    script_stage="install_pkg"
    apt-get -y upgrade

	# TODO: MOVE THESE TO-BE INSTALLED PACKAGES LIST TO CHROOT HOOK SCRIPTS
	# (hooks/chroot/0001_setup_locales_keyboard_console.sh)
	# (hooks/chroot/0002_install_standard_packages.sh)
	# (hooks/chroot/0003_install_bootloader.sh)
	# (hooks/chroot/0004_install_kernel.sh)
	# (hooks/chroot/0005_install_ubuntu_installer.sh)
	# REASON: Users can update/change default package lists without having to edit this script.
    # install live packages

    	# Added this to allow automated locale generation so script can run unattended.
	if [[ "${TARGET_LOCALES_AUTOMATE}" == "1" ]]; then
		printf "LOCALES ARE CONFIGURED AUTOMATICALLY!\n"
    	echo "${TARGET_LOCALES_GENERATE}" > /etc/locale.gen
		debconf-set-selections <<EOF
locales locales/default_environment_locale select ${TARGET_LOCALES_DEFAULT}
locales locales/locales_to_be_generated multiselect ${TARGET_LOCALES_GENERATE}
EOF

		DEBIAN_FRONTEND=noninteractive apt-get install -y locales
		locale-gen
		update-locale LANG="${TARGET_LOCALES_DEFAULT}"
	else
	 	apt-get install locales -y
	fi


	# Added this to allow automated keyboard configuration so script can run unattended.
	if [[ "${TARGET_KEYBOARD_AUTOMATE}" == "1" ]]; then
		printf "KEYBOARD IS CONFIGURED AUTOMATICALLY!\n"
		debconf-set-selections <<EOF
keyboard-configuration keyboard-configuration/modelcode string ${TARGET_KEYBOARD_MODEL}
keyboard-configuration keyboard-configuration/layoutcode string ${TARGET_KEYBOARD_LAYOUT}
keyboard-configuration keyboard-configuration/variantcode string ${TARGET_KEYBOARD_VARIANT}
keyboard-configuration keyboard-configuration/optionscode string ${TARGET_KEYBOARD_OPTIONS}
EOF

		DEBIAN_FRONTEND=noninteractive apt-get install -y keyboard-configuration
	else
		apt-get install -y keyboard-configuration
	fi


	# Added this to allow automated console setup so script can run unattended.
	if [[ "${TARGET_CONSOLE_AUTOMATE}" == "1" ]]; then
		printf "CONSOLE IS CONFIGURED AUTOMATICALLY!\n"
		debconf-set-selections <<EOF
console-setup console-setup/charmap47 select ${TARGET_CONSOLE_CHARMAP}
console-setup console-setup/codeset47 select ${TARGET_CONSOLE_CODESET}
EOF
		DEBIAN_FRONTEND=noninteractive apt-get install -y console-setup
	else
		apt-get install -y console-setup
	fi

    apt-get install -y \
        sudo \
        ubuntu-standard \
        casper \
        discover \
        laptop-detect \
        os-prober \
        network-manager \
        net-tools \
        wpagui \
		iw \
		mtools \
		unzip \
		binutils

	case ${TARGET_UBUNTU_VERSION} in
        "focal" | "bionic")
            apt-get install -y lupin-casper
            ;;
        *)
            printf "Package lupin-casper is not needed. Skipping.\n"
            ;;
    esac

	apt-get install -y \
        grub-common \
        grub-gfxpayload-lists \
        grub-pc \
        grub-pc-bin \
        grub2-common \
        grub-efi-amd64-signed \
        shim-signed

    # install kernel
    apt-get install -y --no-install-recommends "${TARGET_KERNEL_PACKAGE}"

    # graphic installer - ubiquity
    apt-get install -y \
        ubiquity \
        ubiquity-casper \
        ubiquity-frontend-gtk \
        ubiquity-slideshow-ubuntu \
        ubiquity-ubuntu-artwork

	# TODO: TURN THIS INTO SEPARATE CHROOT HOOK SCRIPT (hooks/chroot/0090_install_custom_packages.sh)
    # Call into config function
    customize_image

    # remove unused and clean up apt cache
    apt-get autoremove -y

    # final touch
    dpkg-reconfigure locales

    # network manager
    cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=none
plugins=ifupdown,keyfile
dns=systemd-resolved

[ifupdown]
managed=false
EOF

    dpkg-reconfigure network-manager

    apt-get clean -y
}

function build_image() {
    printf "=====> running build_image ...\n"
	script_stage="build_image"
    rm -rf /image

    mkdir -p /image/{casper,isolinux,install}

    pushd /image

    # copy kernel files
    cp /boot/vmlinuz-**-**-generic casper/vmlinuz
    cp /boot/initrd.img-**-**-generic casper/initrd

    # memtest86
    wget --progress=dot https://memtest.org/download/v7.00/mt86plus_7.00.binaries.zip -O install/memtest86.zip
    unzip -p install/memtest86.zip memtest64.bin > install/memtest86+.bin
    unzip -p install/memtest86.zip memtest64.efi > install/memtest86+.efi
    rm -f install/memtest86.zip

    # grub
    touch ubuntu
    cat <<EOF > isolinux/grub.cfg

search --set=root --file /ubuntu

insmod all_video

set default="0"
set timeout=30

menuentry "${GRUB_LIVEBOOT_LABEL}" {
    linux /casper/vmlinuz boot=casper nopersistent toram quiet splash ---
    initrd /casper/initrd
}

menuentry "${GRUB_INSTALL_LABEL}" {
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /casper/initrd
}

menuentry "Check disc for defects" {
    linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
    initrd /casper/initrd
}

grub_platform
if [ "\$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' {
    fwsetup
}

menuentry "Test memory Memtest86+ (UEFI)" {
    linux /install/memtest86+.efi
}
else
menuentry "Test memory Memtest86+ (BIOS)" {
    linux16 /install/memtest86+.bin
}
fi
EOF

    # generate manifest
    dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee casper/filesystem.manifest

    cp -v casper/filesystem.manifest casper/filesystem.manifest-desktop

	# TODO: MAKE THIS FUNCTION CALL A CHROOT HOOK SCRIPT (hooks/chroot/0010_remove_packages_after_install_list.sh)
    for pkg in ${TARGET_PACKAGE_REMOVE}; do
        sudo sed -i "/${pkg}/d" casper/filesystem.manifest-desktop
    done

    # create diskdefines
    cat <<EOF > README.diskdefines
#define DISKNAME  ${GRUB_LIVEBOOT_LABEL}
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

    # copy EFI loaders
    cp /usr/lib/shim/shimx64.efi.signed.previous isolinux/bootx64.efi
    cp /usr/lib/shim/mmx64.efi isolinux/mmx64.efi
    cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed isolinux/grubx64.efi

    # create a FAT16 UEFI boot disk image containing the EFI bootloaders
    (
        cd isolinux && \
        dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
        mkfs.vfat -F 16 efiboot.img && \
        LC_CTYPE=C mmd -i efiboot.img efi efi/ubuntu efi/boot && \
        LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/bootx64.efi && \
        LC_CTYPE=C mcopy -i efiboot.img ./mmx64.efi ::efi/boot/mmx64.efi && \
        LC_CTYPE=C mcopy -i efiboot.img ./grubx64.efi ::efi/boot/grubx64.efi && \
        LC_CTYPE=C mcopy -i efiboot.img ./grub.cfg ::efi/ubuntu/grub.cfg
    )

    # create a grub BIOS image
    grub-mkstandalone \
      --format=i386-pc \
      --output=isolinux/core.img \
      --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" \
      --modules="linux16 linux normal iso9660 biosdisk search" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=isolinux/grub.cfg"

    # combine a bootable Grub cdboot.img
    cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img

    # generate md5sum.txt
    /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v -e 'isolinux' > md5sum.txt)"

    popd # return initial directory
}

function finish_up() {
    printf "=====> finish_up\n"
	script_stage="finish_up"
    # truncate machine id (why??)
    truncate -s 0 /etc/machine-id

    # remove diversion (why??)
    rm /sbin/initctl
    dpkg-divert --rename --remove /sbin/initctl

    rm -rf /tmp/* ~/.bash_history
}

# =============   main  ================

load_config
check_host

# check number of args
if [[ ${#} == 0 || ${#} -gt 3 ]]; then help; fi

# loop through args
dash_flag=false
start_index=0
end_index=${#CMD[*]}
for ii in "${@}";
do
    if [[ ${ii} == "-" ]]; then
        dash_flag=true
        continue
    fi

    find_index "${ii}"
    if [[ ${dash_flag} == false ]]; then
        start_index=${index}
    else
        ((end_index = index + 1))
    fi
done
if [[ ${dash_flag} == false ]]; then
	((end_index = start_index + 1))
fi

#loop through the commands
for ((ii = start_index; ii < end_index; ii++)); do
    ${CMD[ii]}
    printf "\n\n%s - %s has finished!\n\n" "${0}" "${script_stage}"
done

if [[ ${script_stage} == "finish_up" ]]; then
	printf "The chroot enviroment and image files have finished building!\n"
fi
