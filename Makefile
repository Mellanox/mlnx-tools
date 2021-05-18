DESTDIR =
INSTALL = install
UDEV_DIR = /lib/udev
SBIN_TDIR = /sbin
SBIN_DIR = /usr/sbin
BIN_DIR = /usr/bin
MAN8_DIR = /usr/share/man/man8
PYTHON = python3
PYTHON_SETUP_EXTRA_ARGS =

all:

install:
	$(INSTALL) -d $(DESTDIR)$(SBIN_TDIR)
	$(INSTALL) -d $(DESTDIR)$(SBIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_DIR)
	$(INSTALL) -d $(DESTDIR)$(MAN8_DIR)

	$(INSTALL) -m 0755 udev/* -t $(DESTDIR)$(UDEV_DIR)/
	$(INSTALL) -m 0755 tsbin/* -t $(DESTDIR)$(SBIN_TDIR)/
	$(INSTALL) -m 0755 sbin/* -t $(DESTDIR)$(SBIN_DIR)/
	$(INSTALL) -m 0644 man/man8/*.8 -t $(DESTDIR)$(MAN8_DIR)/

	cd python; $(PYTHON) ./setup.py install $(PYTHON_SETUP_EXTRA_ARGS)
	# Originally resided in sbin and not in bin, as setup.py installs:
	mv $(DESTDIR)$(BIN_DIR)/ib2ib_setup $(DESTDIR)$(SBIN_DIR)/
