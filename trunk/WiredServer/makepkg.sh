#!/bin/sh

ROOT="$1"
PACKAGE="$2"

rm -rf "$PACKAGE"
/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker -build -v -ds -p "$PACKAGE" -f "$ROOT/Contents" -r "$ROOT/Resources" -i "$ROOT/Info.plist" -d "$ROOT/Resources/English.lproj/Description.plist" || exit 1

exit 0
