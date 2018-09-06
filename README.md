# xnubuild [![Build Status](https://travis-ci.org/PureDarwin/xnubuild.svg?branch=master)](https://travis-ci.org/PureDarwin/xnubuild)

A script by the PureDarwin project for setting up a macOS development environment and building XNU, as well as the Libsyscall component that is bundled with XNU.

## Running

	./xnubuild.sh

At various steps the script will ask you to press Enter to continue. If theres noticable problems along the way you can press Ctrl+C at these points to halt the building process. If this occurs please raise an issue in the issue tracker with any relevant information.

## Options

The script has no build options. It always builds into the `build/` directory alongiide the script (that is, in the root of this repository).

However, there is a special option (`travis`) which allows the script to be run without user-interaction (user may probably only have to type his password) and thus allowing TravisCI to complete a build.  You can leverage this functionality if you want the script to go-on by itself.

## Notes

As of right now, the patching works on macOS 10.13.6 and macOS Mojave beta, using Xcode 9.4 and Xcode 10 beta. This will be updated in the future to support more versions.
