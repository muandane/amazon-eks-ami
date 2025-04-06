#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_EFA" != "true" ]; then
  exit 0
fi

##########################################################################################
### Setup installer ######################################################################
##########################################################################################
EFA_VERSION="latest"
EFA_PACKAGE="aws-efa-installer-${EFA_VERSION}.tar.gz"
EFA_DOMAIN="https://efa-installer.amazonaws.com"

# Ubuntu alternative to imds using curl [[7]]
PARTITION=$(curl -s http://169.254.169.254/latest/meta-data/services/partition)

if [ ${PARTITION} == "aws-iso" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.c2s.ic.gov"
elif [ ${PARTITION} == "aws-iso-b" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.sc2s.sgov.gov"
elif [ ${PARTITION} == "aws-iso-e" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.cloud.adc-e.uk"
elif [ ${PARTITION} == "aws-iso-f" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.csp.hci.ic.gov"
fi

# Install required packages for Ubuntu [[6]]
sudo apt-get update && sudo apt-get install -y curl gnupg libncurses5 pigz

mkdir -p /tmp/efa-installer
cd /tmp/efa-installer

##########################################################################################
### Download installer ###################################################################
##########################################################################################
if [ ${PARTITION} == "aws-iso-e" ]; then
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/debs/${EFA_PACKAGE} .
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/debs/aws-efa-installer.key . && gpg --import aws-efa-installer.key
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/debs/${EFA_PACKAGE}.sig .
else
  curl -O ${EFA_DOMAIN}/${EFA_PACKAGE}
  curl -O ${EFA_DOMAIN}/aws-efa-installer.key && gpg --import aws-efa-installer.key
  curl -O ${EFA_DOMAIN}/${EFA_PACKAGE}.sig
fi

if ! gpg --verify ./aws-efa-installer-${EFA_VERSION}.tar.gz.sig &>/dev/null; then
  echo "EFA Installer signature failed verification!"
  exit 2
fi

##########################################################################################
### Install and cleanup ##################################################################
##########################################################################################
tar -xf ${EFA_PACKAGE} && cd aws-efa-installer
sudo ./efa_installer.sh --minimal -y

cd -
sudo rm -rf /tmp/efa-installer

sudo apt-get purge -y ubuntu-server libblockdev-crypto2 libvolume-key1 && sudo apt-get autoremove -y
