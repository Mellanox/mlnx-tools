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

from distutils.core import setup
import os

pkg_version = os.environ['PKG_VERSION']

setup(name='mlnx-tools',
      version=pkg_version,
      author='Vladimir Sokolovsky',
      author_email='vlad@nvidia.com',
      url='https://github.com/Mellanox/mlnx-tools',
      scripts=['mlnx_qos', 'tc_wrap.py', 'mlnx_perf', 'mlnx_dump_parser',
        'mlx_fs_dump', 'ib2ib_setup', 'mlnx_tune'],
      py_modules=['netlink', 'dcbnetlink', 'genetlink'],
      )
