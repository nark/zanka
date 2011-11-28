#!/bin/sh

mkdir -p "$PROJECT_TEMP_DIR/Package/Contents/Library/PreferencePanes"
mkdir -p "$PROJECT_TEMP_DIR/Package/Contents/Library/StartupItems"
mkdir -p "$PROJECT_TEMP_DIR/Package/Contents/Library/Wired"

for i in $ARCHS; do
	WIRED_BINARIES="$PROJECT_TEMP_DIR/run/$i/wired/wired $WIRED_BINARIES"
	MASTER="$i"
done

cp "$PROJECT_TEMP_DIR/run/$MASTER/wired/wired" "/tmp/wired.$MASTER"
lipo -create $WIRED_BINARIES -output "/tmp/wired.universal" || exit 1
cp "/tmp/wired.universal" "$PROJECT_TEMP_DIR/run/$MASTER/wired/wired"

sudo make -f "$PROJECT_TEMP_DIR/make/$MASTER/Makefile" install-only || exit 1

cp "/tmp/wired.$MASTER" "$PROJECT_TEMP_DIR/run/$MASTER/wired/wired"

cp -Rp "$BUILT_PRODUCTS_DIR/Wired.prefPane" "$PROJECT_TEMP_DIR/Package/Contents/Library/PreferencePanes/"
cp -Rp "StartupItems/Wired" "$PROJECT_TEMP_DIR/Package/Contents/Library/StartupItems/"

sudo chmod 1775 "$PROJECT_TEMP_DIR/Package/Contents"
sudo chown root:wheel "$PROJECT_TEMP_DIR/Package/Contents"

sudo chmod 775 "$PROJECT_TEMP_DIR/Package/Contents/Library"
sudo chown root:admin "$PROJECT_TEMP_DIR/Package/Contents/Library"

find "$PROJECT_TEMP_DIR/Package/Contents/Library/PreferencePanes" \( -type d -o -perm +111 \) -print0 | sudo xargs -0 chmod 775
find "$PROJECT_TEMP_DIR/Package/Contents/Library/PreferencePanes" \( -type f -a ! -perm +111 \) -print0 | sudo xargs -0 chmod 664
sudo chmod 775 "$PROJECT_TEMP_DIR/Package/Contents/Library/PreferencePanes"
sudo chown -R root:admin "$PROJECT_TEMP_DIR/Package/Contents/Library/PreferencePanes"

sudo chown -R root:wheel "$PROJECT_TEMP_DIR/Package/Contents/Library/StartupItems"

sudo chmod 755 "$PROJECT_TEMP_DIR/Package/Contents/usr" "$PROJECT_TEMP_DIR/Package/Contents/usr/local"
sudo chown root:wheel "$PROJECT_TEMP_DIR/Package/Contents/usr" "$PROJECT_TEMP_DIR/Package/Contents/usr/local"
