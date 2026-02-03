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

%if 0%{?_ver:1}
%define ver %{_ver}
%else
%define ver 25.10
%endif

%if 0%{?_rel:1}
%define rel %{_rel}
%else
%define rel 1
%endif

%{echo: rel=%{?rel} _rel=%{?_rel} ver=%{?ver} _ver=%{?_ver}}
Summary: Mellanox userland tools and scripts
Name: mlnx-tools
Version: %{?ver}
Release: %{?rel}%{?dist}
License: GPLv2 or BSD
Url: https://github.com/Mellanox/mlnx-tools
Group: Applications/System
Source: https://github.com/Mellanox/mlnx-tools/releases/download/v%{?ver}/%{name}-%{?ver}.tar.gz
BuildRoot: %{?build_root:%{build_root}}%{!?build_root:/var/tmp/%{name}}
Vendor: Mellanox Technologies
Obsoletes: mlnx-ofa_kernel < 5.4, mlnx_en-utils < 5.4
%description
Mellanox userland tools and scripts

%global python_dir %{_datadir}/%{name}/python
%if "%{rhel}" == "7"
%global PYTHON2 1
%else
%global PYTHON2 0
%endif

%prep
%setup -n %{name}-%{?ver}
%if %{PYTHON2}
sed -i -e '1s/python3/python/' \
	python/ib2ib_setup python/mlnx_dump_parser python/mlnx_perf \
	python/mlnx_qos python/mlnx_tune python/mlx_fs_dump python/tc_wrap.py \
	python/Python/dcbnetlink.py
%endif

%install
rm -rf %{buildroot}

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
export PKG_VERSION="%{?ver}"
%make_install

%if "%{_prefix}" != "/usr"
	conf_env=/etc/profile.d/mlnx-tools.sh
	install -d %{buildroot}/etc/profile.d
	add_env %{buildroot}$conf_env PATH %{_bindir}
	add_env %{buildroot}$conf_env PATH %{_sbindir}
	echo $conf_env >> mlnx-tools-files
%endif
install -d %{buildroot}/etc/mellanox/hugepages.d

%clean
rm -rf %{buildroot}

%if "%{_prefix}" != "/usr"
%files -f mlnx-tools-files
%else
%files
%endif
%license LICENSE
%doc doc/*
%defattr(-,root,root,-)
/sbin/sysctl_perf_tuning
/sbin/mlnx_bf_configure
/sbin/mlnx-sf
/sbin/doca-hugepages
%{_sbindir}/*
%{_bindir}/*
%{_mandir}/man8/*.8*
%{python_dir}/dcbnetlink.py*
%{python_dir}/netlink.py*
%exclude %{python_dir}/__pycache__/*.pyc
/lib/udev/mlnx_bf_udev
/etc/mellanox/hugepages.d

%changelog
* Wed May 12 2021 Tzafrir Cohen <nvidia@cohens.org.il> - 5.2.0-1
- MLNX_OFED branch
* Wed Nov  1 2017 Vladimir Sokolovsky <vlad@mellanox.com> - 4.6.0-1
- Initial packaging
