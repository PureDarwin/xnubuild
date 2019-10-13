# This makefile is intended to be ran by darwinbuild
# as part of an automated/bulk build process. Most human
# users of the xnubuild repo should use xnubuild.sh instead.

# NOTE: Please keep this in sync with the corresponding variable in xnubuild.sh
XNU_VERSION = xnu-4903.241.1

.DEFAULT_GOAL : install
.PHONY : install
install :
	@if [ "$(SRCROOT)" == "" -o "$(DSTROOT)" = "" -o "$(SYMROOT)" = "" -o "$(OBJROOT)" = "" ]; then \
		echo "*** Please run xnubuild.sh directly if building interactively."; \
		echo "*** The Makefile is intended only for automated builds using darwinbuild."; \
		exit 1; \
	fi
	@if [ ! -S /var/run/mDNSResponder ]; then \
		echo "*** xnubuild cannot run inside of a chroot. Pass '-nochroot' flag to darwinbuild."; \
		exit 1; \
	fi
	@BUILD_DIR=$(OBJROOT) $(SRCROOT)/xnubuild.sh -travis -separate_libsyscall
ifeq ($(RC_ProjectName),xnubuild)
	@ditto $(OBJROOT)/$(XNU_VERSION).dst $(DSTROOT)
	@ditto $(OBJROOT)/$(XNU_VERSION).sym $(SYMROOT)

	@mkdir -p $(OBJROOT)/libkmod.obj $(OBJROOT)/libkmod.sym
	cd $(SRCROOT)/$(XNU_VERSION) && patch -p1 -i $(SRCROOT)/patches/xnu/libkmod.patch
	make -C $(SRCROOT)/$(XNU_VERSION) RC_ProjectName=libkmod \
		SRCROOT=$(SRCROOT)/$(XNU_VERSION) \
		OBJROOT=$(OBJROOT)/libkmod.obj \
		SYMROOT=$(OBJROOT)/libkmod.sym \
		DSTROOT=$(DSTROOT)
	ditto $(OBJROOT)/libkmod.sym $(SYMROOT)/libkmod
endif
ifeq ($(RC_ProjectName),Libsyscall)
	@ditto $(OBJROOT)/Libsyscall.dst $(DSTROOT)
	@ditto $(OBJROOT)/Libsyscall.sym $(SYMROOT)
endif

.PHONY : installhdrs
installhdrs :
	@if [ "$(SRCROOT)" == "" -o "$(DSTROOT)" = "" -o "$(SYMROOT)" = "" -o "$(OBJROOT)" = "" ]; then \
		echo "*** Please run xnubuild.sh directly if building interactively."; \
		echo "*** The Makefile is intended only for automated builds using darwinbuild."; \
		exit 1; \
	fi
	@if [ ! -S /var/run/mDNSResponder ]; then \
		echo "*** xnubuild cannot run inside of a chroot. Pass '-nochroot' flag to darwinbuild."; \
		exit 1; \
	fi
	@BUILD_DIR=$(OBJROOT) $(SRCROOT)/xnubuild.sh -travis -header_only
	@ditto $(OBJROOT)/$(XNU_VERSION).hdrs.dst $(DSTROOT)
