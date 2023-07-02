DESTDIR =
INSTALL = install
UDEV_DIR = /lib/udev
SBIN_TDIR = /sbin
SBIN_DIR = /usr/sbin
BIN_DIR = /usr/bin
MAN8_DIR = /usr/share/man/man8
PYTHON_DIR = /usr/share/mlnx-tools/python
PYTHON_SBIN_BASE = ib2ib_setup mlnx_tune
PYTHON_SBIN = $(patsubst %,python/%,$(PYTHON_SBIN_BASE))
# Note: subdir is Python with capital P:
PYTHON_SCR = $(wildcard python/[a-z]*)
PYTHON_BIN = $(filter-out $(PYTHON_SBIN),$(PYTHON_SCR))

all:

install:
	$(INSTALL) -d $(DESTDIR)$(SBIN_TDIR)
	$(INSTALL) -d $(DESTDIR)$(SBIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(BIN_DIR)
	$(INSTALL) -d $(DESTDIR)$(UDEV_DIR)
	$(INSTALL) -d $(DESTDIR)$(MAN8_DIR)
	$(INSTALL) -d $(DESTDIR)$(PYTHON_DIR)

	$(INSTALL) -m 0755 udev/* -t $(DESTDIR)$(UDEV_DIR)/
	$(INSTALL) -m 0755 tsbin/* -t $(DESTDIR)$(SBIN_TDIR)/
	$(INSTALL) -m 0755 sbin/* -t $(DESTDIR)$(SBIN_DIR)/
	$(INSTALL) -m 0644 man/man8/*.8 -t $(DESTDIR)$(MAN8_DIR)/
	$(INSTALL) -m 0644 python/Python/*.py -t $(DESTDIR)$(PYTHON_DIR)/
	$(INSTALL) -m 0755 $(PYTHON_SBIN) -t $(DESTDIR)$(SBIN_DIR)/
	$(INSTALL) -m 0755 $(PYTHON_BIN) -t $(DESTDIR)$(BIN_DIR)/
