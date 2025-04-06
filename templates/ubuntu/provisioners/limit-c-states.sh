#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_EFA" != "true" ]; then
  exit 0
fi

echo "Limiting deeper C-states"
echo "GRUB_CMDLINE_LINUX=\"\${GRUB_CMDLINE_LINUX} clocksource=tsc\"" | sudo tee -a /etc/default/grub
sudo update-grub
