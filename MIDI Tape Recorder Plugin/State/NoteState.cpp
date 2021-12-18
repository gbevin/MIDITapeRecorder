//
//  NoteState.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/16/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "NoteState.h"

NoteOnMessage::NoteOnMessage(uint8_t channel, uint8_t note, uint8_t velocity) {
    data[0] = MIDI_NOTE_ON | channel;
    data[1] = note;
    data[2] = velocity;
}

NoteOffMessage::NoteOffMessage(uint8_t channel, uint8_t note, uint8_t velocity) {
    data[0] = MIDI_NOTE_OFF | channel;
    data[1] = note;
    data[2] = velocity;
}

NoteState::NoteState() {
    for (int ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (int n = 0; n < MIDI_NOTES; ++n) {
            _activeNotes[ch][n] = false;
        }
    }
    
    _noteCount = 0;
}

void NoteState::trackNotesForMessage(const RecordedMidiMessage& message) {
    int status = message.data[0];
    int type = status & 0xf0;
    int chan = (status & 0x0f);
    int val = message.data[2];
    if (type == MIDI_NOTE_OFF ||
        (type == MIDI_NOTE_ON && val == 0)) {
        if (_activeNotes[chan][message.data[1]] == true &&
            _noteCount > 0) {
            _noteCount -= 1;
        }
        _activeNotes[chan][message.data[1]] = false;
    }
    else if (type == MIDI_NOTE_ON) {
        if (_activeNotes[chan][message.data[1]] == false) {
            _noteCount += 1;
        }
        _activeNotes[chan][message.data[1]] = true;
    }
}

bool NoteState::hasLingeringNotes() {
    return _noteCount > 0;
}

std::vector<NoteOffMessage> NoteState::turnOffAllNotesAndGenerateMessages() {
    std::vector<NoteOffMessage> result;
    
    if (_noteCount == 0) {
        return result;
    }

    for (uint8_t ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (uint8_t n = 0; n < MIDI_NOTES; ++n) {
            if (_activeNotes[ch][n]) {
                result.push_back(NoteOffMessage(ch, n, 0x40));
                _activeNotes[ch][n] = false;
            }
        }
    }
    _noteCount = 0;

    return result;
}
