//
//  AudioUnitGUIState.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 11/28/21.
//

#pragma once

#import "TPCircularBuffer.h"

struct AudioUnitGUIState {
    float midiActivityInput[8] = { 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f };
    float midiActivityOutput[8] = { 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f };
    
    TPCircularBuffer midiBuffer;
};

struct QueuedMidiMessage {
    Float64 timestampSeconds;
    uint8_t cable;
    uint16_t length;
    uint8_t data[3];
};
