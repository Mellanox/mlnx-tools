#!/bin/bash
#
# Copyright (c) 2016 Mellanox Technologies. All rights reserved.
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

i=$1
shift

if [ -z "$i" ]; then
    echo "Usage:"
    echo "      $0 <interface>"
    exit 1
fi


KNOWN_CONF_VARS="TYPE BROADCAST MASTER BRIDGE BOOTPROTO IPADDR NETMASK PREFIX \
                 NAME DEVICE ONBOOT NM_CONTROLLED CONNECTED_MODE"

OPENIBD_CONFIG=${OPENIBD_CONFIG:-"/etc/infiniband/openib.conf"}
CONFIG=$OPENIBD_CONFIG
export LANG="C"

if [ ! -f $CONFIG ]; then
    echo No InfiniBand configuration found
    exit 0
fi

OS_IS_BOOTING=0
last_bootID=$(cat /var/run/mlx_ifc-${i}.bootid 2>/dev/null)
if [ "X$last_bootID" == "X" ] && [ -e /sys/class/net/${i}/parent ]; then
    parent=$(cat /sys/class/net/${i}/parent)
    last_bootID=$(cat /var/run/mlx_ifc-${parent}.bootid 2>/dev/null)
fi
bootID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | sed -e 's/-//g')
echo $bootID > /var/run/mlx_ifc-${i}.bootid
if [[ "X$last_bootID" == "X" || "X$last_bootID" != "X$bootID" ]]; then
    OS_IS_BOOTING=1
fi
start_time=$(cat /var/run/mlx_os_booting 2>/dev/null)
if [ "X$start_time" != "X" ]; then
    let run_time=$(date +%s | tr -d '[:space:]')-${start_time}
    if [ $run_time -lt 300 ]; then
        OS_IS_BOOTING=1
    fi
fi
# If driver was loaded manually after last boot, then OS boot is over
last_bootID_manual=$(cat /var/run/mlx_ifc.manual 2>/dev/null)
if [[ "X$last_bootID_manual" != "X" && "X$last_bootID_manual" == "X$bootID" ]]; then
    OS_IS_BOOTING=0
fi

. $CONFIG
IPOIB_MTU=${IPOIB_MTU:-65520}

if [ -f /etc/redhat-release ]; then
    NETWORK_CONF_DIR="/etc/sysconfig/network-scripts"
elif [ -f /etc/rocks-release ]; then
    NETWORK_CONF_DIR="/etc/sysconfig/network-scripts"
elif [ -f /etc/SuSE-release ] || [ -f /etc/SUSE-brand ]; then
    NETWORK_CONF_DIR="/etc/sysconfig/network"
else
    if [ -d /etc/sysconfig/network-scripts ]; then
        NETWORK_CONF_DIR="/etc/sysconfig/network-scripts"
    elif [ -d /etc/sysconfig/network ]; then
        NETWORK_CONF_DIR="/etc/sysconfig/network"
    fi
fi

log_msg()
{
    logger -t 'mlnx_interface_mgr' -i "$@"
}

set_ipoib_cm()
{
    local i=$1
    shift
    local mtu=$1
    shift
    local is_up=""
    local RC=0

    if [ ! -e /sys/class/net/${i}/mode ]; then
        log_msg "Failed to configure IPoIB connected mode for ${i}"
        return 1
    fi

    mtu=${mtu:-$IPOIB_MTU}

    #check what was the previous state of the interface
    is_up=`/sbin/ip link show $i | grep -w UP`

    /sbin/ip link set ${i} down
    if [ $? -ne 0 ]; then
        log_msg "set_ipoib_cm: Failed to bring down ${i} in order to change connection mode"
        return 1
    fi

    if [ -w /sys/class/net/${i}/mode ]; then
        echo connected > /sys/class/net/${i}/mode
        if [ $? -eq 0 ]; then
            log_msg "set_ipoib_cm: ${i} connection mode set to connected"
        else
            log_msg "set_ipoib_cm: Failed to change connection mode for ${i} to connected; this mode might not be supported by this device, please refer to the User Manual."
            RC=1
        fi
    else
        log_msg "set_ipoib_cm: cannot write to /sys/class/net/${i}/mode"
        RC=1
    fi

    if [ $RC -eq 0 ] ; then
        /sbin/ip link set ${i} mtu ${mtu}
        if [ $? -ne 0 ]; then
            log_msg "set_ipoib_cm: Failed to set mtu for ${i}"
            RC=1
        fi
    fi

    #if the intf was up returns it to
    if [ -n "$is_up" ]; then
        /sbin/ip link set ${i} up
        if [ $? -ne 0 ]; then
            log_msg "set_ipoib_cm: Failed to bring up ${i} after setting connection mode to connected"
            RC=1
        fi
    fi

    return $RC
}

set_RPS_cpu()
{
    local i=$1
    shift

    if [ ! -e /sys/class/net/${i}/queues/rx-0/rps_cpus ]; then
        log_msg "set_RPS_cpu: Failed to configure RPS cpu for ${i}; missing queues/rx-0/rps_cpus"
        return 1
    fi

    local LOCAL_CPUS=
    # try to get local_cpus of the device
    if [ -e /sys/class/net/${i}/device/local_cpus ]; then
        LOCAL_CPUS=$(cat /sys/class/net/${i}/device/local_cpus)
    elif [ -e /sys/class/net/${i}/parent ]; then
        # Pkeys do not have local_cpus, so take it from their parent
        local parent=$(cat /sys/class/net/${i}/parent)
        if [ -e /sys/class/net/${parent}/device/local_cpus ]; then
            LOCAL_CPUS=$(cat /sys/class/net/${parent}/device/local_cpus)
        fi
    fi

    if [ "X$LOCAL_CPUS" == "X" ]; then
        log_msg "set_RPS_cpu: Failed to configure RPS cpu for ${i}; cannot get local_cpus"
        return 1
    fi

    echo "$LOCAL_CPUS" > /sys/class/net/${i}/queues/rx-0/rps_cpus
    if [ $? -eq 0 ]; then
        log_msg "set_RPS_cpu: Configured RPS cpu for ${i} to $LOCAL_CPUS"
    else
        log_msg "set_RPS_cpu: Failed to configure RPS cpu for ${i} to $LOCAL_CPUS"
        return 1
    fi

    return 0
}

is_connected_mode_supported()
{
    local i=$1
    shift
    # Devices that support connected mode:
    #  "4113", "Connect-IB"
    #  "4114", "Connect-IBVF"
    local hca_type=""
    if [ -e /sys/class/net/${i}/device/infiniband ]; then
        hca_type=$(cat /sys/class/net/${i}/device/infiniband/*/hca_type 2>/dev/null)
    elif [ -e /sys/class/net/${i}/parent ]; then
        # for Pkeys, check their parent
        local parent=$(cat /sys/class/net/${i}/parent)
        hca_type=$(cat /sys/class/net/${parent}/device/infiniband/*/hca_type 2>/dev/null)
    fi
    if (echo -e "${hca_type}" | grep -qE "4113|4114" 2>/dev/null); then
        return 0
    fi

    # For other devices check the ipoib_enhanced module parameter value
    if (grep -q "^0" /sys/module/ib_ipoib/parameters/ipoib_enhanced 2>/dev/null); then
        # IPoIB enhanced is disabled, so we can use connected mode
        return 0
    fi

    log_msg "INFO: ${i} does not support connected mode"
    return 1
}

bring_up()
{
    local i=$1
    shift
    local RC=0

    local IFCFG_FILE="${NETWORK_CONF_DIR}/ifcfg-${i}"
    # W/A for conf files created with nmcli
    if [ ! -e "$IFCFG_FILE" ]; then
        IFCFG_FILE=$(grep -E "=\s*\"*${i}\"*\s*\$" ${NETWORK_CONF_DIR}/* 2>/dev/null | head -1 | cut -d":" -f"1")
    fi

    if [ -e "${IFCFG_FILE}" ]; then
        . ${IFCFG_FILE}
        if [ "${ONBOOT}" = "no" -o "${ONBOOT}" = "NO" ] && [ $OS_IS_BOOTING -eq 1 ]; then
            log_msg "interface $i has ONBOOT=no, skipping."
            unset $KNOWN_CONF_VARS
            return 5
        fi
    fi

    # Take CM mode settings from ifcfg file if set,
    # otherwise, take it from openib.conf
    local SET_CONNECTED_MODE=${CONNECTED_MODE:-$SET_IPOIB_CM}

    # relevant for IPoIB interfaces only
    local is_ipoib_if=0
    case "$(echo "${i}" | tr '[:upper:]' '[:lower:]')" in
        *ib* | *infiniband*)
        is_ipoib_if=1
        ;;
    esac
    if (/sbin/ethtool -i ${i} 2>/dev/null | grep -q "ib_ipoib"); then
        is_ipoib_if=1
    fi
    if [ $is_ipoib_if -eq 1 ]; then
        if [ "X${SET_CONNECTED_MODE}" == "Xyes" ]; then
            set_ipoib_cm ${i} ${MTU}
            if [ $? -ne 0 ]; then
                RC=1
            fi
        elif [ "X${SET_CONNECTED_MODE}" == "Xauto" ]; then
            # handle mlx5 interfaces, assumption: mlx5 interface will be with CM mode.
            local drvname=""
            if [ -e /sys/class/net/${i}/device/driver/module ]; then
                drvname=$(basename `readlink -f /sys/class/net/${i}/device/driver/module 2>/dev/null` 2>/dev/null)
            elif [ -e /sys/class/net/${i}/parent ]; then
                # for Pkeys, check their parent
                local parent=$(cat /sys/class/net/${i}/parent)
                drvname=$(basename `readlink -f /sys/class/net/${parent}/device/driver/module 2>/dev/null` 2>/dev/null)
            fi
            if [ "X${drvname}" == "Xmlx5_core" ]; then
                if is_connected_mode_supported ${i} ; then
                    set_ipoib_cm ${i} ${MTU}
                    if [ $? -ne 0 ]; then
                        RC=1
                    fi
                fi
            fi
        fi
        # Spread the one and only RX queue to more CPUs using RPS.
        local num_rx_queue=$(ls -l /sys/class/net/${i}/queues/ 2>/dev/null | grep rx-  | wc -l | awk '{print $1}')
        if [ $num_rx_queue -eq 1 ]; then
            set_RPS_cpu ${i}
            if [ $? -ne 0 ]; then
                RC=1
            fi
        fi
    fi

    if [ ! -e "${IFCFG_FILE}" ]; then
        log_msg "No configuration found for ${i}"
        unset $KNOWN_CONF_VARS
        return 4
    fi

    if [ $OS_IS_BOOTING -eq 1 ]; then
        log_msg "OS is booting, will not run ifup on $i"
        unset $KNOWN_CONF_VARS
        return 6
    fi

    /sbin/ifup ${i}
    if [ $? -eq 0 ]; then
        log_msg "Bringing up interface $i: PASSED"
    else
        log_msg "Bringing up interface $i: FAILED"
        unset $KNOWN_CONF_VARS
        return 1
    fi

    if [ "X$MASTER" != "X" ]; then
        log_msg "$i - briging up bond master: $MASTER ..."
        local is_up=`/sbin/ip link show $MASTER | grep -w UP`
        if [ -z "$is_up" ]; then
            /sbin/ifup $MASTER
            if [ $? -eq 0 ]; then
                log_msg "$i - briging up bond master $MASTER: PASSED"
            else
                log_msg "$i - briging up bond master $MASTER: FAILED"
                RC=1
            fi
        else
                log_msg "$i - bond master $MASTER is already up"
        fi
    fi

    # bring up the relevant bridge interface
    if [ "X$BRIDGE" != "X" ]; then
        log_msg "$i - briging up bridge interface: $BRIDGE ..."
        /sbin/ifup $BRIDGE
        if [ $? -eq 0 ]; then
            log_msg "$i - briging up bridge interface $BRIDGE: PASSED"
        else
            log_msg "$i - briging up bridge interface $BRIDGE: FAILED"
            RC=1
        fi
    fi

    unset $KNOWN_CONF_VARS
    return $RC
}

# main
log_msg "Setting up Mellanox network interface: $i"

# Don't touch Ethernet interfaces when OS is booting
if [ $OS_IS_BOOTING -eq 1 ]; then
    case "$(echo "$i" | tr '[:upper:]' '[:lower:]')" in
        *ib* | *infiniband*)
        ;;
        *)
        log_msg "Got ETH interface $i and OS is booting, skipping."
        exit 0
        ;;
    esac
fi

# bring up the interface
bring_up $i
if [ $? -eq 1 ]; then
    log_msg "Couldn't fully configure ${i}, review system logs and restart network service after fixing the issues."
fi

# call mlnx_conf_mgr.sh for IB interfaces
case "$(echo "$i" | tr '[:upper:]' '[:lower:]')" in
    *ib* | *infiniband*)
    log_msg "Running: /bin/mlnx_conf_mgr.sh ${i}"
    /bin/mlnx_conf_mgr.sh ${i}
    ;;
esac

case "$(echo ${i} | tr '[:upper:]' '[:lower:]')" in
    *ib* | *infiniband*)
    ############################ IPoIB (Pkeys) ####################################
    # get list of conf child interfaces conf files
    CHILD_CONFS=$(/bin/ls -1 ${NETWORK_CONF_DIR}/ifcfg-${i}.[0-9a-fA-F]* 2> /dev/null)
    # W/A for conf files created with nmcli
    for ff in $(grep -E "=\s*\"*${i}\.[0-9a-fA-F]*\"*\s*\$" ${NETWORK_CONF_DIR}/* 2>/dev/null | cut -d":" -f"1")
    do
        if $(echo ${CHILD_CONFS} 2>/dev/null | grep -q ${ff}); then
            continue
        fi
        CHILD_CONFS="${CHILD_CONFS} ${ff}"
    done

    # Bring up child interfaces if configured.
    for child_conf in ${CHILD_CONFS}
    do
        ch_i=${child_conf##*-}
        # Skip saved interfaces rpmsave and rpmnew
        if (echo $ch_i | grep rpm > /dev/null 2>&1); then
            continue
        fi

        if [ ! -f /sys/class/net/${i}/create_child ]; then
            continue
        fi

        suffix=$(echo ${ch_i##*.} | tr '[:upper:]' '[:lower:]')
        if [[ ${suffix} =~ ^[0-9a-f]{1,4}$ ]]; then
            hexa=$(printf "%x" $(( 0x${suffix} | 0x8000 )))
            if [[ ${hexa} != ${suffix} ]]; then
                log_msg "Error: MSB is NOT set for pkey ${suffix} (should be ${hexa}); skipping interface ${ch_i}."
                continue
            fi
        else
            log_msg "Error: pkey ${suffix} is not hexadecimal (maximum 4 digits); skipping."
            continue
        fi
        pkey=0x${hexa}

        if [ ! -e /sys/class/net/${i}.${ch_i##*.} ] ; then
            {
            local retry_cnt=0
            echo $pkey > /sys/class/net/${i}/create_child
            while [[ $? -ne 0 && $retry_cnt -lt 10 ]]; do
                sleep 1
                let retry_cnt++
                echo $pkey > /sys/class/net/${i}/create_child
            done
            } > /dev/null 2>&1
        fi
        # Note: no need to call 'bring_up $ch_i' anymore.
        # There is a new udev rule that calls this script to configure pkeys.
        # This is needed so that the script can configure also manually created pkeys by users.
    done
    ############################ End of IPoIB (Pkeys) ####################################
    ;;
    *)
    ########################### Ethernet  (Vlans) #################################
    # get list of conf child interfaces conf files
    CHILD_CONFS=$(/bin/ls -1 ${NETWORK_CONF_DIR}/ifcfg-${i}.[0-9]* 2> /dev/null)
    # W/A for conf files created with nmcli
    for ff in $(grep -E "=\s*\"*${i}\.[0-9]*\"*\s*\$" ${NETWORK_CONF_DIR}/* 2>/dev/null | cut -d":" -f"1")
    do
        if $(echo ${CHILD_CONFS} 2>/dev/null | grep -q ${ff}); then
            continue
        fi
        CHILD_CONFS="${CHILD_CONFS} ${ff}"
    done

    # Bring up child interfaces if configured.
    for child_conf in ${CHILD_CONFS}
    do
        ch_i=${child_conf##*-}
        # Skip saved interfaces rpmsave and rpmnew
        if (echo $ch_i | grep rpm > /dev/null 2>&1); then
            continue
        fi

        bring_up $ch_i
        if [ $? -eq 1 ]; then
            log_msg "Couldn't fully configure ${ch_i}, review system logs and restart network service after fixing the issues."
        fi
    done
    ########################### End of Ethernet  (Vlans) #################################
    ;;
esac
