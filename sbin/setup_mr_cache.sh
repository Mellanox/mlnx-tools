#!/bin/bash -eE
#
# Copyright (c) 2017 Mellanox Technologies. All rights reserved.
#
# Author: Artemy Kovalyov <artemyko@mellanox.com>
#
# Since MR registration is slow process we want to keep enough
# preallocated MKeys in MR cache.
#

ilog2() {
	local x=$1 c=0 v=1
	while [ $x -gt $v ] ; do
		v=$((v * 2))
		c=$((c + 1))
	done
	echo $c
}

setup_bucket() {
	local order=$1 size=$2 opt=$3
	local limit=$(((size+1)/2))

	[ -d $mr_cache/$order ] || return

	if [ "$opt" = "no-force" ] ; then
		local cur_limit=$(cat $mr_cache/$order/limit)
		[ $cur_limit -ge $limit ] && return
	fi

	echo -n 0 >$mr_cache/$order/limit
	echo -n $size >$mr_cache/$order/size
	while ! echo -n $limit >$mr_cache/$order/limit 2>/dev/null ; do
		true
	done
}

dev=$1

if [ -z "$dev" ] ; then
	echo "Usage $0 <dev>"
	exit 1
fi

if [ $(id -u) -ne 0 ] ; then
	echo "Must be root"
	exit 1
fi

[ -e "/sys/class/infiniband/$dev/device/physfn" ] && exit 0

mr_cache="/sys/class/infiniband/$dev/mr_cache"
new_order=14
max_order=22     # currently we support cache buckets for MRs up to 16G

[ -d $mr_cache/$max_order ] || exit 0

mem_total=$(cat /proc/meminfo | awk /MemTotal/{print\$2*1024})
nproc=$(grep ^processor /proc/cpuinfo | wc -l)
log_nproc=$(ilog2 $nproc)
page_shift=$(ilog2 $(getconf PAGESIZE))
# order is log base 2 of translation entries number
# in worst case translation entry points to single page
mem_order=$(($(ilog2 $mem_total) - page_shift))

setup_bucket $((max_order+1)) $((mem_total/1073741824+1)) # implicit MTTs 1G
setup_bucket $((max_order+2)) $nproc  # assume 1 KSM per core

# If there are more physical memory then number of cores * 16G
# just allocate enough big MRs
if [ $mem_order -gt $((max_order + log_nproc)) ] ; then
	setup_bucket $max_order $((1 << (mem_order-max_order)))
	exit 0
fi

# Prepare MR cache buckets to cover all physical memory
# using single process or multiple processes up to number of cores
for ((order=new_order; order<=max_order; order++)) do
	if [ $order -lt $((mem_order - log_nproc)) ] ; then
		setup_bucket $order $nproc no-force
	elif [ $order -le $mem_order ] ; then
		setup_bucket $order $((1 << (mem_order-order)))
	else
		setup_bucket $order 0
	fi
done

echo -n 1 >$mr_cache/rel_imm

