//
//  NoteState.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/16/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "NoteState.h"

NoteOffMessage::NoteOffMessage(uint8_t channel, uint8_t note) {
    data[0] = MIDI_NOTE_OFF | channel;
    data[1] = note;
    data[2] = 0x07;
}

NoteState::NoteState() {
    for (int ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (int n = 0; n < MIDI_NOTES; ++n) {
            activeNotes[ch][n] = false;
        }
    }
    
    noteCount = 0;
}

void NoteState::trackNotesForMessage(const RecordedMidiMessage& message) {
    int status = message.data[0];
    int type = status & 0xf0;
    int chan = (status & 0x0f);
    int val = message.data[2];
    if (type == MIDI_NOTE_OFF ||
        (type == MIDI_NOTE_ON && val == 0)) {
        if (activeNotes[chan][message.data[1]] == true &&
            noteCount > 0) {
            noteCount -= 1;
        }
        activeNotes[chan][message.data[1]] = false;
    }
    else if (type == MIDI_NOTE_ON) {
        if (activeNotes[chan][message.data[1]] == false) {
            noteCount += 1;
        }
        activeNotes[chan][message.data[1]] = true;
    }
}

std::vector<NoteOffMessage> NoteState::turnOffAllNotesAndGenerateMessages() {
    std::vector<NoteOffMessage> result;
    
    if (noteCount == 0) {
        return result;
    }

    for (uint8_t ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (uint8_t n = 0; n < MIDI_NOTES; ++n) {
            if (activeNotes[ch][n]) {
                result.push_back(NoteOffMessage(ch, n));
                activeNotes[ch][n] = false;
            }
        }
    }
    noteCount = 0;

    return result;
}
