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
    std::atomic<double> secondsToBeats   { 2.0 };
    std::atomic<double> beatsToSeconds   { 0.5 };
    
    std::atomic<double> maxDuration { 0.0 };

    std::atomic<double> transportStartSampleSeconds  { 0.0 };
    std::atomic<bool> startPositionSet               { false };
    std::atomic<double> startPositionBeats           { 0.0 };
    std::atomic<bool> stopPositionSet                { false };
    std::atomic<double> stopPositionBeats            { 0.0 };
    std::atomic<double> playPositionBeats            { 0.0 };

    std::atomic<bool> scheduledRewind                        { false };
    std::atomic<bool> scheduledPlay                          { false };
    std::atomic<bool> scheduledStop                          { false };
    std::atomic<bool> scheduledStopAndRewind                 { false };
    std::atomic<bool> scheduledBeginRecording[MIDI_TRACKS]   { false, false, false, false };
    std::atomic<bool> scheduledEndRecording[MIDI_TRACKS]     { false, false, false, false };
    std::atomic<bool> scheduledNotesOff[MIDI_TRACKS]         { false, false, false, false };
    std::atomic<bool> scheduledInvalidate[MIDI_TRACKS]       { false, false, false, false };
    std::atomic<bool> scheduledReachEnd                      { false };
    std::atomic<bool> scheduledSendMCM[MIDI_TRACKS]          { false, false, false, false };

    std::atomic<bool> scheduledUIPlay                        { false };
    std::atomic<bool> scheduledUIStop                        { false };
    std::atomic<bool> scheduledUIStopAndRewind               { false };
    std::atomic<bool> scheduledUIMpeConfigChange             { false };

    TPCircularBuffer midiBuffer;
};
