#!/usr/bin/env bash

# Install Mellanox tools and scripts not yet part of an
# Oracle or upstream RPM
#
#   /usr/bin/tc_wrap.py
#   /usr/bin/mlnx_qos
#   /usr/sbin/cma_roce_mode
#   /usr/sbin/show_gids

# This script does not make backups of any existing versions of
# the tools.
#
# This script doesn't do any error checking.
#
# This script does not have an uninstaller.

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

echo "Installing cma_roce_mode..."
install -o root -g root -m 0755 ${parent_path}/ofed_scripts/cma_roce_mode /usr/sbin/cma_roce_mode

echo "Installing ibdev2netdev..."
install -o root -g root -m 0755 ${parent_path}/ofed_scripts/ibdev2netdev /usr/bin/ibdev2netdev

echo "Installing show_gids..."
install -o root -g root -m 0755 ${parent_path}/ofed_scripts/show_gids /usr/sbin/show_gids

echo "Installing roce_config..."
install -o root -g root -m 0755 ${parent_path}/roce_config.sh /usr/bin/roce_config

echo "Installing Mellanox Python utils..."
cd ${parent_path}/ofed_scripts/utils/
/usr/bin/env python setup.py install
cd ${parent_path}

exit 0
