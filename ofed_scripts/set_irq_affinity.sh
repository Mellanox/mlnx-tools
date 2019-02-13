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
if [ -z $1 ]; then
	echo "usage: $0 <interface or IB device> [2nd interface or IB device]"
	exit 1
fi

source common_irq_affinity.sh

CORES=$((`cat /proc/cpuinfo | grep processor | tail -1 | awk '{print $3}'`+1))
hop=1
INT1=$1
INT2=$2

if [ -z $INT2 ]; then
	limit_1=$CORES
	echo "---------------------------------------"
	echo "Optimizing IRQs for Single port traffic"
	echo "---------------------------------------"
else
	echo "-------------------------------------"
	echo "Optimizing IRQs for Dual port traffic"
	echo "-------------------------------------"
	limit_1=$((CORES/2))
	limit_2=$CORES
	IRQS_2=$( get_irq_list $INT2 )
	if [ -z "$IRQS_2" ] ; then
		echo No IRQs found for $INT2.
		exit 1
	fi
fi

IRQS_1=$( get_irq_list $INT1 )

if [ -z "$IRQS_1" ] ; then
	echo No IRQs found for $INT1.
else
	echo Discovered irqs for $INT1: $IRQS_1
	core_id=0
	for IRQ in $IRQS_1
	do
		if is_affinity_hint_set $IRQ ; then
			affinity=$(cat /proc/irq/$IRQ/affinity_hint)
			set_irq_affinity $IRQ $affinity
			echo Assign irq $IRQ to its affinity_hint $affinity
		else
			echo Assign irq $IRQ core_id $core_id
			affinity=$( core_to_affinity $core_id )
			set_irq_affinity $IRQ $affinity
			core_id=$(( core_id + $hop ))
			if [ $core_id -ge $limit_1 ] ; then core_id=0; fi
		fi
	done
fi

echo

if [ "$INT2" != "" ]; then
	IRQS_2=$( get_irq_list $INT2 )
	if [ -z "$IRQS_2" ]; then
		echo No IRQs found for $INT2.
		exit 1
	fi

	echo Discovered irqs for $INT2: $IRQS_2
	core_id=$limit_1
	for IRQ in $IRQS_2
	do
		if is_affinity_hint_set $IRQ ; then
			affinity=$(cat /proc/irq/$IRQ/affinity_hint)
			set_irq_affinity $IRQ $affinity
			echo Assign irq $IRQ to its affinity_hint $affinity
		else
			echo Assign irq $IRQ core_id $core_id
			affinity=$( core_to_affinity $core_id )
			set_irq_affinity $IRQ $affinity
			core_id=$(( core_id + $hop ))
			if [ $core_id -ge $limit_2 ] ; then core_id=$limit_1; fi
		fi
	done
fi
echo
echo done.

