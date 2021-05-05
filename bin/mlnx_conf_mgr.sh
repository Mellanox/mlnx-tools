#!/bin/bash
# ex:ts=4:sw=4:sts=4:et
# -*- tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
#
# Copyright (c) 2018 Mellanox Technologies. All rights reserved.
#
# This Software is licensed under one of the following licenses:
#
# 1) under the terms of the "Common Public License 1.0" a copy of which is
#    available from the Open Source Initiative, see
#    http://www.opensource.org/licenses/cpl.php.
#
# 2) under the terms of the "The BSD License" a copy of which is
#    available from the Open Source Initiative, see
#    http://www.opensource.org/licenses/bsd-license.php.
#
# 3) under the terms of the "GNU General Public License (GPL) Version 2" a
#    copy of which is available from the Open Source Initiative, see
#    http://www.opensource.org/licenses/gpl-license.php.
#
# Licensee has the right to choose one of the above licenses.
#
# Redistributions of source code must retain the above copyright
# notice and one of the license notices.
#
# Redistributions in binary form must reproduce both the above copyright
# notice, one of the license notices in the documentation
# and/or other materials provided with the distribution.
#
# Author: Alaa Hleihel <alaa@mellanox.com>
#
export LANG="C"

MLX5_CONFIG=${MLX5_CONFIG:-"/etc/infiniband/mlx5.conf"}

KNOWN_CONF_VARS="MLX5_RELAXED_PACKET_ORDERING_ON \
                 MLX5_RELAXED_PACKET_ORDERING_OFF"

RC=0
devs=

usage()
{
    cat << EOF

This utility configures the Mellanox device drivers to enable/disable supported fearures.

Usage:
    $0 <interface_name | IB_device_name>

    Running the utility without any argument will configure all defined IB devices
    in the configuration file ${MLX5_CONFIG} .

    Optionally, you can provide a list of interface and/or IB devices to configure
    as defined in the configuration file.

    Note: This utility prints all messages to the system's standard logging file.

EOF

}

# Parse args
while [ ! -z "$1" ]
do
    lc_ent=$(echo "${1}" | tr '[:upper:]' '[:lower:]')
    case "$lc_ent" in
        mlx* | *ib* | *infiniband*)
            devs="${devs} ${1}"
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo
            echo "Wrong parameter $1" >&2
            echo
            usage
            exit 1
            ;;
    esac
    shift
done



if [ ! -f "${MLX5_CONFIG}" ]; then
    echo "No MLX5 InfiniBand configuration found at ${MLX5_CONFIG}"
    exit 1
fi

# Clear env variables
unset ${KNOWN_CONF_VARS}

# Load configurations from conf file
. ${MLX5_CONFIG}

log_msg()
{
    logger -t 'mlnx_conf_mgr' -i "$@"
}

find_pci_dev()
{
	local pdevlist=$(ls /sys/bus/pci/devices)

	for pdev in $pdevlist; do
		if [ -d /sys/bus/pci/devices/${pdev}/infiniband ]; then
			ibd=$(ls /sys/bus/pci/devices/${pdev}/infiniband/)
			if [ "X${ibd}" == "X${1}" ]; then
                echo -n "${pdev}"
			fi
		fi
	done
}

find_ib_dev()
{
    local dev=$1; shift

    local ib_dev=

    if [ -e "/sys/class/net/${dev}/device/infiniband/" ]; then
        ib_dev=$(/bin/ls /sys/class/net/${dev}/device/infiniband/ 2>/dev/null)
    elif [ -e "/sys/class/net/${dev}/parent" ]; then
        # For Pkeys take it from their parent
        local parent=$(cat /sys/class/net/${dev}/parent)
        if [ -e "/sys/class/net/${parent}/device/infiniband/" ]; then
            ib_dev=$(/bin/ls /sys/class/net/${parent}/device/infiniband/ 2>/dev/null)
        fi
    else
        ib_dev=${dev}
    fi

    if [ "X${ib_dev}" == "X" ]; then
        log_msg "Error: find_ib_dev: Failed to get IB device name of ${dev}"
        RC=1
        return
    fi
    if [ ! -e "/sys/class/infiniband/${ib_dev}/" ]; then
        log_msg "Error: find_ib_dev: Cannot find IB device for ${ib_dev}"
        RC=1
        return
    fi
    echo -n "${ib_dev}"
}

set_relaxed_packet_ordering()
{
    local ib_dev=$1; shift
    local mode=$1; shift

    local ib_dev_pci_bus=$(find_pci_dev ${ib_dev})
    if [ "X${ib_dev_pci_bus}" == "X" ]; then
        log_msg "Error: set_relaxed_packet_ordering (${ib_dev}): Failed to get PCI bus."
        RC=1
        return
    fi

    if [ ! -e "/sys/kernel/debug/mlx5/${ib_dev_pci_bus}/ooo/enable" ]; then
        log_msg "Error: set_relaxed_packet_ordering (${ib_dev}): Path does not exist '/sys/kernel/debug/mlx5/${ib_dev_pci_bus}/ooo/enable'"
        RC=1
        return
    fi

    log_msg "INFO: set_relaxed_packet_ordering (${ib_dev}): Setting /sys/kernel/debug/mlx5/${ib_dev_pci_bus}/ooo/enable to ${mode}"
    echo "${mode}" > /sys/kernel/debug/mlx5/${ib_dev_pci_bus}/ooo/enable
    if [ $? -ne 0 ]; then
        log_msg "Error: set_relaxed_packet_ordering (${ib_dev}): Failed to set Relaxed Packet Ordering."
        RC=1
        return
    fi
}


# Main
if [ ! -d /sys/class/infiniband ]; then
	log_msg "Driver is not loaded" >&2
    exit 1
fi

if [ "X${devs}" != "X" ]; then
    # process only given devices list (enabled/disabled based on conf file)
    for cdev in ${devs}
    do
        ib_dev=$(find_ib_dev ${cdev})
        if [ "X${ib_dev}" == "X" ]; then
            continue
        fi
        if (echo "${MLX5_RELAXED_PACKET_ORDERING_ON}" | grep -wq "${ib_dev}") ||
            (echo "${MLX5_RELAXED_PACKET_ORDERING_ON}" | grep -wq "all"); then
            set_relaxed_packet_ordering "${ib_dev}" "1"
        elif (echo "${MLX5_RELAXED_PACKET_ORDERING_OFF}" | grep -wq "${ib_dev}") ||
            (echo "${MLX5_RELAXED_PACKET_ORDERING_OFF}" | grep -wq "all"); then
            set_relaxed_packet_ordering "${ib_dev}" "0"
        else
            log_msg "INFO: No configurations found for ${ib_dev}, skipping."
        fi
    done
else
    # process all configured device in conf file
    if [[ "X${MLX5_RELAXED_PACKET_ORDERING_ON}" == "X" && "X${MLX5_RELAXED_PACKET_ORDERING_OFF}" == "X" ]]; then
        log_msg "Error: Nothing is set in ${MLX5_CONFIG}"
        exit 1
    fi

    # Enable list
    for cdev in ${MLX5_RELAXED_PACKET_ORDERING_ON}
    do
        if [ "X${cdev}" == "X" ]; then
            continue
        fi
        if [ "X${cdev}" == "Xall" ]; then
            for ib_dev in $(/bin/ls /sys/class/net/*/device/infiniband/ 2>/dev/null)
            do
                case "${ib_dev}" in
                    mlx5*)
                        set_relaxed_packet_ordering "${ib_dev}" "1"
                        ;;
                esac
            done
            continue
        fi
        ib_dev=$(find_ib_dev ${cdev})
        if [ "X${ib_dev}" == "X" ]; then
            continue
        fi
        set_relaxed_packet_ordering "${ib_dev}" "1"
    done

    # Disable list
    for cdev in ${MLX5_RELAXED_PACKET_ORDERING_OFF}
    do
        if [ "X${cdev}" == "all" ]; then
            for ib_dev in $(/bin/ls /sys/class/net/*/device/infiniband/ 2>/dev/null)
            do
                case "${ib_dev}" in
                    mlx5*)
                        set_relaxed_packet_ordering "${ib_dev}" "0"
                        ;;
                esac
            done
            continue
        fi
        ib_dev=$(find_ib_dev ${cdev})
        if [ "X${ib_dev}" == "X" ]; then
            continue
        fi
        set_relaxed_packet_ordering "${ib_dev}" "0"
    done
fi

exit ${RC}
