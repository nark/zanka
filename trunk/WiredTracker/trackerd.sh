#!/bin/sh

PATH="/opt/local/bin:/usr/local/bin:/usr/bin:/bin"

if echo $DEBUG_INFORMATION_FORMAT | grep -q dwarf; then
	CFLAGS="-gdwarf-2"
else
	CFLAGS="-gstabs"
fi

if echo $CONFIGURATION | grep -q Release; then
	CFLAGS="$CFLAGS -O2"
else
	CFLAGS="$CFLAGS -O0"
fi

BUILD=$("$SRCROOT/trackerd/config.guess")

for i in $ARCHS; do
	if [ ! -f "$PROJECT_TEMP_DIR/make/$i/Makefile" -o ! -f "$TARGET_TEMP_DIR/configured" ]; then
		HOST="$i-apple-darwin$(uname -r)"
		ARCH_CFLAGS="$CFLAGS"
		ARCH_CPPFLAGS="$CPPFLAGS"
		ARCH_CC="$PLATFORM_DEVELOPER_BIN_DIR/gcc-$GCC_VERSION -arch $i"

		if [ "$i" = "i386" -o "$i" = "ppc" ]; then
			SDKROOT="$DEVELOPER_SDK_DIR/MacOSX10.4u.sdk"
			MACOSX_DEPLOYMENT_TARGET=10.4
		elif [ "$i" = "x86_64" -o "$i" = "ppc64" ]; then
			SDKROOT="$DEVELOPER_SDK_DIR/MacOSX10.5.sdk"
			MACOSX_DEPLOYMENT_TARGET=10.5
		fi

		ARCH_CPPFLAGS="$ARCH_CPPFLAGS -isysroot $SDKROOT -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"

		cd "$SRCROOT/trackerd"
		CC="$ARCH_CC" CFLAGS="$ARCH_CFLAGS" CPPFLAGS="$ARCH_CPPFLAGS -I$PROJECT_TEMP_DIR/make/$i" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --srcdir="$SRCROOT/trackerd" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$PROJECT_TEMP_DIR/run/$i/trackerd" --prefix="$PROJECT_TEMP_DIR/Package/Contents/Library" --with-fake-prefix="/Library" --with-trackerddir="Wired" --mandir="$PROJECT_TEMP_DIR/Package/Contents/usr/local/man" --without-libwired || exit 1
		
		mkdir -p "$PROJECT_TEMP_DIR/make/$i/libwired" "$PROJECT_TEMP_DIR/run/$i" "$BUILT_PRODUCTS_DIR"
		mv config.h Makefile "$PROJECT_TEMP_DIR/make/$i/"
		cp -r run "$PROJECT_TEMP_DIR/run/$i/trackerd"

		cd "$SRCROOT/trackerd/libwired"
		CC="$ARCH_CC" CFLAGS="$ARCH_CFLAGS" CPPFLAGS="$ARCH_CPPFLAGS -I$PROJECT_TEMP_DIR/make/$i/libwired" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --enable-ssl --enable-pthreads --srcdir="$SRCROOT/trackerd/libwired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$PROJECT_TEMP_DIR/run/$i/trackerd/libwired" || exit 1
		mv config.h Makefile "$PROJECT_TEMP_DIR/make/$i/libwired"
		cp -r run "$PROJECT_TEMP_DIR/run/$i/trackerd/libwired"
		
		touch "$TARGET_TEMP_DIR/configured"
	fi
	
	cd "$PROJECT_TEMP_DIR/make/$i"
	make -f "$PROJECT_TEMP_DIR/make/$i/Makefile" || exit 1
done
