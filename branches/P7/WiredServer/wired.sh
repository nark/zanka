#!/bin/sh

PATH="/opt/local/bin:/usr/local/bin:$PATH"

if echo $DEBUG_INFORMATION_FORMAT | grep -q dwarf; then
	CFLAGS="-gdwarf-2"
else
	CFLAGS="-gstabs"
fi

if echo $CONFIGURATION | grep -q Debug; then
	CFLAGS="$CFLAGS -O0"
else
	CFLAGS="$CFLAGS -O2"
fi

WIRED_USER=$(id -un)
WIRED_GROUP=$(id -gn)

BUILD=$("$SRCROOT/wired/config.guess")

for i in $ARCHS; do
	if [ ! -f "$TARGET_TEMP_DIR/make/$i/Makefile" -o ! -f "$TARGET_TEMP_DIR/configured" ]; then
		HOST="$i-apple-darwin$(uname -r)"
		ARCH_CC="$PLATFORM_DEVELOPER_BIN_DIR/gcc-$GCC_VERSION -arch $i"
		ARCH_CFLAGS="$CFLAGS"
		ARCH_CPPFLAGS="$CPPFLAGS"

		if [ "$i" = "i386" -o "$i" = "ppc" ]; then
			SDKROOT="$DEVELOPER_SDK_DIR/MacOSX10.4u.sdk"
			MACOSX_DEPLOYMENT_TARGET=10.4
		elif [ "$i" = "x86_64" -o "$i" = "ppc64" ]; then
			SDKROOT="$DEVELOPER_SDK_DIR/MacOSX10.5.sdk"
			MACOSX_DEPLOYMENT_TARGET=10.5
		fi

		ARCH_CPPFLAGS="$ARCH_CPPFLAGS -isysroot $SDKROOT -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"

		cd "$SRCROOT/wired"
		CC="$ARCH_CC" CFLAGS="$ARCH_CFLAGS" CPPFLAGS="$ARCH_CPPFLAGS -I$TARGET_TEMP_DIR/make/$i" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --srcdir="$SRCROOT/wired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$TARGET_TEMP_DIR/run/$i/wired" --prefix="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH" --with-fake-prefix="/Library" --with-wireddir="Wired" --with-user="$WIRED_USER" --with-group="$WIRED_GROUP" --without-libwired || exit 1
		
		mkdir -p "$TARGET_TEMP_DIR/make/$i/libwired" "$TARGET_TEMP_DIR/run/$i" "$BUILT_PRODUCTS_DIR"
		mv config.h Makefile "$TARGET_TEMP_DIR/make/$i/"

		cd "$SRCROOT/wired/libwired"
		CC="$ARCH_CC" CFLAGS="$ARCH_CFLAGS" CPPFLAGS="$ARCH_CPPFLAGS -I$TARGET_TEMP_DIR/make/$i/libwired" ./configure --build="$BUILD" --host="$HOST" --enable-warnings --enable-pthreads --enable-libxml2 --enable-p7 --enable-sqlite3 --srcdir="$SRCROOT/wired/libwired" --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$TARGET_TEMP_DIR/run/$i/wired/libwired" || exit 1

		mv config.h Makefile "$TARGET_TEMP_DIR/make/$i/libwired"
		
		touch "$TARGET_TEMP_DIR/configured"
	fi
	
	cd "$TARGET_TEMP_DIR/make/$i"
	make -f "$TARGET_TEMP_DIR/make/$i/Makefile" || exit 1
done

for i in $ARCHS; do
	WIRED_BINARIES="$TARGET_TEMP_DIR/run/$i/wired/wired $WIRED_BINARIES"
	MASTER="$i"
done

cp "$TARGET_TEMP_DIR/run/$MASTER/wired/wired" "/tmp/wired.$MASTER"
lipo -create $WIRED_BINARIES -output "/tmp/wired.universal" || exit 1
cp "/tmp/wired.universal" "$TARGET_TEMP_DIR/run/$MASTER/wired/wired"
codesign -f -s "Mac OS X Developer: Axel Andersson" "$TARGET_TEMP_DIR/run/$MASTER/wired/wired"

mkdir -p "$TARGET_TEMP_DIR/run/$MASTER/wired/events"
mkdir -p "$TARGET_TEMP_DIR/run/$MASTER/wired/files/Drop Box/.wired" "$TARGET_TEMP_DIR/run/$MASTER/wired/files/Uploads/.wired"
mkdir -p "$TARGET_TEMP_DIR/run/$MASTER/wired/board/General/.wired" "$TARGET_TEMP_DIR/run/$MASTER/wired/board/General/BC5B30BF-AC4F-4FEE-BB92-C5F3A5436E18.WiredThread"

for i in "banlist" "banner.png" "board/General/.wired/permissions" "board/General/BC5B30BF-AC4F-4FEE-BB92-C5F3A5436E18.WiredThread/AD70D7CB-F789-4030-A92F-40D546DBE1D9.WiredPost" "events/current" "files/Drop Box/.wired/permissions" "files/Drop Box/.wired/type" "files/Uploads/.wired/type" "groups" "users" "wired.xml"; do
	cp "$SRCROOT/wired/run/$i" "$TARGET_TEMP_DIR/run/$MASTER/wired/$i"
done

make -f "$TARGET_TEMP_DIR/make/$MASTER/Makefile" install-wired || exit 1

cp "/tmp/wired.$MASTER" "$TARGET_TEMP_DIR/run/$MASTER/wired/wired"

find "$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH" -name .svn -print0 | xargs -0 sudo rm -rf
