//
//  MidiRecorderState.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/18/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#include "MidiRecorderState.h"

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
