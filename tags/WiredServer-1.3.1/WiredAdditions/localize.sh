#!/bin/sh

rm -f English.lproj/Localizable.strings
find . -name "*.[mc]" | xargs genstrings -s NSLS -s WILS -q -o English.lproj -a

exit 0
