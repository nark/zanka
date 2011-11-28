#!/bin/sh

rm -f English.lproj/Localizable.strings
find . -name "*.[mc]" | xargs genstrings -s NSLS -q -o English.lproj -a

exit 0
