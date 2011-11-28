#!/bin/sh

DST=$1

rm -f "$DST/English.lproj/Localizable.strings"
find . -name "*.[mc]" | xargs genstrings -s NSLS -s WPLS -s WCLS -q -o "$DST/English.lproj" -a

exit 0
