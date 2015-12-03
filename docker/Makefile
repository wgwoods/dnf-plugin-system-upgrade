include ../const.mk

SOURCE_RELEASEVER ?= 22
TARGET_RELEASEVER ?= 23

SNAPVER = $(shell git describe --long --tags --match="*.*.*" 2>/dev/null || \
          echo $(VERSION)-0-x0000000)
SNAPREL = snap$(subst -,.,$(patsubst $(VERSION)-%,%,$(SNAPVER)))

SNAP_RPM_EVR = $(VERSION)-$(SNAPREL).fc$(SOURCE_RELEASEVER)

TESTENV_DOCKERFILE = testenv/Dockerfile.f$(SOURCE_RELEASEVER)
RPMBUILD_DOCKERFILE = rpmbuild/Dockerfile.f$(SOURCE_RELEASEVER)

RPMBUILD_IMAGE = $(PACKAGE)/rpmbuild:$(SOURCE_RELEASEVER)
TESTENV_IMAGE = $(PACKAGE)/testenv:$(SOURCE_RELEASEVER)
RPMBUILD_CONTAINER = rpmbuild-$(SNAP_RPM_EVR)

SNAP_BUILDDIR = rpmbuild/build-$(SNAP_RPM_EVR)
SNAP_TESTDIR = testenv/test-$(SNAP_RPM_EVR)

SNAPARCHIVE = $(PACKAGE)-$(SNAPVER).tar.gz
SNAPSPEC = $(PACKAGE)-$(SNAPVER).spec

SNAP_RPM_NAME = $(PACKAGE)-$(SNAP_RPM_EVR)
SNAP_RPM_GENFILES = $(SNAP_BUILDDIR) \
                    $(SNAP_BUILDDIR)/$(SNAPARCHIVE) \
                    $(SNAP_BUILDDIR)/$(SNAPSPEC)

clean:
	rm -rf $(SNAP_BUILDDIR) $(SNAP_TESTDIR)

docker-clean:
	docker rm $(RPMBUILD_CONTAINER)
	docker rmi $(RPMBUILD_IMAGE) $(TESTENV_IMAGE)

$(SNAP_BUILDDIR) $(SNAP_TESTDIR):
	mkdir -p $@

$(SNAP_BUILDDIR)/$(SNAPARCHIVE):
	( cd ..; git archive --prefix=$(PACKAGE)-$(VERSION)/ HEAD ) \
	> $@ || { rm -f $@; false; }

$(SNAP_BUILDDIR)/$(SNAPSPEC): ../$(PACKAGE).spec
	sed -e 's/^Release:.*$$/Release: $(SNAPREL)%{?dist}/' \
	    -e 's/^Source0:.*$$/Source0: $(SNAPARCHIVE)/' \
		$< > $@

rpmbuild/Dockerfile.f%: rpmbuild/Dockerfile
	sed -e 's/^FROM fedora.*/FROM fedora:$*/' $< > $@ || { rm -f $@; false; }

testenv/Dockerfile.f%: testenv/Dockerfile
	sed -e 's/^FROM fedora.*/FROM fedora:$*/' $< > $@ || { rm -f $@; false; }

docker-rpmbuild-image: $(RPMBUILD_DOCKERFILE)
	docker build -f $(RPMBUILD_DOCKERFILE) -t $(RPMBUILD_IMAGE) rpmbuild

docker-testenv-image: $(TESTENV_DOCKERFILE)
	docker build -f $(TESTENV_DOCKERFILE) -t $(TESTENV_IMAGE) testenv

docker-snapshot-rpmbuild: docker-rpmbuild-image $(SNAP_RPM_GENFILES)
	docker ps -a | grep -qw $(RPMBUILD_CONTAINER) || \
	docker run --name $(RPMBUILD_CONTAINER) \
		--volume $$(pwd)/$(SNAP_BUILDDIR):/src:ro,z \
		$(RPMBUILD_IMAGE) || { docker rm $(RPMBUILD_CONTAINER); false; }

docker-snapshot-runtest: docker-snapshot-rpmbuild docker-testenv-image $(SNAP_TESTDIR)
	docker run --rm --tty \
		--volumes-from $(RPMBUILD_CONTAINER) \
		--volume $$(pwd)/testenv:/testenv:ro,z \
		--volume $$(pwd)/$(SNAP_TESTDIR):/results:z \
		--env RPM_NAME=$(SNAP_RPM_NAME) \
		--env TARGET_RELEASEVER=$(TARGET_RELEASEVER) \
		--env INSTALL_ARGS=$(INSTALL_ARGS) \
		$(TESTENV_IMAGE) \
		/testenv/runtest.sh

.PHONY: docker-rpmbuild-image docker-testenv-image
.PHONY: docker-snapshot-rpmbuild docker-snapshot-runtest
