# End-to-end harness for the Mac Catalyst standalone

Drives the real app (Debug build, out-of-process plugin) with MIDI through RouteMIDI
virtual ports, the app's own menu commands and the host's parameter methods, and
verifies what plays back.

Requirements: `brew install sendmidi receivemidi routemidi`, the terminal granted
Accessibility and Screen Recording in System Settings > Privacy & Security, and the
screen unlocked when the app is launched (an app launched under lock has dead menus;
one launched before the lock keeps working, but the button state reads do not).
`caffeinate -d -i -u` keeps the auto-lock away during long runs.

```
Tests/E2E/e2e_setup.sh            # build, routes, track inputs, register, launch (add --no-build to reuse the build)
python3 Tests/E2E/scenarios.py    # A four-track take, B punch-in on the fly, C arm changes, D clear mid-take, G undo/redo
python3 Tests/E2E/arming_window.py  # bursts 0 to 80 ms after the Record parameter must all be recorded
Tests/E2E/e2e_teardown.sh
```

Every run prints `OK` or `MISMATCH` per check; `scenarios.py` ends with a `RESULTS` line.
Work files (build, captures `mt_*.txt`, cached accessibility paths) live in `Tests/E2E/.work`.

How it works and what to know when extending it:

- `hostlib.py` attaches lldb to the host process only, never to the plugin process
  (suspending the plugin hangs the host's menu dispatch). Parameter toggles are scheduled
  on the host's run loop and fire after lldb detaches; `state()` reads the live parameter
  values through `parameterIsOn:`, `ui()` reads the plugin buttons through accessibility.
- `arming_window.py` schedules the Record toggle at an absolute instant (an NSTimer fire
  date, so lldb's attach time does not matter) and spawns `sendmidi` at that instant plus
  the gap minus its spawn latency (`MTR_E2E_SPAWN_LATENCY`, about 90 ms on a loaded machine).
- With Repeat off the transport stops by itself at the session end; a stop click after
  that restarts playback, so the helpers check the live state before clicking.
- `sendmidi` spawns are slow, so scenario A compares playback spacing against the
  measured send times instead of the nominal sleeps.
- Scenario C and D document kernel behaviour rather than test a fix: a track armed
  mid-take does not record, disarming the track that started the take ends it, and a
  track cleared mid-take stays silent for the rest of the take.
