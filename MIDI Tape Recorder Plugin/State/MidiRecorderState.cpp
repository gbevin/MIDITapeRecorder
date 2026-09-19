//
//  MidiRecorderState.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/18/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#include "MidiRecorderState.h"

#include <algorithm>

// moves the markers into the timeline that cropping to the current crop range
// produces. the crop range becomes the whole session, while the punch range is
// carried across where it still overlaps and reset only when it falls outside.
void MidiRecorderState::cropPositions() {
    const double crop_start = startPositionBeats.load();
    const double crop_stop = stopPositionBeats.load();
    const double duration = std::max(crop_stop - crop_start, 0.0);

    const double punch_in = punchInPositionBeats.load();
    const double punch_out = punchOutPositionBeats.load();
    const bool punch_overlaps = (punch_out > crop_start && punch_in < crop_stop);

    playPositionBeats = 0.0;

    startPositionSet.clear();
    startPositionBeats = 0.0;
    stopPositionSet.clear();
    stopPositionBeats = duration;

    if (punch_overlaps) {
        punchInPositionBeats = std::min(std::max(punch_in - crop_start, 0.0), duration);
        punchOutPositionBeats = std::min(std::max(punch_out - crop_start, 0.0), duration);
    }
    else {
        punchInPositionSet.clear();
        punchInPositionBeats = 0.0;
        punchOutPositionSet.clear();
        punchOutPositionBeats = duration;
    }
}

bool MidiRecorderState::inactivePunchInOut() {
    return punchInOut.test() &&
        (playPositionBeats < punchInPositionBeats.load() ||
         playPositionBeats > punchOutPositionBeats.load());
}

bool MidiRecorderState::activePunchInOut() {
    return punchInOut.test() &&
        playPositionBeats >= punchInPositionBeats.load() &&
        playPositionBeats <= punchOutPositionBeats.load();
}
