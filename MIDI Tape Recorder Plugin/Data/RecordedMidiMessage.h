//
//  RecordedMidiMessage.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

enum RecordedMidiMessageType {
    MIDI_1_0 = 0,
    INTERNAL = 1
};

struct RecordedMidiMessage {
    RecordedMidiMessage() {
        length = 0;
        type = MIDI_1_0;
    }
    
    double offsetBeats  { 0.0 };
    uint8_t data[3]     { 0, 0, 0 };
    
    uint8_t length:4;
    RecordedMidiMessageType type:4;
};

static const int32_t RECORDED_MSG_SIZE = sizeof(RecordedMidiMessage);
