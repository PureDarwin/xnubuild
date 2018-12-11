# This makefile is intended to be ran by darwinbuild
# as part of an automated/bulk build process. Most human
# users of the xnubuild repo should use xnubuild.sh instead.

# NOTE: Please keep this in sync with the corresponding variable in xnubuild.sh
XNU_VERSION = xnu-4903.221.2

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
	@BUILD_DIR=$(OBJROOT) $(SRCROOT)/xnubuild.sh -travis
	@ditto $(OBJROOT)/$(XNU_VERSION).dst $(DSTROOT)
	@ditto $(OBJROOT)/$(XNU_VERSION).sym $(SYMROOT)
