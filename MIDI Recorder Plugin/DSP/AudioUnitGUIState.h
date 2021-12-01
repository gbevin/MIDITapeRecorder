//
//  AudioUnitGUIState.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 11/28/21.
//

#pragma once

#include <atomic>

#include "TPCircularBuffer.h"

struct QueuedMidiMessage {
    double timestampSeconds;
    uint8_t cable;
    uint16_t length;
    uint8_t data[3];
};

struct AudioUnitGUIState {
    float midiActivityInput[4] = { 0.f, 0.f, 0.f, 0.f };
    float midiActivityOutput[4] = { 0.f, 0.f, 0.f, 0.f };
    
    std::atomic<const QueuedMidiMessage*>   recordedBytes1      { nullptr };
    std::atomic<uint64_t>                   recordedLength1     { 0 };
    std::atomic<uint64_t>                   playCounter1        { 0 };

    std::atomic<int32_t> scheduledStop  { false };

    TPCircularBuffer midiBuffer;
};
