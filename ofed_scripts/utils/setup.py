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



setup(name='ofed-le-utils',
      version='1.0.3',
      author='Amir Vadai',
      author_email='amirv@mellanox.co.il',
      url='www.mellanox.co.il',
      scripts=['mlnx_qos', 'tc_wrap.py', 'mlnx_perf', 'mlnx_get_vfs.pl', 'mlnx_qcn', 'mlnx_dump_parser', 'mlx_fs_dump'],
      py_modules=['netlink', 'dcbnetlink', 'genetlink'],
      )
