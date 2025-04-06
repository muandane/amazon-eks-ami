#!/usr/bin/env bash

if [[ "$ENABLE_FIPS" == "true" ]]; then
  # https://wiki.ubuntu.com/DebuggingFIPS
  sudo apt-get update
  sudo apt-get install -y fips-initramfs
  sudo update-alternatives --set fips-mode-setup /usr/lib/fips-mode-setup/fips-mode-setup
  sudo fips-mode-setup --enable
fi
