#!/bin/bash

dev=$1
declare -A verbs iodp
pagesize=$(getconf PAGESIZE)
iodp[23]=leaf
iodp[24]=iodp

for v in /sys/class/infiniband_verbs/* ; do
	[ -d $v ] || continue
	verbs[$(cat $v/ibdev)]=$v
done

v_or_na() {
	v=$(eval "$@" 2>/dev/null) && echo $v || echo NA
}

fix_tab() {
	[ $1 -ge 10000000 ] && echo $1 || echo "$1\t"
}

vt_or_na() {
	v=$(eval "$@" 2>/dev/null) && echo $(fix_tab $v) || echo "NA\t"
}

pf_or_na() {
	v=$(eval "$@" 2>/dev/null) && echo $((v-1)) || echo NA
}

if which numfmt >/dev/null 2>&1 ; then
fmt() {
	[ "${iodp[$mm]}" ] && echo ${iodp[$mm]} || \
	echo $((pagesize << $1)) | numfmt --to=iec
}
else
fmt() {
	[ "${iodp[$mm]}" ] && echo ${iodp[$mm]} || echo 2^$1
}
fi

for i in /sys/class/infiniband/* ; do
	d=$(basename $i)
	[ "$dev" -a "$d" != "$dev" ] && continue

	p=$(basename $(dirname $(dirname $(readlink $i))))
	ddir="/sys/kernel/debug/mlx5/$p/odp_stats"

	[ "$a" ] && echo
	a=1
	echo -ne "$d\n"
	echo -ne "type\t\t\tpages\t\tcount\n"
	echo -ne "odp regions\t\t"
	echo -ne "$(vt_or_na sudo cat $ddir/num_odp_mr_pages)\t"
	echo -ne "$(v_or_na sudo cat $ddir/num_odp_mrs)\n"
	echo -ne "odp page faults\t\t"
	echo -ne "$(vt_or_na cat ${verbs[$d]}/num_page_fault_pages)\t"
	echo -ne "$(v_or_na cat ${verbs[$d]}/num_page_faults)\n"
	echo -ne "odp invalidations\t"
	echo -ne "$(vt_or_na cat ${verbs[$d]}/num_invalidation_pages)\t"
	echo -ne "$(v_or_na cat ${verbs[$d]}/num_invalidations)\n"
	echo -ne "odp prefetches\t\t"
	echo -ne "$(vt_or_na cat ${verbs[$d]}/num_prefetch_pages)\t"
	echo -ne "$(v_or_na cat ${verbs[$d]}/num_prefetches_handled)\n"
	echo -ne "active prefetches\t\t\t"
	echo -ne "$(pf_or_na sudo cat $ddir/num_prefetch)\n"
	echo -ne "odp fault contentions\t\t\t"
	echo -ne "$(v_or_na cat ${verbs[$d]}/invalidations_faults_contentions)\n"
	echo -ne "odp faults wrong key\t\t\t"
	echo -ne "$(v_or_na sudo cat $ddir/num_mrs_not_found)\n"
	echo -ne "odp unhandled faults\t\t\t"
	echo -ne "$(v_or_na sudo cat $ddir/num_failed_resolutions)\n"
	[ -d /sys/class/infiniband/$d/mr_cache ] || continue
	echo -ne "\t\t\tcur\tsize\tlimit\tmiss\n"
	for mm in $(ls -1 /sys/class/infiniband/$d/mr_cache | sort -n) ; do
		m=/sys/class/infiniband/$d/mr_cache/$mm
		[ -d $m ] || continue
		echo -ne "mr cache $(fmt $mm)\t\t"
		echo -ne "$(v_or_na cat $m/cur)\t"
		echo -ne "$(v_or_na cat $m/size)\t"
		echo -ne "$(v_or_na cat $m/limit)\t"
		echo -ne "$(v_or_na cat $m/miss)\n"
	done
done
