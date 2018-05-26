#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)
error=$(tput bold)$(tput setb 1)$(tput setaf 7)

SCRIPT_DIRECTORY=$(cd `dirname $0` && pwd)
PATCH_DIRECTORY=$SCRIPT_DIRECTORY/patches
BUILD_DIR=$SCRIPT_DIRECTORY/build

print() {
	echo "${bold}[$(date +"%T")]${normal} $1"
}

error() {
	echo "${error}[$(date +"%T")] $1${normal}"
	exit
}


echo "                   _           _ _     _ "
echo "                  | |         (_) |   | |"
echo " __  ___ __  _   _| |__  _   _ _| | __| |"
echo " \\ \\/ / '_ \\| | | | '_ \\| | | | | |/ _\` |"
echo "  >  <| | | | |_| | |_) | |_| | | | (_| |"
echo " /_/\\_\\_| |_|\\__,_|_.__/ \\__,_|_|_|\\__,_|"

print "Setting up macOS OpenSource Build Environment"
print "Script by PureDarwin, version 1.0"
print "---"

print "Getting the latest versions"
{
	VERSION_REGEX="\d+(\.?\d+\.?\d+\.\d+)?"
	XNU_VERSION=$(curl -s https://opensource.apple.com/tarballs/xnu/ | egrep -o "xnu-$VERSION_REGEX" | sort -V | tail -n 1)
	LIBDISPATCH_VERSION=$(curl -s https://opensource.apple.com/tarballs/libdispatch/ | egrep -o "libdispatch-$VERSION_REGEX" | sort -V | tail -n 1)
	DTRACE_VERSION=$(curl -s https://opensource.apple.com/tarballs/dtrace/ | egrep -o "dtrace-$VERSION_REGEX" | sort -V | tail -n 1)
	AVAILABILITYVERSIONS_VERSION=$(curl -s https://opensource.apple.com/tarballs/AvailabilityVersions/ | egrep -o "AvailabilityVersions-$VERSION_REGEX" | sort -V | tail -n 1)
	LIBPLATFORM_VERISON=$(curl -s https://opensource.apple.com/tarballs/libplatform/ | egrep -o "libplatform-$VERSION_REGEX" | sort -V | tail -n 1)
	COREOSMAKEFILES_VERISON=$(curl -s https://opensource.apple.com/tarballs/CoreOSMakefiles/ | egrep -o "CoreOSMakefiles-$VERSION_REGEX" | sort -V | tail -n 1)
} || {
	error "Failed to get latest versions"
	exit 1
}


SDK_ROOT=`xcodebuild -version -sdk macosx Path`

# Wait for user input
function wait_enter {
	read -p "Press enter to continue"
}

print "Found versions:"
print "${normal}XNU version:${bold} $XNU_VERSION"
print "${normal}libdispatch version:${bold} $LIBDISPATCH_VERSION"
print "${normal}dtrace version:${bold} $DTRACE_VERSION"
print "${normal}AvailabilityVersions version:${bold} $AVAILABILITYVERSIONS_VERSION"
print "${normal}libplatform version:${bold} $LIBPLATFORM_VERISON"
print "${normal}CoreOSMakefiles version:${bold} $COREOSMAKEFILES_VERISON${normal}"

wait_enter

# Curl these files from Opensource.apple.com
print "Getting dependencies from Apple"
{
	cd $SCRIPT_DIRECTORY && \
	curl -O https://opensource.apple.com/tarballs/dtrace/$DTRACE_VERSION.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/AvailabilityVersions/$AVAILABILITYVERSIONS_VERSION.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/xnu/$XNU_VERSION.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/libplatform/$LIBPLATFORM_VERISON.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/libdispatch/$LIBDISPATCH_VERSION.tar.gz && \
	curl -O	https://opensource.apple.com/tarballs/CoreOSMakefiles/$COREOSMAKEFILES_VERISON.tar.gz
} || {
	error "Failed to get dependencies from Apple"
	exit 1
}
wait_enter

# Run this command to untar all downloaded files and rm the tar.gz files
print "Extracting dependencies"
{
	cd $SCRIPT_DIRECTORY && \
	for file in *.tar.gz; do
		rm -rf $(basename $file .tar.gz)
		tar -zxf $file
	done && \
	rm -f *.tar.gz
} || {
	error "Failed to extract dependencies"
	exit 1
}
wait_enter

if [ ! -f /Applications/Xcode.app/Contents/Developer/Makefiles/CoreOS/Xcode/BSD.xcconfig ]; then
print "Installing CoreOSMakefiles"
{
	cd $SCRIPT_DIRECTORY/$COREOSMAKEFILES_VERISON && \
		sudo ditto $PWD/Xcode /Applications/Xcode.app/Contents/Developer/Makefiles/CoreOS/Xcode
} || {
	error "Failed to install CoreOSMakefiles"
	exit 1
}
wait_enter
fi

mkdir -p $BUILD_DIR/dependencies
print "Building dtrace"
{
	mkdir -p $BUILD_DIR/$DTRACE_VERSION.{obj,sym,dst}
	cd $SCRIPT_DIRECTORY/$DTRACE_VERSION && \
		xcodebuild install -target ctfconvert -target ctfdump -target ctfmerge ARCHS="x86_64" SRCROOT=$PWD OBJROOT=$BUILD_DIR/$DTRACE_VERSION.obj SYMROOT=$BUILD_DIR/$DTRACE_VERSION.sym DSTROOT=$BUILD_DIR/$DTRACE_VERSION.dst && \
		ditto $BUILD_DIR/$DTRACE_VERSION.dst/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain $BUILD_DIR/dependencies
} || {
	error "Failed to build dtrace"
	exit 1
}
wait_enter

print "Building AvailabilityVersions"
{
	mkdir -p $BUILD_DIR/$AVAILABILITYVERSIONS_VERSION.dst
	cd $SCRIPT_DIRECTORY/$AVAILABILITYVERSIONS_VERSION && \
		make install SRCROOT=$PWD DSTROOT=$BUILD_DIR/$AVAILABILITYVERSIONS_VERSION.dst && \
		ditto $BUILD_DIR/$AVAILABILITYVERSIONS_VERSION.dst/usr/local $BUILD_DIR/dependencies/usr/local
} || {
	error "Failed to build AvailabiltyVersions"
	exit 1
}
wait_enter

# Install XNU headers
print "Installing XNU & LibSyscall headers"
{
	mkdir -p $BUILD_DIR/$XNU_VERSION.hdrs.{obj,sym,dst}
	cd $SCRIPT_DIRECTORY/$XNU_VERSION && \
		patch -s -p1 < $PATCH_DIRECTORY/availability_versions.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/fix_codesigning.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu_dependencies_dir.patch && \
		DEPENDENCIES_DIR=$BUILD_DIR/dependencies make installhdrs SDKROOT=macosx ARCH_CONFIGS=X86_64 SRCROOT=$PWD OBJROOT=$BUILD_DIR/$XNU_VERSION.hdrs.obj SYMROOT=$BUILD_DIR/$XNU_VERSION.hdrs.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.hdrs.dst && \
		patch -s -p1 < $PATCH_DIRECTORY/libsyscall.patch && \
		xcodebuild installhdrs -project libsyscall/Libsyscall.xcodeproj -sdk macosx ARCHS='x86_64 i386' SRCROOT=$PWD/libsyscall OBJROOT=$BUILD_DIR/$XNU_VERSION.hdrs.obj SYMROOT=$BUILD_DIR/$XNU_VERSION.hdrs.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.hdrs.dst DEPENDENCIES_DIR=$BUILD_DIR/dependencies && \
		ditto $BUILD_DIR/$XNU_VERSION.hdrs.dst $BUILD_DIR/dependencies
} || {
	error "Failed to build XNU & LibSyscall headers"
	exit 1
}
wait_enter

print "Setting up libplatform"
{
	cd $SCRIPT_DIRECTORY/$LIBPLATFORM_VERISON && \
		ditto $PWD/include $BUILD_DIR/dependencies/usr/local/include && \
		ditto $PWD/private $BUILD_DIR/dependencies/usr/local/include
} || {
	error "Failed to setup libplatform"
	exit 1
}
wait_enter

print "Setting up libfirehose"
{
	mkdir -p $BUILD_DIR/$LIBDISPATCH_VERSION.{obj,sym,dst}
	cd $SCRIPT_DIRECTORY/$LIBDISPATCH_VERSION && \
		xcodebuild install -project libdispatch.xcodeproj -target libfirehose_kernel -sdk macosx ARCHS='x86_64 i386' SRCROOT=$PWD OBJROOT=$BUILD_DIR/$LIBDISPATCH_VERSION.obj SYMROOT=$BUILD_DIR/$LIBDISPATCH_VERSION.sym DSTROOT=$BUILD_DIR/$LIBDISPATCH_VERSION.dst ADDITIONAL_SDKS=$BUILD_DIR/dependencies DEPENDENCIES_DIR=$BUILD_DIR/dependencies && \
		ditto $BUILD_DIR/$LIBDISPATCH_VERSION.dst/usr/local $BUILD_DIR/dependencies/usr/local
} || {
	error "Failed to setup libfirehose"
	exit 1
}
wait_enter

# Building XNU
print "Building XNU"
{
	mkdir -p $BUILD_DIR/$XNU_VERSION.{obj,sym,dst}
	cd $SCRIPT_DIRECTORY/$XNU_VERSION && \
		patch -s -p1 < $PATCH_DIRECTORY/kext_copyright_check.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu_firehose_dir.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/fix_system_framework.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xcode9_warnings.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/fix_build.patch && \
		sudo env DEPENDENCIES_DIR=$BUILD_DIR/dependencies make SDKROOT=macosx ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE OBJROOT=$BUILD_DIR/$XNU_VERSION.obj SYMROOT=$BUILD_DIR/$XNU_VERSION.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.dst DEPENDENCIES_DIR=$BUILD_DIR/dependencies BUILD_WERROR=0
} || {
	error "Failed to build XNU"
	exit 1
}

print "Complete"

open $BUILD_DIR/$XNU_VERSION.dst
