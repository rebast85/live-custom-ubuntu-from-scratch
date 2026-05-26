#!/bin/bash

# This script provides common customization options for the ISO
#
# Usage: Copy this file to config.sh and make changes there.  Keep this file (default_config.sh) as-is
#   so that subsequent changes can be easily merged from upstream.  Keep all customiations in config.sh

# The version of Ubuntu to generate.  Successfully tested LTS: bionic, focal, jammy, noble, resolute
# See https://wiki.ubuntu.com/DevelopmentCodeNames for details
TARGET_UBUNTU_VERSION="resolute"

# The Ubuntu Mirror URL. It's better to change for faster download.
# More mirrors see: https://launchpad.net/ubuntu/+archivemirrors
TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"

# The packaged version of the Linux kernel to install on target image.
# See https://wiki.ubuntu.com/Kernel/LTSEnablementStack for details
TARGET_KERNEL_PACKAGE="linux-generic"

# The file (no extension) of the ISO containing the generated disk image,
# the volume id, and the hostname of the live environment are set from this name.
TARGET_NAME="ubuntu-from-scratch"

# The text label shown in GRUB for booting into the live environment
GRUB_LIVEBOOT_LABEL="Try Ubuntu FS without installing"

# The text label shown in GRUB for starting installation
GRUB_INSTALL_LABEL="Install Ubuntu FS"

# Used to version the configuration.  If breaking changes occur, manual
# updates to this file from the default may be necessary.
CONFIG_FILE_VERSION="0.4"

# =============   export the set options  ================
export "${TARGET_UBUNTU_VERSION}"
export "${TARGET_UBUNTU_MIRROR}"
export "${TARGET_KERNEL_PACKAGE}"
export "${TARGET_NAME}"
export "${GRUB_LIVEBOOT_LABEL}"
export "${GRUB_INSTALL_LABEL}"
export "${CONFIG_FILE_VERSION}"


# TODO: MOVE THESE TO HOOK SCRIPTS
# REASON: These functions do not belong in a config file IMHO.

# Packages to be removed from the target system after installation completes succesfully
export TARGET_PACKAGE_REMOVE="
    ubiquity \
    casper \
    discover \
    laptop-detect \
    os-prober \
"

# Package customisation function.  Update this function to customize packages
# present on the installed system.

function customize_image() {
    # install graphics and desktop
    apt-get install -y \
        plymouth-themes \
        ubuntu-gnome-desktop \
        ubuntu-gnome-wallpapers

    # useful tools
    apt-get install -y \
        clamav-daemon \
        terminator \
        apt-transport-https \
        curl \
        vim \
        nano \
        less

    # purge
    apt-get purge -y \
        transmission-gtk \
        transmission-common \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        aisleriot \
        hitori
}
