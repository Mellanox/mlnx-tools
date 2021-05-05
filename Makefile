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

all:

install:
	$(INSTALL) -d $(DESTDIR)$(SBIN_TDIR)
	$(INSTALL) -d $(DESTDIR)$(SBIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(BIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_RULES_DIR)
	$(INSTALL) -d $(DESTDIR)$(SYSTEMD_DIR)
	$(INSTALL) -d $(DESTDIR)$(MODPROBE_DIR)

	$(INSTALL) -m 0755 udev/* -t $(DESTDIR)$(UDEV_DIR)/
	$(INSTALL) -m 0755 tsbin/* -t $(DESTDIR)$(SBIN_TDIR)/
	$(INSTALL) -m 0755 bin/* -t $(DESTDIR)$(BIN_DIR)/
	$(INSTALL) -m 0755 sbin/* -t $(DESTDIR)$(SBIN_DIR)/
	$(INSTALL) -m 0644 udev_rules/*.rules -t $(DESTDIR)$(UDEV_RULES_DIR)/
	$(INSTALL) -m 0644 systemd/*.service -t $(DESTDIR)$(SYSTEMD_DIR)/
	$(INSTALL) -m 0644 modprobe/*.conf -t $(DESTDIR)$(MODPROBE_DIR)/

	cd python; $(PYTHON) ./setup.py install $(PYTHON_SETUP_EXTRA_ARGS)

