#!/bin/sh

touch "$SRCROOT/.version"
OLD_VERSION=$(cat "$SRCROOT/.version")

if [ -z "$OLD_VERSION" ]; then
	OLD_VERSION="0"
fi

VERSION=$(expr $OLD_VERSION + 1)

OLD_STRING=$(printf "%x" $OLD_VERSION | tr "[:lower:]" "[:upper:]")
STRING=$(printf "%x" $VERSION | tr "[:lower:]" "[:upper:]")

cp "$BUILD_DIR/$WRAPPER_NAME/Contents/Info.plist" .Info.plist

cat .Info.plist | sed -e "s,CFBundleVersionKey,$STRING," | sed -e "s,<string>$OLD_STRING</string>,<string>$STRING</string>," > "$BUILD_DIR/$WRAPPER_NAME/Contents/Info.plist"

rm -rf "$BUILD_DIR/$EXECUTABLE_NAME build $OLD_STRING.$WRAPPER_EXTENSION" .Info.plist
ln -sf "$BUILD_DIR/$WRAPPER_NAME" "$BUILD_DIR/$EXECUTABLE_NAME build $STRING.$WRAPPER_EXTENSION"

echo "$VERSION" > $SRCROOT/.version

exit 0
