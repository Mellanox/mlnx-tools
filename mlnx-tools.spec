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
#

Summary: Mellanox userland tools and scripts
Name: mlnx-tools
Version: 4.6.0
Release: 0%{?_dist}
License: GPLv2
Url: https://github.com/Mellanox/mlnx-tools
Group: Applications/System
Source: https://github.com/Mellanox/mlnx-tools/releases/download/v%{version}/%{name}-%{version}.tar.gz
BuildRoot: %{?build_root:%{build_root}}%{!?build_root:/var/tmp/%{name}}
Vendor: Mellanox Technologies
Requires: perl
Requires: python
%description
Mellanox userland tools and scripts

%prep
%setup -n %{name}-%{version}

%install

add_env()
{
	efile=$1
	evar=$2
	epath=$3

cat >> $efile << EOF
if ! echo \$${evar} | grep -q $epath ; then
	export $evar=$epath:\$$evar
fi

EOF
}

touch mlnx-tools-files
cd ofed_scripts/utils
mlnx_python_sitelib=%{python_sitelib}
if [ "$(echo %{_prefix} | sed -e 's@/@@g')" != "usr" ]; then
	mlnx_python_sitelib=$(echo %{python_sitelib} | sed -e 's@/usr@%{_prefix}@')
fi
python setup.py install -O1 --prefix=%{buildroot}%{_prefix} --install-lib=%{buildroot}${mlnx_python_sitelib}
cd -

install -d %{buildroot}/sbin
install -d %{buildroot}%{_sbindir}
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_sysconfdir}/lib/udev
install -d %{buildroot}%{_sysconfdir}/udev/rules.d
install -d %{buildroot}%{_sysconfdir}/modprobe.d
install -m 0755 ofed_scripts/sysctl_perf_tuning     %{buildroot}/sbin
install -m 0755 ofed_scripts/cma_roce_mode          %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/cma_roce_tos           %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/*affinity*             %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/setup_mr_cache.sh      %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/odp_stat.sh            %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/show_counters          %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/show_gids              %{buildroot}%{_sbindir}
install -m 0755 ofed_scripts/ibdev2netdev           %{buildroot}%{_bindir}
install -m 0755 ofed_scripts/roce_config.sh         %{buildroot}%{_bindir}/roce_config
install -m 0755 kernel-boot/vf-net-link-name.sh     %{buildroot}%{_sysconfdir}/lib/udev/
install -m 0644 kernel-boot/82-net-setup-link.rules %{buildroot}%{_sysconfdir}/udev/rules.d/
install -m 0644 kernel-boot/91-tmfifo_net.rules     %{buildroot}%{_sysconfdir}/udev/rules.d/
install -m 0644 kernel-boot/mlnx-eswitch.service    %{buildroot}%{_sysconfdir}/systemd/system/
install -m 0644 kernel-boot/mlnx-eswitch.conf       %{buildroot}%{_sysconfdir}/modprobe.d/
install -m 0755 kernel-boot/mlnx_eswitch_set.sh     %{buildroot}/sbin

if [ "$(echo %{_prefix} | sed -e 's@/@@g')" != "usr" ]; then
	conf_env=/etc/profile.d/mlnx-tools.sh
	install -d %{buildroot}/etc/profile.d
	add_env %{buildroot}$conf_env PYTHONPATH $mlnx_python_sitelib
	add_env %{buildroot}$conf_env PATH %{_bindir}
	add_env %{buildroot}$conf_env PATH %{_sbindir}
	echo $conf_env >> mlnx-tools-files
fi
find %{buildroot}${mlnx_python_sitelib} -type f -print | sed -e 's@%{buildroot}@@' >> mlnx-tools-files

%clean
rm -rf %{buildroot}

%preun
/usr/bin/systemctl disable mlnx-eswitch.service >/dev/null 2>&1 || :

%post
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
/usr/bin/systemctl enable mlnx-eswitch.service >/dev/null 2>&1 || :

%files -f mlnx-tools-files
%defattr(-,root,root,-)
/sbin/sysctl_perf_tuning
/sbin/mlnx_eswitch_set.sh
%{_sbindir}/*
%{_bindir}/*
/lib/udev/vf-net-link-name.sh
%{_sysconfdir}/udev/rules.d/82-net-setup-link.rules
%{_sysconfdir}/udev/rules.d/91-tmfifo_net.rules
%{_sysconfdir}/systemd/system/mlnx-eswitch.service
%{_sysconfdir}/modprobe.d/mlnx-eswitch.conf

%changelog
* Wed Nov 1 2017 Vladimir Sokolovsky <vlad@mellanox.com>
- Initial packaging
