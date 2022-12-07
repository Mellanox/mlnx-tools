#!/bin/bash

SWID=$2
# might be pf0vf1 so only get vf number
PORT=${1##*f}
PORT_NAME=$1
IFINDEX=$3

# need the PATH for BF ARM lspci to work
PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [[ "$ID_NET_DRIVER" != *"mlx5"* ]]; then
    exit 1
fi

function get_mh_bf_rep_name() {
        PORT_NM=$1
        IFIDX=$2
        for rep_ndev in `ls /sys/class/net/`; do
                _ifindex=`cat /sys/class/net/$rep_ndev/ifindex | head -1 2>/dev/null`
                if [ "$_ifindex" = "$IFIDX" ]
                then
                        devpath=`udevadm info /sys/class/net/$rep_ndev | grep "DEVPATH="`
                        pcipath=`echo $devpath | awk -F "/net/$rep_ndev" '{print $1}'`
                        array=($(echo "$pcipath" | sed 's/\// /g'))
                        len=${#array[@]}
                        # last element in array is pci parent device
                        parent_pdev=${array[$len-1]}
                        #pdev is : 0000:03:00.0, so extract them by their index
                        f=${parent_pdev: -1}
                        if [[ $PORT_NM == p[0-7] ]]; then
                                echo "p${f}"
                                return 0
                        fi

                        if [[ $PORT_NM == pf[0-7] ]]; then
                                echo "pf${f}hpf"
                                return 0
                        fi

                        if [[ $PORT_NM == pf[0-7]vf* ]]; then
                                echo $PORT_NM | sed -e "s/\(pf\).\{1\}/\1${f}/"
                                return 0
                        fi
                 fi
        done
}

is_bf=`lspci -s 00:00.0 2> /dev/null | grep -wq "PCI bridge: Mellanox Technologies" && echo 1 || echo 0`
if [ $is_bf -eq 1 ]; then
        num_of_pf=`lspci 2> /dev/null | grep -w "Ethernet controller: Mellanox Technologies MT42822 BlueField-2" | wc -l`
        if [ $num_of_pf -gt 2 ]; then
                echo "NAME=`get_mh_bf_rep_name $PORT_NAME $IFINDEX`"
                exit 0
        fi

        echo NAME=`echo ${1} | sed -e "s/\(pf[[:digit:]]\+\)$/\1hpf/;s/c[[:digit:]]\+//"`
        exit 0
fi

# Ditch stdout, use stderr as new stdout:
if udevadm test-builtin path_id "/sys$DEVPATH" 2>&1 1>/dev/null \
	| grep -q 'Network interface NamePolicy= disabled'
then
	echo "NAME=$INTERFACE"
	exit 0
fi

# for pf and uplink rep fall to slot or path.
udevversion=`/sbin/udevadm --version`
skip=0
if [ "$ID_NET_DRIVER" == "mlx5e_rep" ]; then
    if [ "$udevversion" == "219" ] || [ "$udevversion" == "229" ]; then
        skip=1
    fi
fi

if [ "$skip" == "0" ]; then
	if [ -n "$ID_NET_NAME_SLOT" ]; then
	    NAME="${ID_NET_NAME_SLOT%%np[[:digit:]]}"
	elif [ -n "$ID_NET_NAME_PATH" ]; then
	    NAME="${ID_NET_NAME_PATH%%np[[:digit:]]}"
	fi

	if [ -n "$NAME" ]; then
	    NAME=`echo $NAME | sed 's/npf.vf/_/'`
	    NAME=`echo $NAME | sed 's/np.v/v/'`
	    echo NAME=$NAME
	    exit
	fi
fi

if [ -z "$SWID" ]; then
    exit 0
fi

# for SF mdev devices
function get_sf_rep_name() {
    b=`udevadm info -q property -p /sys/bus/pci/devices/$1/net/* | grep "ID_PATH=" | cut -d- -f2 | cut -d: -f2`
    d=`udevadm info -q property -p /sys/bus/pci/devices/$1/net/* | grep "ID_PATH=" | cut -d- -f2 | cut -d: -f3 | cut -d. -f1`
    f=`udevadm info -q property -p /sys/bus/pci/devices/$1/net/* | grep "ID_PATH=" | cut -d- -f2 | cut -d: -f3 | cut -d. -f2`
    echo ${b}_${d}_${f}_${PORT_NAME##*p}
}

# get phys_switch_id by mdev
function get_mdev_swid() {
    rep_name=`cat /sys/bus/mdev/devices/$1/devlink-compat-config/netdev 2>/dev/null`
    cat /sys/class/net/${rep_name}/phys_switch_id 2>/dev/null
}

# get phys_port_name by mdev
function get_mdev_port_name() {
    rep_name=`cat /sys/bus/mdev/devices/$1/devlink-compat-config/netdev 2>/dev/null`
    cat /sys/class/net/${rep_name}/phys_port_name 2>/dev/null
}

# try at most two times
for cnt in {1..2}; do
    # wait for mdev to be created
    sleep 0.5
    for dev in `ls -l /sys/class/net/*/device | cut -d "/" -f9-`; do
        if [ -h /sys/bus/mdev/devices/${dev} ]; then
            for pci in `ls /sys/bus/pci/devices/*`; do
                # searching for pci dev that owns this mdev
                if [ -a /sys/bus/pci/devices/${pci}/${dev} ]; then
                    _swid=`get_mdev_swid $dev`
                    _portname=`get_mdev_port_name $dev`
                    if [ "$_swid" = "$SWID" ] && [ "$_portname" = "$PORT_NAME" ]
                    then
                        echo "NAME=`get_sf_rep_name $pci`"
                        exit
                    fi
                fi
            done
        fi
    done
done

# for VFs
function get_pci_name() {
    local a=`udevadm info -q property -p /sys/bus/pci/devices/$1/net/* | grep $2 | cut -d= -f2`
    echo ${a%%np[[:digit:]]}
}

# get phys_switch_id by pci
function get_pci_swid() {
    cat /sys/bus/pci/devices/$1/net/*/phys_switch_id | head -1 2>/dev/null
}

# get phys_port_name by pci
function get_pci_port_name() {
    cat /sys/bus/pci/devices/$1/net/*/phys_port_name | head -1 2>/dev/null
}

# for vf rep get parent slot/path.
parent_phys_port_name=${PORT_NAME%vf*}
parent_phys_port_name=${parent_phys_port_name//pf}
((parent_phys_port_name&=0x7))
parent_phys_port_name="p$parent_phys_port_name"
# try at most two times
for cnt in {1..2}; do
    for pci in `ls -l /sys/class/net/*/device | cut -d "/" -f9-`; do
        if [ -h /sys/bus/pci/devices/${pci}/physfn ]; then
            continue
        fi
        _swid=`get_pci_swid $pci`
        _portname=`get_pci_port_name $pci`
        if [ -z $_portname ]; then
            # no uplink rep so no phys port name
            continue
        fi

        if [ -n "$ID_PATH" ]; then
            if [ "$ID_PATH" != "pci-$pci" ]; then
                continue
            fi
        else
            if [ "$_swid" != "$SWID" ]; then
                continue
            fi
        fi

        if [ "$_portname" != "$parent_phys_port_name" ]; then
            continue
        fi

        parent_path=`get_pci_name $pci ID_NET_NAME_SLOT`
        if [ -z "$parent_path" ]; then
            parent_path=`get_pci_name $pci ID_NET_NAME_PATH`
        fi
        echo "NAME=${parent_path}_$PORT"
        exit
    done

    # swid changes when entering lag mode.
    # So if we didn't find current swid, get the updated one.
    SWID=`cat /sys/class/net/$INTERFACE/phys_switch_id`
done
