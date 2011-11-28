#!/bin/sh

ROOT="$1"

# Create skeleton directories
mkdir -p "$ROOT/Library/PreferencePanes"
mkdir -p "$ROOT/Library/StartupItems"
mkdir -p "$ROOT/Library/Wired"

# Build a universal wired installation
for i in $ARCHS; do
	if [ ! -f "$TEMP_FILE_DIR/make/$i/Makefile" ]; then
		SDKROOT=$(eval echo SDKROOT_$i); SDKROOT=$(eval echo \$$SDKROOT)
		RELEASE=$(uname -r)
		BUILD=$("$SRCROOT/wired/config.guess")
		HOST="$i-apple-darwin$RELEASE"
		
		cd "$SRCROOT/wired"
		CFLAGS="-g -O2 -arch $i" CPPFLAGS="-I$TEMP_FILE_DIR/make/$i -isysroot $SDKROOT" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --srcdir="$SRCROOT/wired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$TEMP_FILE_DIR/run/$i/wired" --prefix="$ROOT/Library" --with-fake-prefix="/Library" --with-wireddir="Wired" --mandir="$ROOT/usr/local/man" --without-libwired || exit 1
		
		cd "$SRCROOT/wired/libwired"
		CFLAGS="-g -O2 -arch $i" CPPFLAGS="-I$TEMP_FILE_DIR/make/$i/libwired -isysroot $SDKROOT" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --enable-ssl --enable-pthreads --srcdir="$SRCROOT/wired/libwired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$TEMP_FILE_DIR/run/$i/wired/libwired" || exit 1

		mkdir -p "$TEMP_FILE_DIR/make/$i/libwired" "$TEMP_FILE_DIR/run/$i" "$BUILT_PRODUCTS_DIR"
		mv "$SRCROOT/wired/config.h" "$TEMP_FILE_DIR/make/$i/config.h"
		mv "$SRCROOT/wired/libwired/config.h" "$TEMP_FILE_DIR/make/$i/libwired/config.h"
		mv "$SRCROOT/wired/Makefile" "$TEMP_FILE_DIR/make/$i/Makefile"
		mv "$SRCROOT/wired/libwired/Makefile" "$TEMP_FILE_DIR/make/$i/libwired/Makefile"
		cp -r "$SRCROOT/wired/run" "$TEMP_FILE_DIR/run/$i/wired"
		cp -r "$SRCROOT/wired/libwired/run" "$TEMP_FILE_DIR/run/$i/wired/libwired"
	fi
	
	cd "$TEMP_FILE_DIR/make/$i"
	make -f "$TEMP_FILE_DIR/make/$i/Makefile" || exit 1
	
	HL2WIRED_BINARIES="$TEMP_FILE_DIR/run/$i/wired/hl2wired $HL2WIRED_BINARIES"
	WIRED_BINARIES="$TEMP_FILE_DIR/run/$i/wired/wired $WIRED_BINARIES"
	MASTER="$i"
done

lipo -create $HL2WIRED_BINARIES -output /tmp/hl2wired || exit 1
cp /tmp/hl2wired "$TEMP_FILE_DIR/run/$MASTER/wired/hl2wired"

lipo -create $WIRED_BINARIES -output /tmp/wired || exit 1
cp /tmp/wired "$TEMP_FILE_DIR/run/$MASTER/wired/wired"

# Install wired into /Library/Wired
sudo make -f "$TEMP_FILE_DIR/make/$MASTER/Makefile" install-only || exit 1

# Install /Library/PreferencePanes and /Library/StartupItems
cd "$SRCROOT"
cp -Rp "$BUILT_PRODUCTS_DIR/Wired.prefPane" "$ROOT/Library/PreferencePanes/"
cp -Rp "StartupItems/Wired" "$ROOT/Library/StartupItems/"

# Fix permissions
sudo chmod 1775 "$ROOT"
sudo chown root:wheel "$ROOT"

sudo chmod 775 "$ROOT/Library"
sudo chown root:admin "$ROOT/Library"

find "$ROOT/Library/PreferencePanes" \( -type d -o -perm +111 \) -print0 | sudo xargs -0 chmod 775
find "$ROOT/Library/PreferencePanes" \( -type f -a ! -perm +111 \) -print0 | sudo xargs -0 chmod 664
sudo chown -R root:admin "$ROOT/Library/PreferencePanes"

sudo chown -R root:wheel "$ROOT/Library/StartupItems"

sudo chmod 755 "$ROOT/usr" "$ROOT/usr/local"
sudo chown root:wheel "$ROOT/usr" "$ROOT/usr/local"

exit 0
