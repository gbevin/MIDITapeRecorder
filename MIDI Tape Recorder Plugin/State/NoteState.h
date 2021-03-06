//
//  NoteState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/16/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <cstdint>
#include <vector>

#include "Constants.h"
#include "RecordedMidiMessage.h"

struct NoteOnMessage {
    NoteOnMessage(uint8_t channel, uint8_t note, uint8_t velocity);
    uint8_t data[3];
};

struct NoteOffMessage {
    NoteOffMessage(uint8_t channel, uint8_t note, uint8_t velocity);
    uint8_t data[3];
};

class NoteState {
public:
    NoteState();
    NoteState(const NoteState&) = delete;
    NoteState& operator= (const NoteState&) = delete;
    
    bool hasLingeringNotes();
    void trackNotesForMessage(const RecordedMidiMessage& message);
    std::vector<NoteOffMessage> turnOffAllNotesAndGenerateMessages();
    
private:
    bool _activeNotes[MIDI_CHANNELS][MIDI_NOTES];
    uint32_t _noteCount;
};
