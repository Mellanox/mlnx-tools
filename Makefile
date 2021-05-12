DESTDIR =
INSTALL = install
UDEV_DIR = /lib/udev
SBIN_TDIR = /sbin
SBIN_DIR = /usr/sbin
PYTHON = python3
PYTHON_SETUP_EXTRA_ARGS =

all:

install:
	$(INSTALL) -d $(DESTDIR)$(SBIN_TDIR)
	$(INSTALL) -d $(DESTDIR)$(SBIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_DIR)

	$(INSTALL) -m 0755 udev/* -t $(DESTDIR)$(UDEV_DIR)/
	$(INSTALL) -m 0755 tsbin/* -t $(DESTDIR)$(SBIN_TDIR)/
	$(INSTALL) -m 0755 sbin/* -t $(DESTDIR)$(SBIN_DIR)/

	cd python; $(PYTHON) ./setup.py install $(PYTHON_SETUP_EXTRA_ARGS)

