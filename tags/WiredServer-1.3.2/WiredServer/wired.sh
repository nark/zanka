#!/bin/sh

BUILDDIR="$1"
INSTALLDIR="$2"

for i in $ARCHS; do
	if [ ! -f "$BUILDDIR/make/$i/Makefile" ]; then
		SDKROOT=$(eval echo SDKROOT_$i); SDKROOT=$(eval echo \$$SDKROOT)
		MACOSX_DEPLOYMENT_TARGET=$(eval echo MACOSX_DEPLOYMENT_TARGET_$i); MACOSX_DEPLOYMENT_TARGET=$(eval echo \$$MACOSX_DEPLOYMENT_TARGET)
		RELEASE=$(uname -r)
		BUILD=$("$SRCROOT/wired/config.guess")
		HOST="$i-apple-darwin$RELEASE"
		
		cd "$SRCROOT/wired"
		CFLAGS="-g -O2 -arch $i -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET" CPPFLAGS="-I$BUILDDIR/make/$i -isysroot $SDKROOT" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --srcdir="$SRCROOT/wired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$BUILDDIR/run/$i/wired" --prefix="$INSTALLDIR/Library" --with-fake-prefix="/Library" --with-wireddir="Wired" --mandir="$INSTALLDIR/usr/local/man" --without-libwired || exit 1
		
		cd "$SRCROOT/wired/libwired"
		CFLAGS="-g -O2 -arch $i -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET" CPPFLAGS="-I$BUILDDIR/make/$i/libwired -isysroot $SDKROOT" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --enable-ssl --enable-pthreads --srcdir="$SRCROOT/wired/libwired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$BUILDDIR/run/$i/wired/libwired" || exit 1

		mkdir -p "$BUILDDIR/make/$i/libwired" "$BUILDDIR/run/$i" "$BUILT_PRODUCTS_DIR"
		mv "$SRCROOT/wired/config.h" "$BUILDDIR/make/$i/config.h"
		mv "$SRCROOT/wired/libwired/config.h" "$BUILDDIR/make/$i/libwired/config.h"
		mv "$SRCROOT/wired/Makefile" "$BUILDDIR/make/$i/Makefile"
		mv "$SRCROOT/wired/libwired/Makefile" "$BUILDDIR/make/$i/libwired/Makefile"
		cp -r "$SRCROOT/wired/run" "$BUILDDIR/run/$i/wired"
		cp -r "$SRCROOT/wired/libwired/run" "$BUILDDIR/run/$i/wired/libwired"
	fi
	
	cd "$BUILDDIR/make/$i"
	make -f "$BUILDDIR/make/$i/Makefile" || exit 1
done

exit 0
