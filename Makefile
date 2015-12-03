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
		docker/rpmbuild/build-* docker/testenv/test-*

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

# TODO everything below here could go into a separate file...

SOURCE_RELEASEVER ?= 22
TARGET_RELEASEVER ?= 23

SNAPVER = $(shell git describe --long --tags --match="*.*.*" 2>/dev/null || \
          echo $(VERSION)-0-x0000000)
SNAPREL = snap$(subst -,.,$(patsubst $(VERSION)-%,%,$(SNAPVER)))

SNAP_RPM_EVR = $(VERSION)-$(SNAPREL).fc$(SOURCE_RELEASEVER)

TESTENV_DOCKERFILE = docker/testenv/Dockerfile.f$(SOURCE_RELEASEVER)
RPMBUILD_DOCKERFILE = docker/rpmbuild/Dockerfile.f$(SOURCE_RELEASEVER) \

RPMBUILD_IMAGE = $(PACKAGE)/rpmbuild:$(SOURCE_RELEASEVER)
TESTENV_IMAGE = $(PACKAGE)/testenv:$(SOURCE_RELEASEVER)
RPMBUILD_CONTAINER = rpmbuild-$(SNAP_RPM_EVR)

SNAP_BUILDDIR = docker/rpmbuild/build-$(SNAP_RPM_EVR)
SNAP_TESTDIR = docker/testenv/test-$(SNAP_RPM_EVR)

SNAPARCHIVE = $(PACKAGE)-$(SNAPVER).tar.gz
SNAPSPEC = $(PACKAGE)-$(SNAPVER).spec

SNAP_RPM_NAME = $(PACKAGE)-$(SNAP_RPM_EVR)
SNAP_RPM_GENFILES = $(SNAP_BUILDDIR) \
                    $(SNAP_BUILDDIR)/$(SNAPARCHIVE) \
                    $(SNAP_BUILDDIR)/$(SNAPSPEC)

$(SNAP_BUILDDIR) $(SNAP_TESTDIR):
	mkdir -p $@

$(SNAP_BUILDDIR)/$(SNAPARCHIVE):
	git archive --prefix=$(PACKAGE)-$(VERSION)/ --output=$@ HEAD

$(SNAP_BUILDDIR)/$(SNAPSPEC): $(PACKAGE).spec
	sed -e 's/^Release:.*$$/Release: $(SNAPREL)%{?dist}/' \
	    -e 's/^Source0:.*$$/Source0: $(SNAPARCHIVE)/' \
		$< > $@

docker/rpmbuild/Dockerfile.f%: docker/rpmbuild/Dockerfile
	sed -e 's/^FROM fedora.*/FROM fedora:$*/' $< > $@ || { rm -f $@; false; }

docker/testenv/Dockerfile.f%: docker/testenv/Dockerfile
	sed -e 's/^FROM fedora.*/FROM fedora:$*/' $< > $@ || { rm -f $@; false; }

docker-rpmbuild-image: $(RPMBUILD_DOCKERFILE)
	docker build -f $(RPMBUILD_DOCKERFILE) -t $(RPMBUILD_IMAGE) docker/rpmbuild

docker-testenv-image: $(TESTENV_DOCKERFILE)
	docker build -f $(TESTENV_DOCKERFILE) -t $(TESTENV_IMAGE) docker/testenv

docker-snapshot-rpmbuild: docker-rpmbuild-image $(SNAP_RPM_GENFILES)
	docker ps -a | grep -qw $(RPMBUILD_CONTAINER) || \
	docker run --name $(RPMBUILD_CONTAINER) \
		--volume $$(pwd)/$(SNAP_BUILDDIR):/src:ro,z \
		$(RPMBUILD_IMAGE) || { docker rm $(RPMBUILD_CONTAINER); false; }

docker-snapshot-runtest: docker-snapshot-rpmbuild docker-testenv-image $(SNAP_TESTDIR)
	docker run --rm --tty \
		--volumes-from $(RPMBUILD_CONTAINER) \
		--volume $$(pwd)/docker/testenv:/testenv:ro,z \
		--volume $$(pwd)/$(SNAP_TESTDIR):/results:z \
		--env RPM_NAME=$(SNAP_RPM_NAME) \
		--env TARGET_RELEASEVER=$(TARGET_RELEASEVER) \
		--env INSTALL_ARGS=$(INSTALL_ARGS) \
		$(TESTENV_IMAGE) \
		/testenv/runtest.sh

.PHONY: build install clean check archive version-check
.PHONY: install-plugin install-service install-bin install-lang install-man
