#!/bin/bash
# builds the Catalyst Debug app, wires four RouteMIDI virtual routes (Drive1-4 -> Src1-4) as the
# track inputs, registers the plugin, launches the app and caches what the python harness needs.
# requirements: sendmidi, receivemidi, routemidi (brew), the terminal granted Accessibility (and
# Screen Recording for shotwin.py), screen unlocked at launch.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${MTR_E2E_WORK:-$HERE/.work}"; mkdir -p "$WORK"; cd "$WORK"
DD="${MTR_E2E_DERIVED_DATA:-$WORK/dd}"
APP="$DD/Build/Products/Debug-maccatalyst/MIDI Tape Recorder.app"
APPEX="$APP/Contents/PlugIns/MIDI Tape Recorder Plugin.appex"

if [ "$1" != "--no-build" ]; then
  echo "building into $DD"
  ( cd "$ROOT" && xcodebuild build -scheme "MIDI Recorder" -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath "$DD" > "$WORK/build.log" 2>&1 ) || { grep -E "error:" "$WORK/build.log" | head; exit 1; }
  grep -q "BUILD SUCCEEDED" "$WORK/build.log" || { tail -5 "$WORK/build.log"; exit 1; }
fi

osascript -e 'tell application "MIDI Tape Recorder" to quit' 2>/dev/null || true; sleep 2
pkill -f "receivemidi dev" 2>/dev/null || true
if ! pgrep -f "routemidi vin Drive1" > /dev/null; then
  nohup routemidi vin Drive1 vout Src1 vin Drive2 vout Src2 vin Drive3 vout Src3 vin Drive4 vout Src4 > "$WORK/routes.log" 2>&1 &
  sleep 2
fi

# the virtual sources get new unique IDs each time the routes are created
P=/Users/$USER/Library/Containers/com.uwyn.MidiTapeRecorder/Data/Library/Preferences/com.uwyn.MidiTapeRecorder
i=0; for u in $(python3 "$HERE/midiuids.py" | grep -E "^\s+Src[1-4] " | sed 's/.*uid=//'); do defaults write $P midi.input.track.$i -int $u; i=$((i+1)); done
[ $i = 4 ] || { echo "expected 4 Src ports, found $i"; exit 1; }

pluginkit -a "$APPEX"; killall -9 AudioComponentRegistrar 2>/dev/null || true; sleep 2
if ioreg -n Root -d1 -a | grep -q CGSSessionScreenIsLocked; then echo "screen is locked: an app launched now has dead menus"; exit 1; fi
open "$APP"; sleep 10
HOST=$(pgrep -f "Debug-maccatalyst/MIDI Tape Recorder.app/Contents/MacOS/MIDI Tape Recorder$") || { echo "app not running"; exit 1; }
( echo "process attach -p $HOST"; echo "script lldb.debugger.SetAsync(False)"; echo "expr -l objc++ -O -- (id)[(id)[[UIApplication sharedApplication] windows] valueForKey:@\"rootViewController\"]"; echo "detach"; echo "quit" ) | lldb 2>&1 | grep -o "HostViewController: 0x[0-9a-f]*" | head -1 | sed 's/.*: //' > host_vc_addr.txt
[ -s host_vc_addr.txt ] || { echo "could not read the host view controller address"; exit 1; }

osascript "$HERE/ax_paths.applescript" > ax_paths.txt || { cat ax_paths.txt; exit 1; }
[ "$(grep -c '|' ax_paths.txt)" = 15 ] || { echo "expected 15 buttons, got:"; cat ax_paths.txt; exit 1; }
python3 "$HERE/gen_ax_state.py" ax_paths.txt ax_state.applescript
PLAY=$(grep '^play|' ax_paths.txt | cut -d'|' -f2); PARENT=${PLAY#UI element 2 of }; echo "UI element 1 of ${PARENT#UI element 2 of }" > ax_routing.txt
echo "ready: $(osascript ax_state.applescript)"
