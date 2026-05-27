#!/bin/bash

apt-get install -y \
        sudo \
        ubuntu-standard \
        casper \
        discover \
        laptop-detect \
        os-prober \
        network-manager \
        net-tools \
		iw \
		unzip \
		binutils \
		mtools

case ${TARGET_UBUNTU_VERSION} in
	"focal" | "bionic")
		apt-get install -y lupin-casper
            ;;
       	*)
     	printf "Package lupin-casper is not needed. Skipping.\n"
            ;;
esac
