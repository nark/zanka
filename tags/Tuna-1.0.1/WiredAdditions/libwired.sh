#!/bin/sh

cd libwired

if [ -d obj ]; then
	rm -r obj
fi

for i in $ARCHS; do
	CONFIG_H="config_$i.h"
	CONFIG_STATUS="config_$i.status"
	LIBWIRED="run/lib/libwired_$i.a"
	MAKEFILE="Makefile_$i"
	OBJDIR="obj_$i"

	OLD_CFLAGS="$CFLAGS"
	SDKROOT=$(eval echo SDKROOT_$i); SDKROOT=$(eval echo \$$SDKROOT)
	export CFLAGS="-g -O2 -arch $i -isysroot $SDKROOT $CFLAGS"

	if [ ! -e "$MAKEFILE" ]; then
		rm -f config.status config.h Makefile
		
		UNAME_R=$(uname -r)

		./configure --build=$(./config.guess) --host="$i-apple-darwin$UNAME_R" --enable-warnings --enable-pthreads --enable-ssl || exit 1

		mv config.h "$CONFIG_H"
		mv config.status "$CONFIG_STATUS"
		mv Makefile "$MAKEFILE"
	fi

	rm -f obj
	mkdir -p "$OBJDIR"

	ln -sf "$CONFIG_H" config.h
	ln -sf "$CONFIG_STATUS" config.status
	ln -sf "$MAKEFILE" Makefile
	ln -sf "$OBJDIR" obj

	if [ -e "$LIBWIRED" ]; then
		mv "$LIBWIRED" run/lib/libwired.a
	fi

	make || exit 1

	mv run/lib/libwired.a "$LIBWIRED"

	LIBWIRED_BINARIES="$LIBWIRED $LIBWIRED_BINARIES"

	CFLAGS="$OLD_CFLAGS"
done

lipo -create $LIBWIRED_BINARIES -output run/lib/libwired.a || exit 1

exit 0
