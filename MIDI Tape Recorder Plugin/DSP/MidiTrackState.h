//
//  MidiTrackState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <atomic>
#include <vector>

#include "MPEState.h"
#include "Types.h"

struct MidiTrackState {
    MidiTrackState() {};
    MidiTrackState(const MidiTrackState&) = delete;
    MidiTrackState& operator= (const MidiTrackState&) = delete;
    
    std::atomic<int32_t> sourceCable    { 0 };
    std::atomic<bool> activityInput     { false };
    std::atomic<bool> activityOutput    { false };
    std::atomic<bool> recordEnabled     { false };
    std::atomic<bool> monitorEnabled    { false };
    std::atomic<bool> muteEnabled       { false };
    std::atomic<int32_t> recording      { 0 };

    MPEState mpeState;
    
    RecordedData        recordedMessages    { nullptr };
    RecordedBookmarks   recordedBeatToIndex { nullptr };
    RecordedPreview     recordedPreview     { nullptr };
    
    std::atomic<uint64_t>   recordedLength      { 0 };
    std::atomic<double>     recordedDuration    { 0.0 };
};
