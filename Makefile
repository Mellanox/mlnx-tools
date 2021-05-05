DESTDIR =
INSTALL = install
UDEV_DIR = /lib/udev
UDEV_RULES_DIR = /lib/udev/rules.d
SYSTEMD_DIR = /lib/systemd/system
MODPROBE_DIR = /lib/modprobe.d
SBIN_TDIR = /sbin
BIN_DIR = /usr/bin
SBIN_DIR = /usr/sbin
PYTHON = python3
PYTHON_SETUP_EXTRA_ARGS =

UDEV_RULES = \
  kernel-boot/82-net-setup-link.rules \
  kernel-boot/91-tmfifo_net.rules \
  kernel-boot/92-oob_net.rules \
  #
UDEV_SCRIPTS = kernel-boot/vf-net-link-name.sh

SYSTEMD_SERVICES = kernel-boot/mlnx-bf-ctl.service

SBIN_TDIR_PROGRAMS = \
  kernel-boot/mlnx_bf_configure \
  kernel-boot/mlnx-sf \
  ofed_scripts/sysctl_perf_tuning \
  #

BIN_PROGRAMS = ofed_scripts/ibdev2netdev

SBIN_PROGRAMS = \
  ofed_scripts/show_gids \
  ofed_scripts/cma_roce_mode \
  ofed_scripts/cma_roce_tos \
  ofed_scripts/*affinity* \
  ofed_scripts/setup_mr_cache.sh \
  ofed_scripts/odp_stat.sh \
  ofed_scripts/show_counters \
  ofed_scripts/mlnx*hlk \
  ofed_scripts/roce_config \
  #

MODPROBE_CONF = kernel-boot/mlnx-bf.conf

all:

install:
	$(INSTALL) -d $(DESTDIR)$(SBIN_TDIR)
	$(INSTALL) -d $(DESTDIR)$(SBIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(BIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_RULES_DIR)
	$(INSTALL) -d $(DESTDIR)$(SYSTEMD_DIR)
	$(INSTALL) -d $(DESTDIR)$(MODPROBE_DIR)

	$(INSTALL) -m 0755 $(UDEV_SCRIPTS) -t $(DESTDIR)$(UDEV_DIR)/
	$(INSTALL) -m 0755 $(SBIN_TDIR_PROGRAMS) -t $(DESTDIR)$(SBIN_TDIR)/
	$(INSTALL) -m 0755 $(BIN_PROGRAMS) -t $(DESTDIR)$(BIN_DIR)/
	$(INSTALL) -m 0755 $(SBIN_PROGRAMS) -t $(DESTDIR)$(SBIN_DIR)/
	$(INSTALL) -m 0644 $(UDEV_RULES) -t $(DESTDIR)$(UDEV_RULES_DIR)/
	$(INSTALL) -m 0644 $(SYSTEMD_SERVICES) -t $(DESTDIR)$(SYSTEMD_DIR)/
	$(INSTALL) -m 0644 $(MODPROBE_CONF) -t $(DESTDIR)$(MODPROBE_DIR)/

	cd ofed_scripts/utils;	$(PYTHON) ./setup.py install $(PYTHON_SETUP_EXTRA_ARGS)

