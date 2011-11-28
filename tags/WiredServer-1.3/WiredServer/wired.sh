#!/bin/sh

ROOT="$1"

# Create skeleton directories
mkdir -p "$ROOT/Library/PreferencePanes"
mkdir -p "$ROOT/Library/StartupItems"
mkdir -p "$ROOT/Library/Wired"
mkdir -p "$ROOT/usr/local"

# Build a universal wired installation
cd wired

if [ -d obj ]; then
	rm -r obj
fi

if [ -d libwired/obj ]; then
	rm -r libwired/obj
fi

for i in $ARCHS; do
	CONFIG_H="config_$i.h"
	CONFIG_STATUS="config_$i.status"
	HL2WIRED="run/hl2wired_$i"
	LIBWIRED="libwired/run/lib/libwired_$i.a"
	MAKEFILE="Makefile_$i"
	OBJDIR="obj_$i"
	WIRED="run/wired_$i"
	
	for j in . libwired; do
		rm -f "$j/obj"

		rm -f "$j/config.h"
		rm -f "$j/config.status"
		rm -f "$j/Makefile"
		rm -f "$j/obj"
	done
	
	SDKROOT=$(eval echo SDKROOT_$i); SDKROOT=$(eval echo \$$SDKROOT)

	export CFLAGS="-g -O2 -arch $i"
	export CPPFLAGS="-isysroot $SDKROOT"
	
	if [ ! -e "$MAKEFILE" ]; then
		for j in . libwired; do
			rm -f "$j/config.status" "$j/config.h" "$j/Makefile"
		done

		UNAME_R=$(uname -r)

		./configure --build=$(./config.guess) --host="$i-apple-darwin$UNAME_R" --prefix="$ROOT/Library" --with-fake-prefix="/Library" --with-wireddir="Wired" --mandir="$ROOT/usr/local/man"  --enable-warnings || exit 1

		for j in . libwired; do
			mv "$j/config.h" "$j/$CONFIG_H"
			mv "$j/config.status" "$j/$CONFIG_STATUS"
			mv "$j/Makefile" "$j/$MAKEFILE"
		done
	fi
	
	for j in . libwired; do
		mkdir -p "$j/$OBJDIR"

		ln -sf "$CONFIG_H" "$j/config.h"
		ln -sf "$CONFIG_STATUS" "$j/config.status"
		ln -sf "$MAKEFILE" "$j/Makefile"
		ln -sf "$OBJDIR" "$j/obj"
	done
	
	if [ -e "$HL2WIRED" ]; then
		mv "$HL2WIRED" run/hl2wired
	fi

	if [ -e "$LIBWIRED" ]; then
		mv "$LIBWIRED" libwired/run/lib/libwired.a
	fi

	if [ -e "$WIRED" ]; then
		mv "$WIRED" run/wired
	fi

	make || exit 1
	
	mv run/hl2wired "$HL2WIRED"
	mv libwired/run/lib/libwired.a "$LIBWIRED"
	mv run/wired "$WIRED"
	
	HL2WIRED_BINARIES="$HL2WIRED $HL2WIRED_BINARIES"
	WIRED_BINARIES="$WIRED $WIRED_BINARIES"
done

lipo -create $HL2WIRED_BINARIES -output run/hl2wired || exit 1
lipo -create $WIRED_BINARIES -output run/wired || exit 1

# Install wired into /Library/Wired
sudo make install-only || exit 1

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
