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
# Author: Moni Shoua <monis@mellanox.com>
#

black='\E[30;50m'
red='\E[31;50m'
green='\E[32;50m'
yellow='\E[33;50m'
blue='\E[34;50m'
magenta='\E[35;50m'
cyan='\E[36;50m'
white='\E[37;50m'

bold='\033[1m'

gid_count=0

# cecho (color echo) prints text in color.
# first parameter should be the desired color followed by text
function cecho ()
{
	echo -en $1
	shift
	echo -n $*
	tput sgr0
}

# becho (color echo) prints text in bold.
becho ()
{
	echo -en $bold
	echo -n $*
	tput sgr0
}

function print_gids()
{
	dev=$1
	port=$2
	for gf in /sys/class/infiniband/$dev/ports/$port/gids/* ; do
		gid=$(cat $gf);
		if [ $gid = 0000:0000:0000:0000:0000:0000:0000:0000 ] ; then
			continue
		fi
		echo -e $(basename $gf) "\t" $gid
	done
}

echo -e "DEV\tPORT\tINDEX\tGID\t\t\t\t\tIPv4  \t\tVER\tDEV"
echo -e "---\t----\t-----\t---\t\t\t\t\t------------  \t---\t---"
DEVS=$1
if [ -z "$DEVS" ] ; then
	DEVS=$(ls /sys/class/infiniband/)
fi
for d in $DEVS ; do
	for p in $(ls /sys/class/infiniband/$d/ports/) ; do
		for g in $(ls /sys/class/infiniband/$d/ports/$p/gids/) ; do
			gid=$(cat /sys/class/infiniband/$d/ports/$p/gids/$g);
			if [ $gid = 0000:0000:0000:0000:0000:0000:0000:0000 ] ; then
				continue
			fi
			if [ $gid = fe80:0000:0000:0000:0000:0000:0000:0000 ] ; then
				continue
			fi
			_ndev=$(cat /sys/class/infiniband/$d/ports/$p/gid_attrs/ndevs/$g 2>/dev/null)
			__type=$(cat /sys/class/infiniband/$d/ports/$p/gid_attrs/types/$g 2>/dev/null)
			_type=$(echo $__type| grep -o "[Vv].*")
			if [ $(echo $gid | cut -d ":" -f -1) = "0000" ] ; then
				ipv4=$(printf "%d.%d.%d.%d" 0x${gid:30:2} 0x${gid:32:2} 0x${gid:35:2} 0x${gid:37:2})
				echo -e "$d\t$p\t$g\t$gid\t$ipv4  \t$_type\t$_ndev"
			else
				echo -e "$d\t$p\t$g\t$gid\t\t\t$_type\t$_ndev"
			fi
			gid_count=$(expr 1 + $gid_count)
		done #g (gid)
	done #p (port)
done #d (dev)

echo n_gids_found=$gid_count
