//
//  MidiTrackState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <atomic>

#include "RecordedMidiMessage.h"

struct MidiTrackState {
    MidiTrackState() {};
    MidiTrackState(const MidiTrackState&) = delete;
    MidiTrackState& operator= (const MidiTrackState&) = delete;
    
    // using 32-bit variables ensures no partial reads or write,
    // nor cache inconsistancies amongst threads or core
    int32_t sourceCable     = 0;
    float activityInput     = 0.f;
    float activityOutput    = 0.f;
    int32_t recordEnabled   = false;
    int32_t monitorEnabled  = false;
    int32_t muteEnabled     = false;
    int32_t recording       = 0;
    
    std::atomic<const RecordedMidiMessage*> recordedMessages = nullptr;
    std::atomic<uint64_t>                   recordedLength = 0;
    std::atomic<double>                     recordedDurationSeconds = 0.0;
    std::atomic<uint64_t>                   playCounter = 0;
};
