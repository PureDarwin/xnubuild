# xnubuild

A script by the PureDarwin project for setting up a macOS development environment and building XNU.

## Running

	./xnubuild.sh

At various steps the script will ask you to click enter to continue. If theres noticable problems along the way you can ctr-c at these points to halt the building process. If this occurs please raise an issue in the issue tracker with any relevant information.

## Options

In the script you can change the location it builds to by changing the `BUILD_DIR` variable.

## Notes

As of right now, the patching only works on Darwin 17.0. This will be updated in the future to support more versions