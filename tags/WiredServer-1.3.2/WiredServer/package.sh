#!/bin/sh

BUILDDIR="$1"
INSTALLDIR="$2"

# Create skeleton directories
mkdir -p "$INSTALLDIR/Library/PreferencePanes"
mkdir -p "$INSTALLDIR/Library/StartupItems"
mkdir -p "$INSTALLDIR/Library/Wired"

# Build a universal wired installation
for i in $ARCHS; do
	WIRED_BINARIES="$BUILDDIR/run/$i/wired/wired $WIRED_BINARIES"
	MASTER="$i"
done

cp "$BUILDDIR/run/$MASTER/wired/wired" "/tmp/wired.$MASTER"
lipo -create $WIRED_BINARIES -output "/tmp/wired.universal" || exit 1
cp "/tmp/wired.universal" "$BUILDDIR/run/$MASTER/wired/wired"

# Install wired into /Library/Wired
sudo make -f "$BUILDDIR/make/$MASTER/Makefile" install-only || exit 1

# Restore thin binary
cp "/tmp/wired.$MASTER" "$BUILDDIR/run/$MASTER/wired/wired"

# Install /Library/PreferencePanes and /Library/StartupItems
cd "$SRCROOT"
cp -Rp "$BUILT_PRODUCTS_DIR/Wired.prefPane" "$INSTALLDIR/Library/PreferencePanes/"
cp -Rp "StartupItems/Wired" "$INSTALLDIR/Library/StartupItems/"

# Fix permissions
sudo chmod 1775 "$INSTALLDIR"
sudo chown root:wheel "$INSTALLDIR"

sudo chmod 775 "$INSTALLDIR/Library"
sudo chown root:admin "$INSTALLDIR/Library"

find "$INSTALLDIR/Library/PreferencePanes" \( -type d -o -perm +111 \) -print0 | sudo xargs -0 chmod 775
find "$INSTALLDIR/Library/PreferencePanes" \( -type f -a ! -perm +111 \) -print0 | sudo xargs -0 chmod 664
sudo chown -R root:admin "$INSTALLDIR/Library/PreferencePanes"

sudo chown -R root:wheel "$INSTALLDIR/Library/StartupItems"

sudo chmod 755 "$INSTALLDIR/usr" "$INSTALLDIR/usr/local"
sudo chown root:wheel "$INSTALLDIR/usr" "$INSTALLDIR/usr/local"

exit 0
