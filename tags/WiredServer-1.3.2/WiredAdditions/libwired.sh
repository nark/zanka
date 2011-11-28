#!/bin/sh

for i in $ARCHS; do
	if [ -f "$TEMP_FILE_DIR/archs" ]; then
		PREVIOUS_ARCHS=$(cat "$TEMP_FILE_DIR/archs")
		
		if [ "$ARCHS" != "$PREVIOUS_ARCHS" ]; then
			rm -f "$BUILT_PRODUCTS_DIR/libwired.a"
		fi
	fi
		
	if [ ! -f "$TEMP_FILE_DIR/make/$i/Makefile" ]; then
		SDKROOT=$(eval echo SDKROOT_$i); SDKROOT=$(eval echo \$$SDKROOT)
		MACOSX_DEPLOYMENT_TARGET=$(eval echo MACOSX_DEPLOYMENT_TARGET_$i); MACOSX_DEPLOYMENT_TARGET=$(eval echo \$$MACOSX_DEPLOYMENT_TARGET)
		RELEASE=$(uname -r)
		BUILD=$("$SRCROOT/libwired/config.guess")
		HOST="$i-apple-darwin$RELEASE"
		
		cd "$SRCROOT/libwired"
		CFLAGS="-g -O2 -arch $i -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET" CPPFLAGS="-I$TEMP_FILE_DIR/make/$i -isysroot $SDKROOT" ./configure --build="$BUILD" --host="$HOST" --srcdir="$SRCROOT/libwired" --enable-warnings --enable-pthreads --enable-ssl --with-objdir="$OBJECT_FILE_DIR/$i" --with-rundir="$TEMP_FILE_DIR/run/$i/libwired" || exit 1

		mkdir -p "$TEMP_FILE_DIR/make/$i" "$TEMP_FILE_DIR/run/$i" "$BUILT_PRODUCTS_DIR"
		mv "$SRCROOT/libwired/config.h" "$TEMP_FILE_DIR/make/$i/config.h"
		mv "$SRCROOT/libwired/Makefile" "$TEMP_FILE_DIR/make/$i/Makefile"
		rm -rf "$TEMP_FILE_DIR/run/$i/libwired"
		cp -r "$SRCROOT/libwired/run" "$TEMP_FILE_DIR/run/$i/libwired"
	fi
	
	if [ ! -d "$BUILT_PRODUCTS_DIR/wired/" ]; then
		ln -sf "$TEMP_FILE_DIR/run/$i/libwired/include/wired" "$BUILT_PRODUCTS_DIR/wired"
	fi

	cd "$TEMP_FILE_DIR/make/$i"
	make -f "$TEMP_FILE_DIR/make/$i/Makefile" || exit 1
	
	if [ "$TEMP_FILE_DIR/run/$i/libwired/lib/libwired.a" -nt "$BUILT_PRODUCTS_DIR/libwired.a" ]; then
		LIPO=1
	fi
	
	LIBWIRED_BINARIES="$TEMP_FILE_DIR/run/$i/libwired/lib/libwired.a $LIBWIRED_BINARIES"
	LIBWIRED_INCLUDES="$TEMP_FILE_DIR/run/$i/libwired/include/wired"
done

echo "$ARCHS" > "$TEMP_FILE_DIR/archs"

if [ "$LIPO" ]; then
	lipo -create $LIBWIRED_BINARIES -output "$BUILT_PRODUCTS_DIR/libwired.a" || exit 1
	touch "$BUILT_PRODUCTS_DIR/libwired.a"
	ranlib "$BUILT_PRODUCTS_DIR/libwired.a"
fi

exit 0
