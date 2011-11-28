#!/bin/sh

mkdir -p "$PROJECT_TEMP_DIR/Package/Contents/Library/Wired"

for i in $ARCHS; do
	TRACKERD_BINARIES="$PROJECT_TEMP_DIR/run/$i/trackerd/trackerd $TRACKERD_BINARIES"
	MASTER="$i"
done

cp "$PROJECT_TEMP_DIR/run/$MASTER/trackerd/trackerd" "/tmp/trackerd.$MASTER"
lipo -create $TRACKERD_BINARIES -output "/tmp/trackerd.universal" || exit 1
cp "/tmp/trackerd.universal" "$PROJECT_TEMP_DIR/run/$MASTER/trackerd/trackerd"

sudo make -f "$PROJECT_TEMP_DIR/make/$MASTER/Makefile" install-only || exit 1

cp "/tmp/trackerd.$MASTER" "$PROJECT_TEMP_DIR/run/$MASTER/trackerd/trackerd"

sudo chmod 1775 "$PROJECT_TEMP_DIR/Package/Contents"
sudo chown root:wheel "$PROJECT_TEMP_DIR/Package/Contents"

sudo chmod 775 "$PROJECT_TEMP_DIR/Package/Contents/Library"
sudo chown root:admin "$PROJECT_TEMP_DIR/Package/Contents/Library"

sudo chmod 755 "$PROJECT_TEMP_DIR/Package/Contents/usr" "$PROJECT_TEMP_DIR/Package/Contents/usr/local"
sudo chown root:wheel "$PROJECT_TEMP_DIR/Package/Contents/usr" "$PROJECT_TEMP_DIR/Package/Contents/usr/local"
