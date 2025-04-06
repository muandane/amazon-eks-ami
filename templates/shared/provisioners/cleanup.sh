#!/usr/bin/env bash

# Clean up apt caches to reduce the image size
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Only clean files that don't affect name resolution
sudo rm -rf \
  /etc/machine-id \
  /etc/ssh/ssh_host* \
  /home/ubuntu/.ssh/authorized_keys \
  /root/.ssh/authorized_keys \
  /var/lib/cloud/data \
  /var/lib/cloud/instance \
  /var/lib/cloud/instances \
  /var/lib/cloud/sem \
  /var/lib/dhclient/* \
  /var/lib/dhcp/dhclient.* \
  /var/log/cloud-init-output.log \
  /var/log/cloud-init.log \
  /var/log/secure \
  /var/log/wtmp \
  /var/log/messages \
  /var/log/audit/*

echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
sudo touch /etc/machine-id
