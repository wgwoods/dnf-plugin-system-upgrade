PACKAGE = dnf-plugin-system-upgrade
VERSION = 0.7.1

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
TEXTDOMAIN = dnf-plugin-system-upgrade
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
		dnf-plugin-system-upgrade-*.tar.gz po/*.mo \
		docker/rpmbuild/$(PACKAGE)-*

check: po/zh_CN.mo
	$(PYTHON) -m unittest discover tests

archive: $(PACKAGE)-$(VERSION).tar.gz
$(PACKAGE)-$(VERSION).tar.gz: version-check
	git archive --prefix=dnf-plugin-system-upgrade-$(VERSION)/ \
		    --output=dnf-plugin-system-upgrade-$(VERSION).tar.gz \
		    $(VERSION)

version-check:
	git describe --tags $(VERSION)
	grep '^Version:\s*$(VERSION)' dnf-plugin-system-upgrade.spec
	grep '^\.TH .* "$(VERSION)"' $(MANPAGE)

SNAPVER = $(shell git describe --long --tags --match="*.*.*" 2>/dev/null || \
          echo $(VERSION)-0-x0000000)
SNAPREL = snap$(subst -,.,$(patsubst $(VERSION)-%,%,$(SNAPVER)))

SNAPARCHIVE = $(PACKAGE)-$(SNAPVER).tar.gz
SNAPSPEC = $(PACKAGE)-$(SNAPVER).spec

%/$(SNAPARCHIVE):
	git archive --prefix=$(PACKAGE)-$(VERSION)/ --output=$@ HEAD

%/$(SNAPSPEC): $(PACKAGE).spec
	sed -e 's/^Release:.*$$/Release: $(SNAPREL)%{?dist}/' \
	    -e 's/^Source0:.*$$/Source0: $(SNAPARCHIVE)/' \
		$< > $@
	touch -r $< $@

# This feels like a dumb way of doing this but I don't know of a smart one
%/Dockerfile.f21: %/Dockerfile
	sed -e 's/^FROM fedora$/FROM fedora:21/' $< > $@
%/Dockerfile.f22: %/Dockerfile
	sed -e 's/^FROM fedora$/FROM fedora:22/' $< > $@
%/Dockerfile.f23: %/Dockerfile
	sed -e 's/^FROM fedora$/FROM fedora:23/' $< > $@

# TODO: we should copy docker stuff info a build/ dir and then build temporary
# artifacts etc. there so we can clean it all out easily afterward

DOCKER_GENFILES = docker/rpmbuild/$(SNAPARCHIVE) docker/rpmbuild/$(SNAPSPEC)

# I don't think the tagging here is smart but I'll improve it later
snapshot-docker-rpmbuild: $(DOCKER_GENFILES) docker/rpmbuild/Dockerfile
	docker build -t $(PACKAGE)-rpmbuild:$(SNAPVER) docker/rpmbuild
	docker run $(PACKAGE)-rpmbuild:$(SNAPVER) tar -C / -c rpms/ | \
		tar -C docker/testenv -vx
	docker build -t $(PACKAGE)-testenv docker/testenv
	@echo "Done! To enter test environment, try:"
	@echo "  docker run -ti $(PACKAGE)-testenv"

snapshot-docker-compose: snapshot-docker-rpmbuild docker-compose.yml
	docker-compose build

.PHONY: build install clean check archive version-check
.PHONY: install-plugin install-service install-bin install-lang install-man
