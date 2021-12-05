//
//  RecordedMidiMessage.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

struct RecordedMidiMessage {
    RecordedMidiMessage() {}
    RecordedMidiMessage(const RecordedMidiMessage&) = delete;
    RecordedMidiMessage& operator= (const RecordedMidiMessage&) = delete;
    
    double offsetBeats  { 0.0 };
    uint16_t length     { 0 };
    uint8_t data[3]     { 0, 0, 0 };
};

static const int32_t RECORDED_MSG_SIZE = sizeof(RecordedMidiMessage);
