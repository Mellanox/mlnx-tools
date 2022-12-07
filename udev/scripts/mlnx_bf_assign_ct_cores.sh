#!/bin/bash
#
# Copyright (c) 2020 Mellanox Technologies. All rights reserved.
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

#assign the 7th core for ct del actions
del_coremask=40

#assign the 8th core for ct del actions
add_coremask=80

echo ff > /sys/devices/virtual/workqueue/cpumask

if [ -f /sys/devices/virtual/workqueue/nf_ft_offload_add/cpumask -a -f /sys/devices/virtual/workqueue/nf_ft_offload_del/cpumask ]; then
	echo $del_coremask > /sys/devices/virtual/workqueue/nf_ft_offload_del/cpumask
	echo $add_coremask > /sys/devices/virtual/workqueue/nf_ft_offload_add/cpumask
	echo "Bluefield ct offload: add wq coremask $add_coremask, del wq coremask $del_coremask" >/dev/kmsg

        echo 1 > /sys/devices/virtual/workqueue/nf_ft_offload_add/max_active
        echo 1 > /sys/devices/virtual/workqueue/nf_ft_offload_del/max_active
else
	echo "cannot set ct offload coremasks" >/dev/kmsg
fi
