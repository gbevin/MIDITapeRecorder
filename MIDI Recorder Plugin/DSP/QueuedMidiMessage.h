//
//  QueuedMidiMessage.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

struct QueuedMidiMessage {
    QueuedMidiMessage() {}
    QueuedMidiMessage(const QueuedMidiMessage&) = delete;
    QueuedMidiMessage& operator= (const QueuedMidiMessage&) = delete;
    
    double timestampSeconds { 0.0 };
    uint8_t cable           { 0 };
    uint16_t length         { 0 };
    uint8_t data[3]         { 0, 0, 0};
};

static const int32_t MSG_SIZE = sizeof(QueuedMidiMessage);
