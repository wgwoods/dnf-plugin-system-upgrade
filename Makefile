include const.mk

LN ?= ln
INSTALL ?= install -p
PYTHON ?= python

PYTHON_VERSION=$(shell $(PYTHON) -c \
    "import sys; print(sys.version_info.major)")
PYTHON_LIBDIR=$(shell $(PYTHON) -c \
    "from distutils import sysconfig; print(sysconfig.get_python_lib())")
PLUGINDIR=$(PYTHON_LIBDIR)/dnf-plugins

UNITDIR=$(shell pkg-config systemd --variable systemdsystemunitdir)
TARGET_WANTSDIR=$(UNITDIR)/system-update.target.wants

LOCALEDIR ?= /usr/share/locale
TEXTDOMAIN = $(PACKAGE)
LANGUAGES = $(patsubst po/%.po,%,$(wildcard po/*.po))
MSGFILES = $(patsubst %,po/%.mo,$(LANGUAGES))

BINDIR ?= /usr/bin
FEDUP_SCRIPT = fedup.sh

SERVICE = dnf-system-upgrade.service
PLUGIN = system_upgrade.py

MANDIR ?= /usr/share/man
MANPAGE = doc/dnf.plugin.system-upgrade.8

build: $(MSGFILES)

po/$(TEXTDOMAIN).pot: $(PLUGIN) $(FEDUP_SCRIPT)
	xgettext -c -s -d $(TEXTDOMAIN) -o $@ $^

po/%.mo : po/%.po
	msgfmt $< -o $@

install: install-plugin install-service install-bin install-lang install-man

install-plugin: $(PLUGIN)
	$(INSTALL) -d $(DESTDIR)$(PLUGINDIR)
	$(INSTALL) -m644 $(PLUGIN) $(DESTDIR)$(PLUGINDIR)
	$(PYTHON) -m py_compile $(DESTDIR)$(PLUGINDIR)/$(PLUGIN)
	$(PYTHON) -O -m py_compile $(DESTDIR)$(PLUGINDIR)/$(PLUGIN)

install-service: $(SERVICE)
	$(INSTALL) -d $(DESTDIR)$(UNITDIR)
	$(INSTALL) -d $(DESTDIR)$(TARGET_WANTSDIR)
	$(INSTALL) -m644 $(SERVICE) $(DESTDIR)$(UNITDIR)
	$(LN) -sf ../$(SERVICE) $(DESTDIR)$(TARGET_WANTSDIR)/$(SERVICE)

install-bin: $(FEDUP_SCRIPT)
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL) -m755 $(FEDUP_SCRIPT) $(DESTDIR)$(BINDIR)/fedup

install-lang: $(MSGFILES)
	for lang in $(LANGUAGES); do \
	  langdir=$(DESTDIR)$(LOCALEDIR)/$${lang}/LC_MESSAGES; \
	  $(INSTALL) -d $$langdir; \
	  $(INSTALL) po/$${lang}.mo $${langdir}/$(TEXTDOMAIN).mo;\
	done

install-man: $(MANPAGE)
	$(INSTALL) -d $(DESTDIR)$(MANDIR)/man8
	$(INSTALL) -m644 $(MANPAGE) $(DESTDIR)$(MANDIR)/man8
	$(LN) -sf $(notdir $(MANPAGE)) $(DESTDIR)$(MANDIR)/man8/fedup.8

clean:
	rm -rf *.py[co] __pycache__ tests/*.py[co] tests/__pycache__ \
		$(PACKAGE)-*.tar.gz po/*.mo

check: po/zh_CN.mo
	$(PYTHON) -m unittest discover tests

archive: $(PACKAGE)-$(VERSION).tar.gz
$(PACKAGE)-$(VERSION).tar.gz: version-check
	git archive --prefix=$(PACKAGE)-$(VERSION)/ \
		    --output=$(PACKAGE)-$(VERSION).tar.gz \
		    $(VERSION)

version-check:
	git describe --tags $(VERSION)
	grep '^Version:\s*$(VERSION)' $(PACKAGE).spec
	grep '^\.TH .* "$(VERSION)"' $(MANPAGE)

.PHONY: build install clean check archive version-check
.PHONY: install-plugin install-service install-bin install-lang install-man
