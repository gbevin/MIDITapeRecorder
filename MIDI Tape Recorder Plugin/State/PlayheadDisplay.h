//
//  PlayheadDisplay.h
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <algorithm>

#include "MidiRecorderState.h"

// only write the clamped position back while the transport is stopped: while it
// runs the render thread owns the playhead and stamps recordings from it, and the
// max duration trails the playhead by a buffer, so clamping would slow recordings
inline double syncDisplayPlayhead(MidiRecorderState& state) {
    double play_position = std::min(state.playPositionBeats.load(), state.maxDuration.load());
    if (!state.playActive.test()) {
        state.playPositionBeats = play_position;
    }
    return play_position;
}
