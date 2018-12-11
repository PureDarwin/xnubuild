#!/bin/bash

isRunningInTravis=false
preclean=false

while [ $# -ne 0 ]; do
	if [ "$1" == "-travis" ]; then
		isRunningInTravis=travis
	elif [ "$1" == "-preclean" ]; then
		preclean=true
	fi

	shift
done

if [ -t 1 ]; then
	bold=$(tput bold)
	normal=$(tput sgr0)
	error=$(tput bold)$(tput setb 1)$(tput setaf 7)
else
	bold=""
	normal=""
	error=""
fi

SCRIPT_DIRECTORY=$(cd `dirname $0` && pwd)
PATCH_DIRECTORY=$SCRIPT_DIRECTORY/patches

if [ "$BUILD_DIR" = "" ]; then
	BUILD_DIR=$SCRIPT_DIRECTORY/build
fi

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

XNU_VERSION=xnu-4903.221.2
LIBDISPATCH_VERSION=libdispatch-1008.220.2
DTRACE_VERSION=dtrace-284.200.15
AVAILABILITYVERSIONS_VERSION=AvailabilityVersions-33.200.4
LIBPLATFORM_VERSION=libplatform-177.200.16

SDK_ROOT=`xcodebuild -version -sdk macosx Path`

# Wait for user input
function wait_enter {
	if [ "$isRunningInTravis" != "travis" ] ; then
		read -p "Press enter to continue"
	fi
}

print "Using versions:"
print "${normal}XNU version:${bold} $XNU_VERSION"
print "${normal}libdispatch version:${bold} $LIBDISPATCH_VERSION"
print "${normal}dtrace version:${bold} $DTRACE_VERSION"
print "${normal}AvailabilityVersions version:${bold} $AVAILABILITYVERSIONS_VERSION"
print "${normal}libplatform version:${bold} $LIBPLATFORM_VERSION${normal}"

wait_enter

if [ "$preclean" = "true" ]; then
	print "Removing old tarballs and work directories"
	{
		cd $SCRIPT_DIRECTORY && \
			rm -rf $XNU_VERSION $XNU_VERSION.tar.gz && \
			rm -rf $LIBDISPATCH_VERSION $LIBDISPATCH_VERSION.tar.gz && \
			rm -rf $DTRACE_VERSION $DTRACE_VERSION.tar.gz && \
			rm -rf $AVAILABILITYVERSIONS_VERSION $AVAILABILITYVERSIONS_VERSION.tar.gz && \
			rm -rf $LIBPLATFORM_VERSION $LIBPLATFORM_VERSION.tar.gz && \
			rm -rf build
	} || {
		error "Could not remove old build artifacts"
	}
fi

print "Getting dependencies from Apple (if required)"
{
	curl_dependency () {
		if [ ! -f $1.tar.gz ]; then
			PROJECT_NAME=$(echo $1 | sed -Ee 's,-.*$,,g')
			curl -O https://opensource.apple.com/tarballs/$PROJECT_NAME/$1.tar.gz
		fi
	}

	cd $SCRIPT_DIRECTORY && \
	curl_dependency $DTRACE_VERSION && \
	curl_dependency $AVAILABILITYVERSIONS_VERSION && \
	curl_dependency $XNU_VERSION && \
	curl_dependency $LIBPLATFORM_VERSION && \
	curl_dependency $LIBDISPATCH_VERSION
} || {
	error "Failed to get dependencies from Apple"
	exit 1
}
wait_enter

print "Extracting dependencies"
{
	cd $SCRIPT_DIRECTORY && \
	for file in *.tar.gz; do
		rm -rf $(basename $file .tar.gz)
		tar -zxf $file
	done
} || {
	error "Failed to extract dependencies"
	exit 1
}
wait_enter

XCODE_DEVELOPER_DIR=$(xcode-select -print-path)

mkdir -p $BUILD_DIR/dependencies
print "Building dtrace"
{
	mkdir -p $BUILD_DIR/$DTRACE_VERSION.{obj,sym,dst}
	cd $SCRIPT_DIRECTORY/$DTRACE_VERSION && \
		patch -p1 < $PATCH_DIRECTORY/dtrace/header-paths.patch && \
		xcodebuild install -target ctfconvert -target ctfdump -target ctfmerge ARCHS="x86_64" SRCROOT=$PWD OBJROOT=$BUILD_DIR/$DTRACE_VERSION.obj SYMROOT=$BUILD_DIR/$DTRACE_VERSION.sym DSTROOT=$BUILD_DIR/$DTRACE_VERSION.dst && \
		ditto $BUILD_DIR/$DTRACE_VERSION.dst/$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain $BUILD_DIR/dependencies
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
		patch -s -p1 < $PATCH_DIRECTORY/xnu/availability_versions.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu/fix_codesigning.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu/xnu_dependencies_dir.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu/bsd-xcconfig.patch && \
		DEPENDENCIES_DIR=$BUILD_DIR/dependencies make installhdrs SDKROOT=macosx ARCH_CONFIGS=X86_64 SRCROOT=$PWD OBJROOT=$BUILD_DIR/$XNU_VERSION.hdrs.obj SYMROOT=$BUILD_DIR/$XNU_VERSION.hdrs.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.hdrs.dst && \
		xcodebuild installhdrs -project libsyscall/Libsyscall.xcodeproj -sdk macosx SRCROOT=$PWD/libsyscall OBJROOT=$BUILD_DIR/$XNU_VERSION.hdrs.obj SYMROOT=$BUILD_DIR/$XNU_VERSION.hdrs.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.hdrs.dst DEPENDENCIES_DIR=$BUILD_DIR/dependencies && \
		ditto $BUILD_DIR/$XNU_VERSION.hdrs.dst $BUILD_DIR/dependencies
} || {
	error "Failed to build XNU & LibSyscall headers"
	exit 1
}
wait_enter

print "Setting up libplatform"
{
	cd $SCRIPT_DIRECTORY/$LIBPLATFORM_VERSION && \
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
		patch -s -p1 < $PATCH_DIRECTORY/libfirehose/header-paths.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/libfirehose/fix-build.patch && \
		xcodebuild install -project libdispatch.xcodeproj -target libfirehose_kernel -sdk macosx ARCHS='x86_64' SRCROOT=$PWD OBJROOT=$BUILD_DIR/$LIBDISPATCH_VERSION.obj SYMROOT=$BUILD_DIR/$LIBDISPATCH_VERSION.sym DSTROOT=$BUILD_DIR/$LIBDISPATCH_VERSION.dst DEPENDENCIES_DIR=$BUILD_DIR/dependencies && \
		ditto $BUILD_DIR/$LIBDISPATCH_VERSION.dst/usr/local $BUILD_DIR/dependencies/usr/local
} || {
	error "Failed to setup libfirehose"
	exit 1
}
wait_enter

print "Building XNU, sudo password may be required"
{
	mkdir -p $BUILD_DIR/$XNU_VERSION.{obj,sym,dst}
	cd $SCRIPT_DIRECTORY/$XNU_VERSION && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu/kext_copyright_check.patch && \
		patch -s -p1 < $PATCH_DIRECTORY/xnu/xnu_firehose_dir.patch && \
		sudo env DEPENDENCIES_DIR=$BUILD_DIR/dependencies make install SDKROOT=macosx ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE OBJROOT=$BUILD_DIR/$XNU_VERSION.obj SYMROOT=$BUILD_DIR/$XNU_VERSION.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.dst DEPENDENCIES_DIR=$BUILD_DIR/dependencies BUILD_WERROR=0 BUILD_LTO=0
} || {
	error "Failed to build XNU"
	exit 1
}

print "Building Libsyscall, sudo password may be required"
{
	# This phase of the build installs into the same directory as xnu proper, for ease of use with pd_update.
	mkdir -p $BUILD_DIR/Libsyscall.{obj,sym}
	cd $SCRIPT_DIRECTORY/$XNU_VERSION && \
		sudo env DEPENDENCIES_DIR=$BUILD_DIR/dependencies RC_ProjectName=Libsyscall make install SDKROOT=macosx OBJROOT=$BUILD_DIR/Libsyscall.obj SYMROOT=$BUILD_DIR/Libsyscall.sym DSTROOT=$BUILD_DIR/$XNU_VERSION.dst
} || {
	error "Failed to build Libsyscall"
	exit 1
}

print "Complete"

if [ "$isRunningInTravis" != "travis" ]; then
	open $BUILD_DIR/$XNU_VERSION.dst
fi
