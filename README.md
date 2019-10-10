# xnubuild

A script by the PureDarwin project for setting up a macOS development environment and building XNU, as well as the Libsyscall component that is bundled with XNU. This script currently works with Xcode 11.1 on macOS Catalina.

## Running

	./xnubuild.sh

After each build step completesthe script will ask you to press Enter to continue. If you encounter problems, you can press Ctrl+C at these points to halt the build process. If you find you need to do this, please raise an issue in the issue tracker with any relevant information.

Please do not attempt to use the Makefile in this repository to build XNU; it is present only for integration with the [darwinbuild](https://github.com/PureDarwin/darwinbuild) program and is not meant for general use. It only calls through into `xnubuild.sh` anyways.

## Options

The script has several build options. By default, it builds into the `build/` directory alongiide the script (that is, in the root of this repository). You can override this by setting the `BUILD_DIR` environment variable before running the script.

You can also use one or more of the following options:

* `-travis`: Don't prompt the user to press Enter to continue the build, and don't open the build products folder in the Finder at the end. The user may still need to enter their password for `sudo`.
* `-preclean`: Delete the `build/` directory, as well as all source directories and the tarballs they were expanded from before building. All files will be re-downloaded.
* `-header_only`: Stop after building the XNU headers. Not generally useful.
* `-separate_libsyscall`: Install Libsyscall into a different directory than the kernel itself. Works well together with `-compress_roots`.
* `-compress_roots`: Compress the folders output by the XNU (and Libsyscall, if `-separate_libsyscall` is passed) into tarballs. The tarballs will be placed in the `build/roots` directories.
