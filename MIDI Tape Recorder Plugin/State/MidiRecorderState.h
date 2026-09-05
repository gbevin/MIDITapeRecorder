//
//  MidiRecorderState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
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

    std::atomic_flag rewindTrigger      { false };
    std::atomic_flag playActive         { false };
    std::atomic_flag recordArmed        { false };
    std::atomic_flag repeatEnabled      { false };
    std::atomic_flag clearAllTrigger    { false };
    std::atomic_flag undoTrigger        { false };
    std::atomic_flag redoTrigger        { false };
    std::atomic_flag undoAvailable      { false };
    std::atomic_flag redoAvailable      { false };
    std::atomic_flag clearUndoHistoryTrigger { false };

    std::atomic_flag grid       { false };
    std::atomic_flag chase      { true };
    std::atomic_flag punchInOut { false };

    std::atomic_flag displayMpeConfigDetails    { false };
    std::atomic_flag showToolTips               { true };
    std::atomic_flag sendMpeConfigOnPlay        { true };
    std::atomic_flag followHostTransport        { true };
    std::atomic_flag waitForNextHostBeatToPlay  { false };
    std::atomic_flag autoTrimRecordings         { true };
    std::atomic_flag autoRewindAfterRecording   { true };
    // when set, we keep looping and overdubbing each pass instead of punching
    // out at the end of the loop (opt-in, off by default)
    std::atomic_flag loopRecord                 { false };

    std::atomic<double> tempo           { 120.0 };
    std::atomic<double> secondsToBeats  { 2.0 };
    std::atomic<double> beatsToSeconds  { 0.5 };
    
    std::atomic_flag repeatActive   { false };

    std::atomic<double> maxDuration { 0.0 };

    std::atomic_flag startPositionSet               { false };
    std::atomic_flag stopPositionSet                { false };
    std::atomic_flag punchInPositionSet             { false };
    std::atomic_flag punchOutPositionSet            { false };
    std::atomic<double> transportStartSampleSeconds { 0.0 };
    std::atomic<double> startPositionBeats          { 0.0 };
    std::atomic<double> stopPositionBeats           { 0.0 };
    std::atomic<double> playPositionBeats           { 0.0 };
    std::atomic<double> punchInPositionBeats        { 0.0 };
    std::atomic<double> punchOutPositionBeats       { 0.0 };

    std::atomic_flag processedRewind                        { true };
    std::atomic_flag processedPlay                          { true };
    std::atomic_flag processedStop                          { true };
    std::atomic_flag processedStopAndRewind                 { true };
    std::atomic_flag processedRecordArmed                   { true };
    std::atomic_flag processedActivateRepeat                { true };
    std::atomic_flag processedDeactivateRepeat              { true };
    std::atomic_flag processedBeginRecording[MIDI_TRACKS]   { true, true, true, true };
    std::atomic_flag processedEndRecording[MIDI_TRACKS]     { true, true, true, true };
    std::atomic_flag processedBlendRecording[MIDI_TRACKS]   { true, true, true, true };
    // loop-record cycle capture: the kernel sets this at the loop wrap, and the
    // recorder acts on it at the wrap point in its message stream (the first
    // message that jumps back to the loop start begins the new pass)
    std::atomic_flag processedCaptureRecording[MIDI_TRACKS]  { true, true, true, true };
    std::atomic_flag processedImport[MIDI_TRACKS]           { true, true, true, true };
    std::atomic_flag processedCropAll                       { true };
    std::atomic_flag processedNotesOff[MIDI_TRACKS]         { true, true, true, true };
    std::atomic_flag processedInvalidate[MIDI_TRACKS]       { true, true, true, true };
    std::atomic_flag processedClearAllPostInvalidate        { true };
    std::atomic_flag processedReachEnd                      { true };
    std::atomic_flag processedSendMCM[MIDI_TRACKS]          { true, true, true, true };
    std::atomic_flag processedResetRecording[MIDI_TRACKS]   { true, true, true, true };

    std::atomic_flag processedUIRewind                      { true };
    std::atomic_flag processedUIPlay                        { true };
    std::atomic_flag processedUIStop                        { true };
    std::atomic_flag processedUIStopAndRewind               { true };
    std::atomic_flag processedUIMpeConfigChange             { true };
    std::atomic_flag processedUIEndRecord                   { true };
    std::atomic_flag processedUIRebuildPreview[MIDI_TRACKS] { true, true, true, true };
    std::atomic_flag processedUIClearAllPostInvalidate      { true };

    TPCircularBuffer midiBuffer;
    // messages the render thread couldn't queue because the recorder fell behind
    std::atomic<uint32_t> midiQueueDropped { 0 };
    
    bool inactivePunchInOut();
    bool activePunchInOut();
};
