#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi

#Detect Isolated partitions
function is-isolated-partition() {
  PARTITION=$(imds /latest/meta-data/services/partition)
  NON_ISOLATED_PARTITIONS=("aws" "aws-cn" "aws-us-gov")
  for NON_ISOLATED_PARTITION in "${NON_ISOLATED_PARTITIONS[@]}"; do
    if [ "${NON_ISOLATED_PARTITION}" = "${PARTITION}" ]; then
      return 1
    fi
  done
  return 0
}

function deb_install() {
  local DEBS=($@)
  echo "Pulling and installing local debs from s3 bucket"
  for DEB in "${DEBS[@]}"; do
    aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/debs/${DEB} ${WORKING_DIR}/${DEB}
    sudo apt-get install -y ${WORKING_DIR}/${DEB}
  done
}
echo "Installing NVIDIA ${NVIDIA_DRIVER_MAJOR_VERSION} drivers..."

################################################################################
### Add repository #############################################################
################################################################################
# Determine the domain based on the region
if is-isolated-partition; then
  # Add NVIDIA repository for Ubuntu
  sudo apt-get update && sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:graphics-drivers/ppa
  sudo apt-get update

  deb_install "opencl-filesystem_1.0-5_all.deb" "ocl-icd-opencl-dev_2.2.12-1_amd64.deb"

else
  if [[ $AWS_REGION == cn-* ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  if [ -n "${NVIDIA_REPOSITORY:-}" ]; then
    sudo add-apt-repository -y ${NVIDIA_REPOSITORY}
  else
    # Add CUDA repository for Ubuntu
    wget https://developer.download.${DOMAIN}/compute/cuda/repos/ubuntu2204/$(uname -m)/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.${DOMAIN}/compute/cuda/repos/ubuntu2204/$(uname -m)/ /" | sudo tee /etc/apt/sources.list.d/cuda.list
  fi

  if [[ $AWS_REGION != cn-* ]]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg &&
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  fi

  sudo apt-get update
fi

################################################################################
### Install drivers ############################################################
################################################################################
sudo mv ${WORKING_DIR}/gpu/gpu-ami-util /usr/bin/
sudo mv ${WORKING_DIR}/gpu/kmod-util /usr/bin/

sudo mkdir -p /etc/dkms
echo "MAKE[0]=\"'make' -j$(grep -c processor /proc/cpuinfo) module\"" | sudo tee /etc/dkms/nvidia.conf
sudo apt-get install -y linux-headers-$(uname -r) dkms

function archive-open-kmods() {
  if is-isolated-partition; then
    sudo apt-get install -y nvidia-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}
  else
    sudo apt-get install -y nvidia-driver-${NVIDIA_DRIVER_MAJOR_VERSION}
  fi

  sudo kmod-util archive nvidia-open/${NVIDIA_DRIVER_MAJOR_VERSION}
  sudo kmod-util remove nvidia-open
}

function archive-proprietary-kmod() {
  if is-isolated-partition; then
    sudo apt-get install -y nvidia-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}
  else
    sudo apt-get install -y nvidia-driver-${NVIDIA_DRIVER_MAJOR_VERSION}
  fi
  sudo kmod-util archive nvidia/${NVIDIA_DRIVER_MAJOR_VERSION}
  sudo kmod-util remove nvidia
}

# archive-open-kmods
# archive-proprietary-kmod
sudo apt-get install -y nvidia-dkms-535
################################################################################
### Prepare for nvidia init ####################################################
################################################################################

sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.service /etc/systemd/system/nvidia-kmod-load.service
sudo mv ${WORKING_DIR}/gpu/set-nvidia-clocks.service /etc/systemd/system/set-nvidia-clocks.service
sudo systemctl daemon-reload
sudo systemctl enable nvidia-kmod-load.service
sudo systemctl enable set-nvidia-clocks.service

################################################################################
### Install other dependencies #################################################
################################################################################
sudo apt-get install -y nvidia-fabricmanager-${NVIDIA_DRIVER_MAJOR_VERSION}
sudo apt-get install -y nvidia-imex # disable if not needed

# NVIDIA Container toolkit needs to be locally installed for isolated partitions, also install NVIDIA-Persistenced
if is-isolated-partition; then
  sudo apt-get install -y nvidia-container-toolkit nvidia-persistenced
  sudo systemctl enable nvidia-persistenced
else
  sudo systemctl disable nvidia-persistenced || true # Ensure service is disabled
  sudo apt-get install -y nvidia-container-toolkit
fi

sudo systemctl enable nvidia-fabricmanager
