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

typedef void (^HostParamChange)(uint64_t address, float value);

struct MidiRecorderState {
    MidiRecorderState() {}
    MidiRecorderState(const MidiRecorderState&) = delete;
    MidiRecorderState& operator= (const MidiRecorderState&) = delete;
    
    HostParamChange hostParamChange { nullptr };

    MidiTrackState track[MIDI_TRACKS];

    std::atomic<bool> repeat                    { false };
    std::atomic<bool> sendMpeConfigOnPlay       { true };
    std::atomic<bool> displayMpeConfigDetails   { false };
    std::atomic<bool> autoTrimRecordings        { true };

    std::atomic<double> tempo            { 120.0 };
    std::atomic<double> currentBeatPos   { 0.0 };
    std::atomic<double> secondsToBeats   { 2.0 };
    std::atomic<double> beatsToSeconds   { 0.5 };

    std::atomic<int32_t> scheduledRewind                        { false };
    std::atomic<int32_t> scheduledPlay                          { false };
    std::atomic<int32_t> scheduledStop                          { false };
    std::atomic<int32_t> scheduledStopAndRewind                 { false };
    std::atomic<int32_t> scheduledBeginRecording[MIDI_TRACKS]   { false, false, false, false };
    std::atomic<int32_t> scheduledEndRecording[MIDI_TRACKS]     { false, false, false, false };
    std::atomic<int32_t> scheduledNotesOff[MIDI_TRACKS]         { false, false, false, false };
    std::atomic<int32_t> scheduledInvalidate[MIDI_TRACKS]       { false, false, false, false };
    std::atomic<int32_t> scheduledReachEnd                      { false };
    std::atomic<int32_t> scheduledSendMCM[MIDI_TRACKS]          { false, false, false, false };

    std::atomic<int32_t> scheduledUIPlay                        { false };
    std::atomic<int32_t> scheduledUIStop                        { false };
    std::atomic<int32_t> scheduledUIStopAndRewind               { false };

    TPCircularBuffer midiBuffer;
    
    double transportStartSampleSeconds  { 0.0 };
    double playDurationBeats            { 0.0 };
};
