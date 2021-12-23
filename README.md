# MIDI Tape Recorder

Created by Geert Bevin.

This work is freely distributed under the Creative Commons Attribution 4.0 International, an approved Free Culture License.

If you want to support my efforts, please consider donating through:
http://uwyn.com/donate

## Description

MIDI Tape Recorder is an open source Audio Unit v3 plugin with an opinionated approach towards MIDI recording. Every message is captured and played back in a sample-accurate way, like you would record audio.

There is no MIDI note editing, no quantization, no individual CC tweaking, nothing that you wouldn't do with audio. Instead, very expressive and ultra-dense MIDI streams are perfectly stored and reproduced exactly as they were played. MIDI Tape Recorder excels at capturing and playing back expressive performances with MPE controllers and MPE MIDI plugins.

The controls are purposefully simple and intuitive, making it fun to record, play back and loop your MIDI performance.

MIDI Tape Recorder makes no sound on its own and requires an AUv3 host to function.

Features:

* Four independent tracks for recording MIDI channel voice messages
* Sample accurate MIDI recording and playback
* Real-time display of active recorded notes and other received messages
* MPE support
* Multi-level undo and redo
* Overdub recording
* Punch in and punch out recording for automated regional overdubbing
* Automated storage and recall of all recordings inside the AUv3 host project
* MIDI file import and export for the project or each individual track
* Repeated playback with start and stop locators
* AUv3 parameters for all controls
* Snap to beat option for positioning playhead and start/stop locators
* Detection of MPE configuration message (MCM) reception for each track
* Envoy of MCM at start of play or when pressing the track's MPE button
* Host transport and host tempo sync
* Clear all recordings or clear a single track
* Crop session to new duration
* Fully resizable UI
* Activity indicators for MIDI input and output on each track
* Optional tool tips for every operation
* Optional per-track record enable, input monitoring, and mute
* Four virtual MIDI cable inputs if the AUv3 host supports it
* Support for AUv3 user presets if the host supports it
* Optional routing of first virtual MIDI cable to all tracks