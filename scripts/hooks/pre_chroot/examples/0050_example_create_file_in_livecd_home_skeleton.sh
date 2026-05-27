#!/bin/bash

# This is a pre-chroot hook example file. Copy it and adapt it to your wishes.

# Create directory chroot/etc/skel/Desktop and create a file in it
mkdir -p "${SCRIPT_DIR}/chroot/etc/skel/Desktop"
touch "${SCRIPT_DIR}/chroot/etc/skel/Desktop/file.txt"

# Add some content to the file
echo "This is a test file. This file should be visisble on the desktop of the live cd user and will also be copied over during an installation." > "${SCRIPT_DIR}/chroot/etc/skel/Desktop/file.txt"
