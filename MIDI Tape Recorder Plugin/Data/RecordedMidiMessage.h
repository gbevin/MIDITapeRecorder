//
//  RecordedMidiMessage.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <cstdint>

enum RecordedMidiMessageType {
    MIDI_1_0 = 0,
    INTERNAL = 1
};

enum InternalMessageStatus {
    UNDEFINED_INTERNAL_MESSAGE = 0,
    OVERDUB_START_MESSAGE = 1,
    OVERDUB_STOP_MESSAGE = 2
};

struct RecordedMidiMessage {
    RecordedMidiMessage();
    
    double offsetBeats  { 0.0 };
    uint8_t data[3]     { 0, 0, 0 };
    
    uint8_t length:4;
    RecordedMidiMessageType type:4;
    
    bool isOverdubStart() const;
    bool isOverdubStop() const;

    static RecordedMidiMessage makeOverdubStartMessage(double offsetBeats);
    static RecordedMidiMessage makeOverdubStopMessage(double offsetBeats);
};
