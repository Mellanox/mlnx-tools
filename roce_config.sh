#!/bin/bash
#NETDEV is the netdev interface name (e.g.: eth4)
#IBDEV is the corresponding IB device (e.g.: mlx5_0)
#PORT is the corresponding IB port
#W_SWITCH identifies if the interface is connected to a switch or not

W_SWITCH=1
TRUST_MODE=dscp

echo ""

print_usage() {
  echo "Use this script to configure RoCE on Oracle setups
Usage: 
	roce_config <netdev> [-s <n>]

Options:
 -s <n>			n is 1 if interface is connected to switch
		  	  is 0 if connected back-to-back(default: 1)

 -t <trust_mode>	set priority trust mode to pcp or dscp(default: dscp)

Example:
	roce_config eth4 -s 0
"
}

set_rocev2_default() {
	cma_roce_mode -d $IBDEV -p $PORT -m 2 > /dev/null
	if [[ $? != 0 ]] ; then
		echo " - Setting RoCEv2 as rdma_cm preference failed; Please make sure you installed cma_roce_mode"
		exit 1
	else
		echo " + RoCE v2 is set as default rdma_cm preference"
	fi
}

config_trust_mode() {
	mlnx_qos -i $NETDEV --trust $TRUST_MODE > /dev/null
	if [[ $? != 0 ]] ; then
		echo " - Setting $TRUST_MODE as trust mode failed; Please make sure you installed mlnx_qos"
		exit 1
	else
		echo " + Trust mode is set to $TRUST_MODE"
	fi
}

start_lldpad() {
	service lldpad start > /dev/null
	if [[ $? != 0 ]] ; then
		echo " - Starting lldpad failed; exiting"
		exit 1
	else
		echo " + Service lldpad is running"
	fi
}

config_pfc() {
#Alternatively pfc config could be done by using lldp tool
#	lldptool -T -i $NETDEV -V sysCap enableTx=yes
#	lldptool -T -i $NETDEV -V mngAddr enableTx=yes
#	lldptool -T -i $NETDEV -V PFC enableTx=yes
#	lldptool -T -i $NETDEV -V CEE-DCBX enableTx=yes
#	lldptool set-lldp -i $NETDEV adminStatus=rxtx
#	
#	lldptool -T -i $NETDEV -V PFC enabled=1,2,3,4,5,6

	mlnx_qos -i $NETDEV --pfc 0,1,1,1,1,1,1,0 > /dev/null
	if [[ $? != 0 ]] ; then
		echo " - Configuring PFC failed"
		exit 1
	else
		echo " + PFC is configured as 0,1,1,1,1,1,1,0"
	fi
}

#This enables congestion control on all priorities, for RP and NP both, 
#regardless of PFC is enabled on one more priorities.
enable_congestion_control() {
	echo 1 > /sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/cc_enable
	if [[ $? != 0 ]] ; then
		echo " - Enabling congestion control failed"
		exit 1
	else
		echo " + Congestion control enabled"
	fi
}

#Perform CNP frame configuration, indicating with L2 priority
#to use for sending CNP frames.
set_cnp_priority() {
	echo 7 > /sys/kernel/debug/mlx5/$PCI_ADDR/cc_params/np_cnp_prio
	if [[ $? != 0 ]] ; then
		echo " - Setting CNP priority failed"
		exit 1
	else
		echo " + CNP priority is set to 7"
	fi
}

if [[ $# -gt 5 || $# -lt 1 ]]
then
	print_usage
	exit 1
fi

while [ "$1" != "" ]; do
case $1 in
	-s )	shift
		W_SWITCH=$1
		;;
	-t )	shift
		TRUST_MODE=$1
		;;
	-h )	print_usage
		exit
		;;
	* )	NETDEV=$1
    esac
    shift
done

if [ "$EUID" -ne 0 ] ; then
	echo " - Please run as root"
	exit 1
fi

IBDEV="$(ibdev2netdev | grep $NETDEV | head -1 | cut -f 1 -d " ")"
if [ -z "$IBDEV" ] ; then
	echo " - netdev \"$NETDEV\" doesn't exist or doesn't have a corresponding ibdev"
	exit 1
fi
PORT="$(ibdev2netdev | grep $NETDEV | head -1 | cut -f 3 -d " ")"
echo "NETDEV=$NETDEV; IBDEV=$IBDEV; PORT=$PORT"

if [[ $W_SWITCH != "1" && $W_SWITCH != "0" ]] ; then
	echo " - Option -s can take only 1 or 0 as input"
	exit 1
fi

if [[ $TRUST_MODE != "dscp" && $TRUST_MODE != "pcp" ]] ; then
	echo " - Option -t can take only dscp or pcp as input"
	exit 1
fi

set_rocev2_default
config_trust_mode
start_lldpad

if [[ $W_SWITCH == "0" ]] ; then
	config_pfc

	PCI_ADDR="$(ethtool -i $NETDEV | grep "bus-info" | cut -f 2 -d " ")"
	if [ -z "$PCI_ADDR" ] ; then
		echo " - Failed to obtain PCI ADDRESS for netdev \"$NETDEV\""
		exit 1
	fi

	if (! cat /proc/mounts |grep /sys/kernel/debug > /dev/null) ; then
		mount -t debugfs none /sys/kernel/debug
        	if [[ $? != 0 ]] ; then
                	echo " - Failed to mount debugfs"
			exit 1
		fi
	fi

	enable_congestion_control
	set_cnp_priority
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
