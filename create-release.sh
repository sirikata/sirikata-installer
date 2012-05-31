#!/bin/bash
#
# create-release.sh x.y.z
#
# Grab the raw binaries and make the necessary modifications to create
# installers for each platform. Essentially, this downloads and
# extracts the main install contents and sets up the version
# number. After executing this, you need to run BitRock InstallBuilder
# and generate each of the installers, unless it can be found in your
# PATH, in which case it will be run automatically to build the
# packages.

VERSION=$1

# Clean out any old data
rm -rf sirikata_win32
rm -rf sirikata_mac
rm -rf sirikata-${VERSION}-mac-installer.app
rm -f sirikata-${VERSION}-mac-installer.dmg
rm -f sirikata-${VERSION}-win32-installer.exe

# Grab and extract data
([ -e sirikata-$VERSION-win32.zip ] || wget http://sirikata.com/releases/win32/sirikata-$VERSION-win32.zip) && \
    unzip sirikata-$VERSION-win32.zip

([ -e sirikata-$VERSION-mac.tar.gz ] || wget http://sirikata.com/releases/mac/sirikata-$VERSION-mac.tar.gz) && \
    tar -xzvf sirikata-$VERSION-mac.tar.gz

# Make sure we have a copy of sirikata at the right version. We get
# the README and LICENSE from here currently.
([ -e sirikata.git ] || git clone git://github.com/sirikata/sirikata.git sirikata.git) && \
    cd sirikata.git && \
    git checkout v${VERSION} && \
    cd ..

# Generate a version-specific project file. When we can find the
# InstallBuilder binary, we could actually just use --setvars, but to
# support not having it in your PATH, we just generate a copy with the
# version set. Using a copy avoids accidentally checking in changes to
# this file.
sed "s/<version><\/version>/<version>${VERSION}<\/version>/" sirikata.xml > sirikata-$VERSION.xml


# Try to run InstallBuilder if we can find it
INSTALLBUILDER=`which builder`
if [ "x${INSTALLBUILDER}" == "x" ]; then
    echo "Couldn't find InstallBuilder. You need to open sirikata-${VERSION}.xml manually and build the packages."
else
    echo "Building packages for Windows and Mac..."
    ${INSTALLBUILDER} build sirikata-$VERSION.xml windows
    ${INSTALLBUILDER} build sirikata-$VERSION.xml osx
    echo "Copying to current directory..."
    cp -r `dirname ${INSTALLBUILDER}`/../output/sirikata-${VERSION}-osx-installer.app sirikata-${VERSION}-mac-installer.app
    genisoimage -D -V "sirikata-${VERSION}" -no-pad -r -apple -root sirikata-${VERSION}-mac-installer.app -o sirikata-${VERSION}-mac-installer.dmg sirikata-${VERSION}-mac-installer.app
    cp -r `dirname ${INSTALLBUILDER}`/../output/sirikata-${VERSION}-windows-installer.exe sirikata-${VERSION}-win32-installer.exe
    echo "Done"

    rm sirikata-${VERSION}.xml
fi