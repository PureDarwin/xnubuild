#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)
error=$(tput bold)$(tput setb 1)$(tput setaf 7)

print() {
	echo "${bold}[$(date +"%T")]${normal} $1"
}

error() {
	echo "${error}[$(date +"%T")] $1"
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

print "Getting the latest versions and Libsyscall Patch"
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
BUILD_DIR=~/Desktop/xnubuild 

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

print "Going to temporary build directory ($BUILD_DIR)"
{
	mkdir -p $BUILD_DIR
	cd $BUILD_DIR
} || {
	error "Failed to make build directory"
	exit 1
}
wait_enter

# Curl these files from Opensource.apple.com
print "Getting dependencies from Apple and PD-Devs"
{
	curl -O https://opensource.apple.com/tarballs/dtrace/$DTRACE_VERSION.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/AvailabilityVersions/$AVAILABILITYVERSIONS_VERSION.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/xnu/$XNU_VERSION.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/libplatform/$LIBPLATFORM_VERISON.tar.gz && \
	curl -O https://opensource.apple.com/tarballs/libdispatch/$LIBDISPATCH_VERSION.tar.gz && \
	curl -O	https://opensource.apple.com/tarballs/CoreOSMakefiles/$COREOSMAKEFILES_VERISON.tar.gz && \
	curl -O https://pd-devs.org/patches/libsyscall.patch
} || {
	error "Failed to get dependencies from Apple and PD-Devs"
	exit 1
}
wait_enter

# Run this command to untar all downloaded files and rm the tar.gz files
print "Extracting dependencies"
{
	for file in *.tar.gz; do tar -zxf $file; done && rm -f *.tar.gz
} || {	
	error "Failed to extract dependencies"
	exit 1
}
wait_enter

print "Installing CoreOSMakefiles"
{
	cd $COREOSMAKEFILES_VERISON && \
		sudo ditto $PWD/Xcode /Applications/Xcode.app/Contents/Developer/Makefiles/CoreOS/Xcode && \
	cd ..
} || {
	error "Failed to install CoreOSMakefiles"
	exit 1
}
wait_enter
 
print "Building dtrace"
{
	cd $DTRACE_VERSION && \
		mkdir -p obj sym dst && \
		xcodebuild install -target ctfconvert -target ctfdump -target ctfmerge ARCHS="x86_64" SRCROOT=$PWD OBJROOT=$PWD/obj SYMROOT=$PWD/sym DSTROOT=$PWD/dst && \
		sudo ditto $PWD/dst/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain && \
	cd ..
} || {
	error "Failed to build dtrace"
	exit 1
}
wait_enter

print "Building AvailabilityVersions"
{
	cd $AVAILABILITYVERSIONS_VERSION && \
		mkdir -p dst && \
		make install SRCROOT=$PWD DSTROOT=$PWD/dst && \
		sudo ditto $PWD/dst/usr/local `xcrun -sdk macosx -show-sdk-path`/usr/local && \
	cd ..
} || {
	error "Failed to build AvailabiltyVersions"
	exit 1
}
wait_enter

# Install XNU headers
print "Installing XNU & LibSyscall headers"
{
	cd $XNU_VERSION/ && \
		mkdir -p BUILD.hdrs/obj BUILD.hdrs/sym BUILD.hdrs/dst && \
		make installhdrs SDKROOT=macosx ARCH_CONFIGS=X86_64 SRCROOT=$PWD OBJROOT=$PWD/BUILD.hdrs/obj SYMROOT=$PWD/BUILD.hdrs/sym DSTROOT=$PWD/BUILD.hdrs/dst && \
		patch -s -p1 < $PWD/../libsyscall.patch && \
		sudo xcodebuild installhdrs -project libsyscall/Libsyscall.xcodeproj -sdk macosx ARCHS='x86_64 i386' SRCROOT=$PWD/libsyscall OBJROOT=$PWD/BUILD.hdrs/obj SYMROOT=$PWD/BUILD.hdrs/sym DSTROOT=$PWD/BUILD.hdrs/dst && \
		sudo ditto BUILD.hdrs/dst `xcrun -sdk macosx -show-sdk-path` && \
	cd ..
} || {
	error "Failed to build XNU & LibSyscall headers"
	exit 1
}
wait_enter

print "Setting up libplatform"
{
	cd $LIBPLATFORM_VERISON && \
		sudo ditto $PWD/include `xcrun -sdk macosx -show-sdk-path`/usr/local/include && \
		sudo ditto $PWD/private `xcrun -sdk macosx -show-sdk-path`/usr/local/include && \
	cd ..
} || {
	error "Failed to setup libplatform"
	exit 1
}
wait_enter

print "Setting up libfirehose"
{
	cd $LIBDISPATCH_VERSION && \
		mkdir -p BUILD.hdrs/obj BUILD.hdrs/sym BUILD.hdrs/dst && \
		sudo xcodebuild install -project libdispatch.xcodeproj -target libfirehose_kernel -sdk macosx ARCHS='x86_64 i386' SRCROOT=$PWD OBJROOT=$PWD/obj SYMROOT=$PWD/sym DSTROOT=$PWD/dst && \
		sudo ditto $PWD/dst/usr/local `xcrun -sdk macosx -show-sdk-path`/usr/local && \
	cd ..
} || {
	error "Failed to setup libfirehose"
	exit 1
}
wait_enter

# Building XNU
print "Building XNU"
{
	cd $XNU_VERSION && \
		sudo make SDKROOT=macosx ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE && \
	cd ..
} || {
	error "Failed to build XNU"
	exit 1
}

print "Complete"

cd $BUILD_DIR/$XNU_VERSION/BUILD/obj/RELEASE_X86_64
open .