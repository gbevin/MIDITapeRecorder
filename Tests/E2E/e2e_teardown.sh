#!/bin/bash
# quits the app, unregisters the scratch plugin and stops the routes and captures
HERE="$(cd "$(dirname "$0")" && pwd)"; WORK="${MTR_E2E_WORK:-$HERE/.work}"; DD="${MTR_E2E_DERIVED_DATA:-$WORK/dd}"
osascript -e 'tell application "MIDI Tape Recorder" to quit' 2>/dev/null; sleep 2
pkill -f "receivemidi dev" 2>/dev/null; pkill -f "routemidi vin Drive1" 2>/dev/null
pluginkit -r "$DD/Build/Products/Debug-maccatalyst/MIDI Tape Recorder.app/Contents/PlugIns/MIDI Tape Recorder Plugin.appex" 2>/dev/null
killall -9 AudioComponentRegistrar 2>/dev/null
echo "torn down"
