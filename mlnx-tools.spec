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
Version: 5.2.0
Release: 0%{?_dist}
License: GPLv2
Url: https://github.com/Mellanox/mlnx-tools
Group: Applications/System
Source: https://github.com/Mellanox/mlnx-tools/releases/download/v%{version}/%{name}-%{version}.tar.gz
BuildRoot: %{?build_root:%{build_root}}%{!?build_root:/var/tmp/%{name}}
Vendor: Mellanox Technologies
Obsoletes: mlnx-ofa_kernel < 5.4, mlnx_en-utils < 5.4
%description
Mellanox userland tools and scripts

%global RHEL8 0%{?rhel} >= 8
%global FEDORA3X 0%{?fedora} >= 30
%global SLES15 0%{?suse_version} >= 1500
%global PYTHON3 %{RHEL8} || %{FEDORA3X} || %{SLES15}

%global IS_RHEL_VENDOR "%{_vendor}" == "redhat" || ("%{_vendor}" == "bclinux") || ("%{_vendor}" == "openEuler")

%if %{PYTHON3}
%define __python %{_bindir}/python3
BuildRequires: python3
%endif

%prep
%setup -n %{name}-%{version}

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
%if %{PYTHON3}
mlnx_python_sitelib=%{?python3_sitelib}
%else
mlnx_python_sitelib=%{?python_sitelib}
%endif
if [ "$(echo %{_prefix} | sed -e 's@/@@g')" != "usr" ]; then
	mlnx_python_sitelib=$(echo "$mlnx_python_sitelib" | sed -e 's@/usr@%{_prefix}@')
fi
export PKG_VERSION="%{version}"
%make_install PYTHON="%__python" PYTHON_SETUP_EXTRA_ARGS="-O1 --prefix=%{buildroot}%{_prefix} --install-lib=%{buildroot}${mlnx_python_sitelib}"

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

%files -f mlnx-tools-files
%doc doc/*
%defattr(-,root,root,-)
/sbin/sysctl_perf_tuning
/sbin/mlnx_bf_configure
/sbin/mlnx_bf_configure_ct
/sbin/mlnx-sf
%{_sbindir}/*
%{_bindir}/*
%{_mandir}/man8/*.8*
/lib/udev/mlnx_bf_udev

%changelog
* Wed May 12 2021 Tzafrir Cohen <nvidia@cohens.org.il> - 5.2.0-1
- MLNX_OFED branch
* Wed Nov  1 2017 Vladimir Sokolovsky <vlad@mellanox.com> - 4.6.0-1
- Initial packaging
