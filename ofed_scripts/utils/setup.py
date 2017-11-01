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
from subprocess import Popen, PIPE
from sys import argv

# I would absolutely *LOVE* to be informed of a sexier way to do this,
# preferably without hard-coding Ubuntu as a special case...
try:
    if 'Ubuntu\n' in Popen(('lsb_release', '-si'),
            stdout=PIPE).communicate():
        argv.append('--install-layout=deb')
except OSError:
    pass



setup(name='mlnx-utils',
      version='1.0.3',
      author='Amir Vadai',
      author_email='amirv@mellanox.co.il',
      url='www.mellanox.com',
      scripts=['mlnx_qos', 'tc_wrap.py', 'mlnx_perf', 'mlnx_get_vfs.pl', 'mlnx_qcn', 'mlnx_dump_parser', 'mlx_fs_dump'],
      py_modules=['netlink', 'dcbnetlink', 'genetlink'],
      )
