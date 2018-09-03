# This makefile is intended to be ran by darwinbuild
# as part of an automated/bulk build process. Most human
# users of the xnubuild repo should use xnubuild.sh instead.

PATCH_DIRECTORY = $(SRCROOT)/patches
XCODE_DEVELOPER_DIR = $(shell xcode-select -print-path)

.DEFAULT_GOAL : install

.PHONY : download_tarballs
download_tarballs :
	curl -sO https://opensource.apple.com/tarballs/AvailabilityVersions/AvailabilityVersions-32.30.1.tar.gz
	curl -sO https://opensource.apple.com/tarballs/CoreOSMakefiles/CoreOSMakefiles-77.tar.gz
	curl -sO https://opensource.apple.com/tarballs/dtrace/dtrace-262.tar.gz
	curl -sO https://opensource.apple.com/tarballs/libdispatch/libdispatch-913.30.4.tar.gz
	curl -sO https://opensource.apple.com/tarballs/libplatform/libplatform-161.20.1.tar.gz
	curl -sO https://opensource.apple.com/tarballs/xnu/xnu-4570.41.2.tar.gz
	tar -xzf AvailabilityVersions-32.30.1.tar.gz
	tar -xzf CoreOSMakefiles-77.tar.gz
	tar -xzf dtrace-262.tar.gz
	tar -xzf libdispatch-913.30.4.tar.gz
	tar -xzf libplatform-161.20.1.tar.gz
	tar -xzf xnu-4570.41.2.tar.gz

.PHONY : dtrace
dtrace : download_tarballs
	mkdir -p $(OBJROOT)/dtrace.{obj,sym,dst}
	cd $(SRCROOT)/dtrace-262 && \
		patch -s -p1 < $(PATCH_DIRECTORY)/dtrace/missing-xcconfig.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/dtrace/header-paths.patch && \
		xcodebuild install -target ctfconvert -target ctfdump -target ctfmerge \
			ARCHS=x86_64 SRCROOT=$(SRCROOT)/dtrace-262 OBJROOT=$(OBJROOT)/dtrace.obj \
			SYMROOT=$(OBJROOT)/dtrace.sym DSTROOT=$(OBJROOT)/dtrace.dst
	mkdir -p $(OBJROOT)/dependencies
	ditto $(OBJROOT)/dtrace.dst/$(XCODE_DEVELOPER_DIR)/Toolchains/XcodeDefault.xctoolchain \
		$(OBJROOT)/dependencies

.PHONY : AvailabilityVersions
AvailabilityVersions : download_tarballs
	mkdir -p $(OBJROOT)/AvailabilityVersions.dst
	cd $(SRCROOT)/AvailabilityVersions-32.30.1 && \
		make install SRCROOT=$(SRCROOT)/AvailabilityVersions-32.30.1 \
			DSTROOT=$(OBJROOT)/AvailabilityVersions.dst
	mkdir -p $(OBJROOT)/dependencies
	ditto $(OBJROOT)/AvailabilityVersions.dst/usr/local $(OBJROOT)/dependencies/usr/local

.PHONY : installhdrs
installhdrs :
	make HEADER_DSTROOT=$(DSTROOT) xnu_headers

HEADER_DSTROOT ?= $(OBJROOT)/dependencies
HEADER_SYMROOT ?= $(OBJROOT)/xnu.headers.sym
.PHONY : xnu_headers
xnu_headers : download_tarballs AvailabilityVersions dtrace
	mkdir -p $(OBJROOT)/xnu.headers.{obj,sym}
	mkdir -p $(HEADER_DSTROOT) $(HEADER_SYMROOT)
	cd $(SRCROOT)/xnu-4570.41.2 && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/availability_versions.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/fix_codesigning.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/xnu_dependencies_dir.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/libsyscall.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/remove-i386.patch
	make -C $(SRCROOT)/xnu-4570.41.2 installhdrs \
		RC_ProjectName=xnu \
		DEPENDENCIES_DIR=$(OBJROOT)/dependencies \
		SDKROOT=macosx ARCH_CONFIGS=X86_64 \
		SRCROOT=$(SRCROOT)/xnu-4570.41.2 \
		OBJROOT=$(OBJROOT)/xnu.headers.obj \
		SYMROOT=$(HEADER_SYMROOT) \
		DSTROOT=$(HEADER_DSTROOT)
	mkdir -p $(OBJROOT)/libsyscall.headers.sym
	xcodebuild installhdrs -project $(SRCROOT)/xnu-4570.41.2/libsyscall/Libsyscall.xcodeproj \
		-sdk macosx SRCROOT=$(SRCROOT)/xnu-4570.41.2/libsyscall \
		OBJROOT=$(OBJROOT)/libsyscall.headers.obj SYMROOT=$(OBJROOT)/libsyscall.headers.sym \
		DSTROOT=$(HEADER_DSTROOT) DEPENDENCIES_DIR=$(OBJROOT)/dependencies

.PHONY : libplatform
libplatform : download_tarballs
	ditto $(SRCROOT)/libplatform-161.20.1/include $(OBJROOT)/dependencies/usr/local/include
	ditto $(SRCROOT)/libplatform-161.20.1/private $(OBJROOT)/dependencies/usr/local/include

.PHONY : libfirehose
libfirehose : download_tarballs libplatform xnu_headers
	mkdir -p $(OBJROOT)/libfirehose.{dst,obj,sym}
	cd $(SRCROOT)/libdispatch-913.30.4 && \
		patch -s -p1 < $(PATCH_DIRECTORY)/libfirehose/header-paths.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/libfirehose/missing-xcconfig.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/libfirehose/no-werror.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/libfirehose/void-returns-void.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/libfirehose/include-standard-path.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/libfirehose/fix-xnu-linking.patch
	xcodebuild install -project $(SRCROOT)/libdispatch-913.30.4/libdispatch.xcodeproj \
		-target libfirehose_kernel -sdk macosx ARCHS=x86_64 SRCROOT=$(SRCROOT)/libdispatch-913.30.4 \
		OBJROOT=$(OBJROOT)/libfirehose.obj SYMROOT=$(OBJROOT)/libfirehose.sym \
		DSTROOT=$(OBJROOT)/libfirehose.dst DEPENDENCIES_DIR=$(OBJROOT)/dependencies
	ditto $(OBJROOT)/libfirehose.dst/usr/local $(OBJROOT)/dependencies/usr/local

.PHONY : xnu
xnu : download_tarballs libfirehose AvailabilityVersions dtrace
	mkdir -p $(OBJROOT)/xnu.obj $(SYMROOT) $(DSTROOT)
	cd $(SRCROOT)/xnu-4570.41.2 && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/kext_copyright_check.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/xnu_firehose_dir.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/fix_system_framework.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/xcode9_warnings.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/missing_header.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/invalid_assembly.patch && \
		patch -s -p1 < $(PATCH_DIRECTORY)/xnu/add_missing_symbol.patch
	DEPENDENCIES_DIR=$(OBJROOT)/dependencies make install -C $(SRCROOT)/xnu-4570.41.2 \
		RC_ProjectName=xnu SDKROOT=macosx ARCH_CONFIGS=x86_64 \
		KERNEL_CONFIGS=RELEASE SRCROOT=$(SRCROOT)/xnu-4570.41.2 \
		OBJROOT=$(OBJROOT)/xnu.obj SYMROOT=$(SYMROOT) \
		DSTROOT=$(DSTROOT) BUILD_WERROR=0 BUILD_LTO=0

.PHONY : libsyscall
libsyscall : download_tarballs xnu_headers
	cd $(SRCROOT)/xnu-4570.41.2 && \
		patch -sf -p1 < $(PATCH_DIRECTORY)/xnu/libsyscall-build.patch
	DEPENDENCIES_DIR=$(OBJROOT)/dependencies \
		make install -C $(SRCROOT)/xnu-4570.41.2 RC_ProjectName=Libsyscall \
		SDKROOT=macosx SRCROOT=$(SRCROOT)/xnu-4570.41.2 \
		OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT)

.PHONY : install
ifeq ($(RC_ProjectName),libsyscall)
install : libsyscall
else
install : xnu
endif
