//
//  MidiTrackState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <atomic>

#include "MidiRecordedData.h"
#include "MidiRecordedPreview.h"
#include "MPEState.h"

struct MidiTrackState {
    MidiTrackState() {};
    MidiTrackState(const MidiTrackState&) = delete;
    MidiTrackState& operator= (const MidiTrackState&) = delete;
    
    std::atomic<int32_t> sourceCable    { 0 };
    
    std::atomic_flag processedActivityInput  { true };
    std::atomic_flag processedActivityOutput { true };
    
    std::atomic_flag recordEnabled      { false };
    std::atomic_flag monitorEnabled     { false };
    std::atomic_flag muteEnabled        { false };
    std::atomic_flag recording          { false };
    std::atomic_flag hasRecordedEvents  { false };

    MPEState mpeState;
    
    std::unique_ptr<MidiRecordedData> recordedData       { nullptr };
    std::unique_ptr<MidiRecordedPreview> recordedPreview { nullptr };
    
    std::unique_ptr<MidiRecordedData> pendingRecordedData       { nullptr };
    std::unique_ptr<MidiRecordedPreview> pendingRecordedPreview { nullptr };
};
