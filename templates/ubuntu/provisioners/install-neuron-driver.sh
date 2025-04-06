#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "neuron" ]; then
  exit 0
fi

PARTITION=$(imds "/latest/meta-data/services/partition")

if [[ "$PARTITION" =~ ^aws-iso(-[bef])?$ ]]; then
  echo "Neuron repository not available in isolated regions"
  exit 1
fi

################################################################################
### Add repository #############################################################
################################################################################
. /etc/os-release
sudo tee /etc/apt/sources.list.d/neuron.list >/dev/null <<EOF
deb https://apt.repos.neuron.amazonaws.com ${VERSION_CODENAME} main
EOF
wget -qO - https://apt.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB | sudo apt-key add -

################################################################################
### Install packages ###########################################################
################################################################################
sudo apt-get update -y
sudo apt-get remove aws-neuron-dkms -y
sudo apt-get remove aws-neuronx-dkms -y
sudo apt-get install aws-neuronx-dkms=2.5.41.0 -y
