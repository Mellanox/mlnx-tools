#!/bin/bash

PATH=/bin:/sbin:/usr/bin

for dev in `lspci -n -d 15b3:a2d2 | cut -d ' ' -f 1`
do
	if (mstconfig -d ${dev} q 2> /dev/null | grep -q "ECPF_ESWITCH_MANAGER.*ECPF(1)"); then
		devlink dev eswitch set pci/0000:${dev} mode switchdev
	fi
done
