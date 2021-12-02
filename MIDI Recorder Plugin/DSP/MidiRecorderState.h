//
//  MidiRecorderState.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <atomic>

#include "Constants.h"
#include "MidiTrackState.h"
#include "TPCircularBuffer.h"

struct MidiRecorderState {
    MidiRecorderState() {}
    MidiRecorderState(const MidiRecorderState&) = delete;
    MidiRecorderState& operator= (const MidiRecorderState&) = delete;
    
    MidiTrackState track[MIDI_TRACKS];

    std::atomic<int32_t> scheduledStopAndRewind  { false };

    TPCircularBuffer midiBuffer;
    
    double transportStartMachSeconds    { 0.0 };
    double playStartSampleSeconds       { 0.0 };
    double playDurationSeconds          { 0.0 };
};
