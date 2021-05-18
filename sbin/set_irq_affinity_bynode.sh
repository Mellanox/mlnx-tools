#! /bin/bash
#
# Copyright (c) 2017 Mellanox Technologies. All rights reserved.
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
if [ -z $2 ]; then
	echo "usage: $0 <node id> <interface or IB device> [2nd interface or IB device]"
	exit 1
fi

source common_irq_affinity.sh

node=$1
interface=$2
interface2=$3

IRQS=$( get_irq_list $interface )
if [ -z "$IRQS" ] ; then
        echo No IRQs found for $interface.
	exit 1
fi

echo Discovered irqs for $interface: $IRQS

if [ $interface2 ]; then

	IRQS_2=$( get_irq_list $interface2 )
	if [ -z "$IRQS_2" ] ; then
	        echo No IRQs found for $interface2.
		exit 1
	fi
	echo Discovered irqs for $interface2: $IRQS_2
        echo "---------------------------------------"
        echo "Optimizing IRQs for Dual port traffic"
        echo "---------------------------------------"
else
        echo "-------------------------------------"
        echo "Optimizing IRQs for Single port traffic"
        echo "-------------------------------------"
fi

cpulist=$(cat /sys/devices/system/node/node$node/cpulist )
if [ "$(echo $?)" != "0" ]; then
	echo "Node id '$node' does not exists."
	exit
fi
CORES=$( echo $cpulist | sed 's/,/ /g' | wc -w )
for word in $(seq 1 $CORES)
do
	SEQ=$(echo $cpulist | cut -d "," -f $word | sed 's/-/ /')
	if [ "$(echo $SEQ | wc -w)" != "1" ]; then
		CPULIST="$CPULIST $( echo $(seq $SEQ) | sed 's/ /,/g' )"
	fi
done
if [ "$CPULIST" != "" ]; then
	cpulist=$(echo $CPULIST | sed 's/ /,/g')
fi
CORES=$( echo $cpulist | sed 's/,/ /g' | wc -w )

I=1
for IRQ in $IRQS
do
	core_id=$(echo $cpulist | cut -d "," -f $I)
	echo Assign irq $IRQ core_id $core_id
	affinity=$( core_to_affinity $core_id )
        set_irq_affinity $IRQ $affinity
	if [ -z $interface2 ]; then
		I=$(( (I%CORES) + 1 ))
	else
		I=$(( (I%(CORES/2)) + 1 ))
	fi
done

I=$(( (CORES/2) + 1 ))
for IRQ in $IRQS_2
do
	core_id=$(echo $cpulist | cut -d "," -f $I)
	echo Assign irq $IRQ core_id $core_id
	affinity=$( core_to_affinity $core_id )
        set_irq_affinity $IRQ $affinity
	I=$(( (I%(CORES/2)) + 1 + (CORES/2) ))
done
echo
echo done.


