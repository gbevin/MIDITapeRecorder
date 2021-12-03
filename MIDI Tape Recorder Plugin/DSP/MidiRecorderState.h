//
//  MidiRecorderState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
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

    std::atomic<int32_t> scheduledRewind                        { false };
    std::atomic<int32_t> scheduledPlay                          { false };
    std::atomic<int32_t> scheduledStop                          { false };
    std::atomic<int32_t> scheduledStopAndRewind                 { false };
    std::atomic<int32_t> scheduledBeginRecording[MIDI_TRACKS]   { false, false, false, false };
    std::atomic<int32_t> scheduledEndRecording[MIDI_TRACKS]     { false, false, false, false };
    std::atomic<int32_t> scheduledNotesOff[MIDI_TRACKS]         { false, false, false, false };
    std::atomic<int32_t> scheduledReachEnd                      { false };
    
    std::atomic<int32_t> scheduledUIStopAndRewind               { false };

    TPCircularBuffer midiBuffer;
    
    double transportStartMachSeconds    { 0.0 };
    double playStartSampleSeconds       { 0.0 };
    double playDurationSeconds          { 0.0 };
};
