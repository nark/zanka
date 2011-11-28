#!/bin/sh

LIBRARY="$1"

rm -rf "$LIBRARY/Wired" || exit 1

launchctl unload -w "$LIBRARY/LaunchAgents/com.zankasoftware.WiredServer.plist" || exit 1
rm -f "$LIBRARY/LaunchAgents/com.zankasoftware.WiredServer.plist" || exit 1

exit 0
