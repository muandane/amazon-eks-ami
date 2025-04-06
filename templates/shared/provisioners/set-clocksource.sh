#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# use the tsc clocksource by default
# https://repost.aws/knowledge-center/manage-ec2-linux-clock-source
echo "GRUB_CMDLINE_LINUX=\"\${GRUB_CMDLINE_LINUX} clocksource=tsc\"" | sudo tee -a /etc/default/grub
sudo update-grub
