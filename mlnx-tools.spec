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
%global mlnx_python_sitelib %{python3_sitelib}
BuildRequires: python3
# mlnx_tune is python2 but is not important enough to create a dependency
# on python2 in a python3 system:
%global __requires_exclude_from mlnx_tune
%else
%global mlnx_python_sitelib %{python2_sitelib}
%endif

%global files_list mlnx-tools-files

%prep
%setup -n %{name}-%{version}

%install
rm -rf %{buildroot}

export PKG_VERSION="%{version}"
%make_install PYTHON="%__python" PYTHON_SETUP_EXTRA_ARGS="-O1 --root=%{buildroot} --record $PWD/%{files_list}"

# Moved in the Makefile:
sed -i -e '/ib2ib_setup/s|/usr/bin|/usr/sbin|' %{files_list}

%clean
rm -rf %{buildroot}

%files -f %{files_list}
%doc doc/*
%defattr(-,root,root,-)
/sbin/sysctl_perf_tuning
/sbin/mlnx_bf_configure
/sbin/mlnx_bf_configure_ct
/sbin/mlnx-sf
%{_sbindir}/cma_roce_mode
%{_sbindir}/cma_roce_tos
%{_sbindir}/common_irq_affinity.sh
%{_sbindir}/compat_gid_gen
%{_sbindir}/mlnx_affinity
%{_sbindir}/mlnx_tune
%{_sbindir}/set_irq_affinity_bynode.sh
%{_sbindir}/set_irq_affinity_cpulist.sh
%{_sbindir}/set_irq_affinity.sh
%{_sbindir}/show_counters
%{_sbindir}/show_gids
%{_sbindir}/show_irq_affinity_hints.sh
%{_sbindir}/show_irq_affinity.sh
%{_mandir}/man8/ib2ib_setup.8*
/lib/udev/mlnx_bf_udev

%changelog
* Wed May 12 2021 Tzafrir Cohen <nvidia@cohens.org.il> - 5.2.0-1
- MLNX_OFED branch
* Wed Nov  1 2017 Vladimir Sokolovsky <vlad@mellanox.com> - 4.6.0-1
- Initial packaging
