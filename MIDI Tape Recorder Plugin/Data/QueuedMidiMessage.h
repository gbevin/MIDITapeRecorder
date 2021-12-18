//
//  QueuedMidiMessage.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

struct QueuedMidiMessage {
    QueuedMidiMessage() {
        cable = 0;
        length = 0;
    }
    QueuedMidiMessage(const QueuedMidiMessage&) = delete;
    QueuedMidiMessage& operator= (const QueuedMidiMessage&) = delete;
    
    double timeSampleSeconds    { 0.0 };
    uint8_t data[3]             { 0, 0, 0 };
    
    uint8_t cable:4;
    uint8_t length:4;
};

static const int32_t QUEUED_MSG_SIZE = sizeof(QueuedMidiMessage);
