# MIDI Tape Recorder

Created by Geert Bevin.

This work is freely distributed under the Creative Commons Attribution 4.0 International, an approved Free Culture License.

If you want to support my efforts, please consider donating through:
http://uwyn.com/donate

## Community

Join the Forums: https://forum.uwyn.com

Chat on Discord: https://discord.gg/g5nddMbx2H

## Description

MIDI Tape Recorder takes a radically different approach towards MIDI recording. It runs both as an open source Audio Unit v3 plugin inside your favorite host and as a standalone app on iPhone, iPad, and Mac.

MIDI messages are recorded and played back with the same accuracy and precision as audio recordings. Most modern DAWs, even at their highest resolution, still change the timing of MIDI messages to accommodate for their editing features. These changes impact the playback of your performance as MIDI messages get reordered and delayed, causing changes in how they influence sound, sometimes in very significant ways.

MIDI Tape Recorder records your performance exactly as you play it, just like an audio recorder, accurately reproducing every nuance of your performance.

<a href="https://www.youtube.com/watch?v=UfpEnpGqwn0" target="_blank"><img src="https://i.ytimg.com/vi/UfpEnpGqwn0/maxresdefault.jpg" alt="Intro and Tutorial Video" width="640" height="360" border="0" /></a>

MIDI Tape Recorder purposefully has no MIDI note editing, no quantization, no individual CC tweaking, nothing that you wouldn't do with audio. Instead, very expressive and ultra-dense MIDI streams are perfectly stored and reproduced. MIDI Tape Recorder excels at capturing and playing back expressive performances with MPE controllers and MPE MIDI plugins.

The controls are purposefully simple and intuitive, similar to a traditional four-track audio recorder, making it fun to record, play back and loop your MIDI performance. Even when recording non-MPE MIDI, MIDI Tape Recorder makes it easy to stay in the flow and be creative without being interrupted by the technical nature of most DAWs.

As a standalone app, MIDI Tape Recorder runs on its own with CoreMIDI input and output, routing your performance to any of your MIDI apps, synths, and hardware. Sessions are autosaved and can be saved, opened, and shared as documents, and recording keeps running in the background and with the screen locked, so you never lose a take.

MIDI Tape Recorder makes no sound on its own: as a plugin it records inside your host, and as a standalone app it routes MIDI to your instruments.

Features:

* Runs as an AUv3 plugin or as a standalone app on iPhone, iPad, and Mac
* Four independent tracks for recording MIDI channel voice messages
* Sample accurate MIDI recording and playback
* Real-time display of active recorded notes and other received messages
* MPE support
* Continuous loop recording to overdub across every loop cycle
* Multi-level undo and redo
* Overdub recording, with punch in and punch out for automated regional overdubbing
* CoreMIDI input and output routing in the standalone app
* Autosaved, shareable session documents in the standalone app
* Background and screen-locked recording in the standalone app
* Automated storage and recall of all recordings inside the AUv3 host project
* MIDI file import and export for the project or each individual track
* Repeated playback with start and stop locators
* AUv3 parameters for all controls
* Snap to beat option for positioning playhead and start/stop locators
* Per-track MPE configuration message (MCM) detection and envoy at start of play or when pressing the track's MPE button
* Host transport and host tempo sync
* Clear all recordings or a single track, and crop the session to a new duration
* Fully resizable UI with per-track MIDI input and output activity indicators
* Optional tool tips for every operation
* Optional per-track record enable, input monitoring, and mute
* Four virtual MIDI cable inputs if the AUv3 host supports it, with optional routing of the first cable to all tracks
* Support for AUv3 user presets if the host supports it
