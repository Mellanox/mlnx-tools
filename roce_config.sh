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

#NETDEV is the netdev interface name (e.g.: eth4)
#IBDEV is the corresponding IB device (e.g.: mlx5_0)
#PORT is the corresponding IB port
#W_DCBX identifies if dynamic/static config is preferred

NETDEV=""
W_DCBX=1
TRUST_MODE=dscp
PFC_STRING=1,2,3,4,5,6
CC_FLAG=1
SET_TOS=0
MAJOR_VERSION=1
MINOR_VERSION=1

echo ""

print_usage() {
#Use this script to configure RoCE on Oracle setups
  echo "Usage:
	roce_config -i <netdev> [-d <n>] [-t <trust_mode>]
			[-p <pfc_string>] [-q <default_tos>]

Options:
 -i <interface>		enter the interface name(required)

 -d <n>			n is 1 if dynamic config(DCBX)is preferred,
			  is 0 if static config is preferred (default: 1)

 -t <trust_mode>	set priority trust mode to pcp or dscp(default: dscp)

 -p <pfc_string>	enter the string of priority lanes to enable pfc for them
			(default: 1,2,3,4,5,6). This is ignored for dynamic config.

 -q <default_tos>	set the default tos to a value between 0-255. If this option
			is not used, default tos will remain unchanged.

Example:
	roce_config -i eth4 -d 0 -t pcp
"
}

print_version() {
	echo "Version: $MAJOR_VERSION.$MINOR_VERSION"
	echo ""
}

set_rocev2_default() {
	echo "RoCE v2" > /sys/kernel/config/rdma_cm/$IBDEV/ports/$PORT/default_roce_mode > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Setting RoCEv2 as rdma_cm preference failed"
		exit 1
	else
		echo " + RoCE v2 is set as default rdma_cm preference"
	fi
}

set_tos_mapping() {
	if [ ! -d "/sys/kernel/config/rdma_cm/$IBDEV/tos_map" ] ; then
		return
	fi

	echo 32 > /sys/kernel/config/rdma_cm/$IBDEV/tos_map/tos_map_0
	if [[ $? != 0 ]] ; then
		>&2 echo " - Failed to set tos mapping"
		exit 1
	fi
	for i in {1..7}
	do
		let "mapping=$i<<5"
		echo $mapping > /sys/kernel/config/rdma_cm/$IBDEV/tos_map/tos_map_$i
		if [[ $? != 0 ]] ; then
			>&2 echo " - Failed to set tos mapping"
			exit 1
		fi
	done

	echo " + Tos mapping is set"
}

set_deafult_tos() {
	if [[ $SET_TOS == "0" ]] ; then
		return
	fi
	echo $DEFAULT_TOS > /sys/kernel/config/rdma_cm/$IBDEV/ports/$PORT/default_roce_tos
	if [[ $? != 0 ]] ; then
		>&2 echo " - Failed to set default roce tos"
		exit 1
	else
		echo " + Default roce tos is set to $DEFAULT_TOS"
	fi
}

config_trust_mode() {
	mlnx_qos -i $NETDEV --trust $TRUST_MODE > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Setting $TRUST_MODE as trust mode failed; Please make sure you installed mlnx_qos"
		exit 1
	else
		echo " + Trust mode is set to $TRUST_MODE"
	fi
}

start_lldpad() {
	if [[ $OS_VERSION == "6" ]] ; then
		service lldpad start > /dev/null
	else
		/bin/systemctl start lldpad.service > /dev/null
	fi
	if [[ $? != 0 ]] ; then
		>&2 echo " - Starting lldpad failed; exiting"
		exit 1
	else
		echo " + Service lldpad is running"
	fi
}

#This generic lldpad configuration(not related to RoCE)
do_lldpad_config() {
	lldptool set-lldp -i $NETDEV adminStatus=rxtx > /dev/null &&
	lldptool -T -i $NETDEV -V sysName enableTx=yes > /dev/null &&
	lldptool -T -i $NETDEV -V portDesc enableTx=yes > /dev/null &&
	lldptool -T -i $NETDEV -V sysDesc enableTx=yes > /dev/null &&
	lldptool -T -i $NETDEV -V sysCap enableTx=yes > /dev/null &&
	lldptool -T -i $NETDEV -V mngAddr enableTx=yes > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Generic lldpad configuration failed"
		exit 1
	else
		echo " + Finished generic lldpad configuration"
	fi
}

config_pfc() {
#Alternatively pfc config could be done by using mlnx_qos tool
#	mlnx_qos -i $NETDEV --pfc 0,1,1,1,1,1,1,0

	lldptool -T -i $NETDEV -V PFC enableTx=yes > /dev/null &&
	lldptool -T -i $NETDEV -V PFC willing=no > /dev/null &&
	lldptool -T -i $NETDEV -V PFC enabled=$PFC_STRING > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Configuring PFC failed for priority lanes $PFC_STRING"
		exit 1
	else
		echo " + PFC is configured for priority lanes $PFC_STRING"
	fi
}

enable_pfc_willing() {
	lldptool -T -i $NETDEV -V PFC enableTx=yes > /dev/null &&
	lldptool -T -i $NETDEV -V PFC willing=yes > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Enabling PFC willing bit failed"
		exit 1
	else
		echo " + Enabled PFC willing bit"
	fi
}

set_cc_algo_mask() {
	yes | mstconfig -d 0000:30:00.0 set ROCE_CC_PRIO_MASK_P1=255 ROCE_CC_PRIO_MASK_P2=255 \
	ROCE_CC_ALGORITHM_P1=ECN ROCE_CC_ALGORITHM_P2=ECN > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Setting congestion control algo/mask failed"
		exit 1
	fi
}

#This enables congestion control on all priorities, for RP and NP both, 
#regardless of PFC is enabled on one more priorities.
enable_congestion_control() {
	if [ -f "/sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/cc_enable" ] ; then
		echo 1 > /sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/cc_enable
		if [[ $? != 0 ]] ; then
			>&2 echo " - Enabling congestion control failed"
			exit 1
		else
			echo " + Congestion control enabled"
		fi
	else
		CC_VARS="$(mstconfig -d $PCI_ADDR q | grep ROCE_CC | awk '{print $NF}')"
		if [[ $? != 0 ]] ; then
			>&2 echo " - mstconfig query failed"
			exit 1
		fi
		CC_FLAG=1
		while read -r line; do
			if [[ $line != "255" && $line != "ECN(0)" ]] ; then
				CC_FLAG=0
			fi
		done <<< "$CC_VARS"
		if [[ $CC_FLAG == "1" ]] ; then
			echo " + Congestion control algo/mask are set as expected"
		else
			set_cc_algo_mask
			echo " + Congestion control algo/mask has been changed; Please **REBOOT** to load the new settings"
		fi
	fi
}

#Perform CNP frame configuration, indicating with L2 priority
#to use for sending CNP frames.
set_cnp_priority() {
	echo 7  > /sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/np_cnp_prio &&
	echo 56 > /sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/np_cnp_dscp
	if [[ $? != 0 ]] ; then
		>&2 echo " - Setting CNP priority lane failed"
		exit 1
	else
		echo " + CNP is set to priority lane 7"
	fi
}

if [[ $# -gt 8 || $# -lt 2 ]]
then
	print_usage
	exit 1
fi

while [ "$1" != "" ]; do
case $1 in
	-i )	shift
		NETDEV=$1
		;;
	-d )	shift
		W_DCBX=$1
		;;
	-t )	shift
		TRUST_MODE=$1
		;;
	-p )	shift
		PFC_STRING=$1
		;;
	-q )	shift
		DEFAULT_TOS=$1
		SET_TOS=1
		;;
	-v )	print_version
		exit
		;;
	-h )	print_usage
		exit
		;;
	* )	(>&2 echo " - Invalid option \"$1\"")
		print_usage
		exit 1
    esac
    shift
done

if [ "$EUID" -ne 0 ] ; then
	>&2 echo " - Please run as root"
	exit 1
fi

if [[ $NETDEV == "" ]] ; then
	>&2 echo " - Please enter an interface name, -i option is mandatory"
	print_usage
	exit 1
fi
ip a s $NETDEV > /dev/null
if [[ $? != 0 ]] ; then
	>&2 echo " - netdevice \"$NETDEV\" doesn't exist"
	exit 1
fi

IBDEV="$(ibdev2netdev | grep "$NETDEV" | head -1 | cut -f 1 -d " ")"
if [ -z "$IBDEV" ] ; then
	>&2 echo " - netdev \"$NETDEV\" doesn't have a corresponding ibdev"
	exit 1
fi
PORT="$(ibdev2netdev | grep $NETDEV | head -1 | cut -f 3 -d " ")"
echo "NETDEV=$NETDEV; IBDEV=$IBDEV; PORT=$PORT"

if [[ $W_DCBX != "1" && $W_DCBX != "0" ]] ; then
	>&2 echo " - Option -d can take only 1 or 0 as input"
	exit 1
fi

if [[ $TRUST_MODE != "dscp" && $TRUST_MODE != "pcp" ]] ; then
	>&2 echo " - Option -t can take only dscp or pcp as input"
	exit 1
fi

if [[ $SET_TOS == "1" && $DEFAULT_TOS -gt "255" ]] ; then
	>&2 echo " - Option -q (default tos) can only take values between 0-255"
	exit 1
fi

OS_VERSION="$(cat /etc/oracle-release | rev | cut -d" " -f1 | rev | cut -d "." -f 1)"
if [[ $OS_VERSION != "6" && $OS_VERSION != "7" ]] ; then
	>&2 echo " - Unexpected OS Version; this script works only for OL6 & OL7"
	exit 1
fi

if (! cat /proc/mounts | grep /sys/kernel/config > /dev/null) ; then
	mount -t configfs none /sys/kernel/config
	if [[ $? != 0 ]] ; then
		>&2 echo " - Failed to mount configfs"
		exit 1
	fi
fi

if [ ! -d "/sys/kernel/config/rdma_cm" ] ; then
	modprobe rdma_cm > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Failed to load rdma_cm module"
		exit 1
	fi
	if [ ! -d "/sys/kernel/config/rdma_cm" ] ; then
		>&2 echo " - rdma_cm is missing under /sys/kernel/config"
		exit 1
	fi
fi

if [ ! -d "/sys/kernel/config/rdma_cm/$IBDEV" ] ; then
	mkdir /sys/kernel/config/rdma_cm/$IBDEV
	if [[ $? != 0 ]] ; then
		>&2 echo " - Failed to create /sys/kernel/config/rdma_cm/$IBDEV"
		exit 1
	fi
fi

set_rocev2_default
set_tos_mapping
set_deafult_tos
config_trust_mode

PCI_ADDR="$(ethtool -i $NETDEV | grep "bus-info" | cut -f 2 -d " ")"
if [ -z "$PCI_ADDR" ] ; then
	>&2 echo " - Failed to obtain PCI ADDRESS for netdev \"$NETDEV\""
	exit 1
fi
if (! cat /proc/mounts |grep /sys/kernel/debug > /dev/null) ; then
	mount -t debugfs none /sys/kernel/debug
	if [[ $? != 0 ]] ; then
		>&2 echo " - Failed to mount debugfs"
		exit 1
	fi
fi
enable_congestion_control
set_cnp_priority

start_lldpad
do_lldpad_config
if [[ $W_DCBX == "0" ]] ; then
	config_pfc
else
	enable_pfc_willing
fi

echo ""
if [[ $CC_FLAG = "0" ]] ; then
	>&2 echo "Finished configuring \"$NETDEV\", but needs a *REBOOT*"
	echo ""
	exit 1
else
	echo "Finished configuring \"$NETDEV\" ヽ(•‿•)ノ"
fi
echo ""

##################################################
##	   EXTRA CODE, PLEASE IGNORE		##
##################################################

#Set priority to traffic class configuration (optional)
#This is only needed to see if RoCEv2 traffic is really taking the right DSCP based 
#QoS when you do not have switch and want to see DSCP is in effect. This maps priority
#0 to 7 to rate limiting traffic class 0 to 7. This traffic class has nothing to do with 
#rdma_set_service_level(tos) or address_handle->sl or address_handle->traffic_class.
function ets_traffic_class_config {
	mlnx_qos -i $NETDEV -p 0,1,2,3,4,5,6,7
}

#Do ETS rate limiting (optional)
#This is only needed to see if RoCEv2 traffic is really taking the right DSCP based 
#QoS when you do not have switch and still want to see DSCP is in effect.
#(Each number below indicates maximum bw in Gbps)
function ets_rate_limiting {
	mlnx_qos -i $NETDEV -r 5,4,3,2,1,10,17,8
}
#	lldptool -T -i $NETDEV -V sysCap enableTx=yes
#	lldptool -T -i $NETDEV -V mngAddr enableTx=yes
#	lldptool -T -i $NETDEV -V PFC enableTx=yes
#	lldptool -T -i $NETDEV -V CEE-DCBX enableTx=yes
#	lldptool set-lldp -i $NETDEV adminStatus=rxtx
