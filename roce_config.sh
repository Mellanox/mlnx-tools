#!/bin/bash
#NETDEV is the netdev interface name (e.g.: eth4)
#IBDEV is the corresponding IB device (e.g.: mlx5_0)
#PORT is the corresponding IB port
#W_DCBX identifies if dynamic/static config is preferred

NETDEV=""
W_DCBX=1
TRUST_MODE=dscp
PFC_STRING=1,2,3,4,5,6

echo ""

print_usage() {
#Use this script to configure RoCE on Oracle setups
  echo "Usage:
	roce_config -i <netdev> [-d <n>] [-t <trust_mode>]
			[-p <pfc_string>]

Options:
 -i <interface>		enter the interface name(required)

 -d <n>			n is 1 if dynamic config(DCBX)is preferred,
			  is 0 if static config is preferred (default: 1)

 -t <trust_mode>	set priority trust mode to pcp or dscp(default: dscp)

 -p <pfc_string>	enter the string of priority lanes to enable pfc for them
			(default: 1,2,3,4,5,6). This is ignored for dynamic config.

Example:
	roce_config -i eth4 -d 0 -t pcp
"
}

set_rocev2_default() {
	cma_roce_mode -d $IBDEV -p $PORT -m 2 > /dev/null
	if [[ $? != 0 ]] ; then
		>&2 echo " - Setting RoCEv2 as rdma_cm preference failed; Please make sure you installed cma_roce_mode"
		exit 1
	else
		echo " + RoCE v2 is set as default rdma_cm preference"
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
	service lldpad start > /dev/null
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

#This enables congestion control on all priorities, for RP and NP both, 
#regardless of PFC is enabled on one more priorities.
enable_congestion_control() {
	echo 1 > /sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/cc_enable
	if [[ $? != 0 ]] ; then
		>&2 echo " - Enabling congestion control failed"
		exit 1
	else
		echo " + Congestion control enabled"
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

set_rocev2_default
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
echo "Finished configuring \"$NETDEV\" ヽ(•‿•)ノ"
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
