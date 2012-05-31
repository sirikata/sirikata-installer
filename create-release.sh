#!/bin/bash
#
# create-release.sh x y z
#
# Grab the raw binaries and make the necessary modifications to create
# installers for each platform. Essentially, this downloads and
# extracts the main install contents and sets up the version
# number. After executing this, you need to run BitRock InstallBuilder
# and generate each of the installers, unless it can be found in your
# PATH, in which case it will be run automatically to build the
# packages.

VERSION_MAJOR=$1
VERSION_MINOR=$2
VERSION_REVISION=$3

VERSION=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_REVISION}
VERSION_INT=$((${VERSION_MAJOR}*1000000 + ${VERSION_MINOR}*1000 + ${VERSION_REVISION}))

# Clean out any old data
rm -rf sirikata_win32
rm -rf sirikata_mac
rm -f sirikata-win32-autoupdate.exe
rm -rf sirikata-mac-autoupdate.app
rm -rf sirikata-${VERSION}-mac-installer.app
rm -f sirikata-${VERSION}-mac-installer.dmg
rm -f sirikata-${VERSION}-win32-installer.exe

# Grab and extract data
echo "Grabbing and extracting raw packages..."
([ -e sirikata-$VERSION-win32.zip ] || wget http://sirikata.com/releases/win32/sirikata-$VERSION-win32.zip) && \
    unzip -q sirikata-$VERSION-win32.zip

([ -e sirikata-$VERSION-mac.tar.gz ] || wget http://sirikata.com/releases/mac/sirikata-$VERSION-mac.tar.gz) && \
    tar -xzf sirikata-$VERSION-mac.tar.gz

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
sed "s/__VERSIONINT__/${VERSION_INT}/" sirikata.xml | sed "s/__VERSION__/${VERSION}/" > sirikata-$VERSION.xml
# And generate update.xml with correct version info for the server
sed "s/__VERSIONINT__/${VERSION_INT}/" update-template.xml | sed "s/__VERSION__/${VERSION}/" > update.xml

# Try to run InstallBuilder if we can find it
INSTALLBUILDER=`which builder`
if [ "x${INSTALLBUILDER}" == "x" ]; then
    echo "Couldn't find InstallBuilder. You need to open sirikata-${VERSION}.xml manually and build the packages."
else
    INSTALLBUILDER_BIN=`dirname ${INSTALLBUILDER}`
    INSTALLBUILDER_BASE=`dirname ${INSTALLBUILDER_BIN}`
    INSTALLBUILDER_AUTOUPDATE=${INSTALLBUILDER_BASE}/autoupdate/bin/customize.run

    echo "Building autoupdaters"
    ${INSTALLBUILDER_AUTOUPDATE} build sirikata-autoupdate.xml windows
    ${INSTALLBUILDER_AUTOUPDATE} build sirikata-autoupdate.xml osx
    echo "Copying to current directory..."
    cp -r ${INSTALLBUILDER_BASE}/autoupdate/output/autoupdate-windows.exe sirikata-win32-autoupdate.exe
    cp -r ${INSTALLBUILDER_BASE}/autoupdate/output/autoupdate-osx.app sirikata-mac-autoupdate.app


    echo "Building installers for Windows and Mac..."
    ${INSTALLBUILDER} build sirikata-$VERSION.xml windows
    ${INSTALLBUILDER} build sirikata-$VERSION.xml osx
    echo "Copying to current directory..."
    # Copy installer app, works for both regular and update
    cp -r `dirname ${INSTALLBUILDER}`/../output/Sirikata-${VERSION}-osx-installer.app sirikata-${VERSION}-mac-installer.app
    # Generate dmg for regular installs
    genisoimage -D -V "sirikata-${VERSION}" -no-pad -r -apple -root sirikata-${VERSION}-mac-installer.app -o sirikata-${VERSION}-mac-installer.dmg sirikata-${VERSION}-mac-installer.app
    # Regular archive for updater
    tar -czf sirikata-${VERSION}-mac-installer.tgz sirikata-${VERSION}-mac-installer.app
    # Copy the windows installer
    cp -r `dirname ${INSTALLBUILDER}`/../output/Sirikata-${VERSION}-windows-installer.exe sirikata-${VERSION}-win32-installer.exe
    echo "Done"


    rm sirikata-${VERSION}.xml

    echo
    echo
    echo "*****************************"
    echo
    echo "Finished generating installers. You need to upload:"
    echo " * the installer packages to sirikata.com/releases/[mac/win32]"
    echo " * the update installer package (tgz version) for mac to sirikata.com/releases/mac"
    echo " * update.xml to sirikata.com/releases/"
    echo
    echo "   e.g."
    echo "    scp sirikata-${VERSION}-win32-installer.exe user@server:sirikata.com/releases/win32/"
    echo "    scp sirikata-${VERSION}-mac-installer.dmg user@server:sirikata.com/releases/mac/"
    echo "    scp sirikata-${VERSION}-mac-installer.dmg user@server:sirikata.com/releases/mac/"
    echo "    scp update.xml user@server:sirikata.com/releases/"
    echo

fi