//
//  QueuedMidiMessage.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
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
    double offsetBeats          { 0.0 };
    // The render-thread playhead position captured when this message was queued,
    // so the consumer thread doesn't have to read live (later, possibly
    // different-tempo) state to anchor a recording.
    double playPositionBeats    { 0.0 };
    bool hasBeatTime            { false };
    uint8_t data[3]             { 0, 0, 0 };
    
    uint8_t cable:4;
    uint8_t length:4;
};

const int32_t QUEUED_MSG_SIZE = sizeof(QueuedMidiMessage);
