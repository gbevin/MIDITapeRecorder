//
//  NoteTracker.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/18/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "NoteTracker.h"

const int8_t NOTE_STATE_NONE = -0x80;

NoteTracker::NoteTracker() {
    for (int ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (int n = 0; n < MIDI_NOTES; ++n) {
            _activeNotes[ch][n] = NOTE_STATE_NONE;
        }
    }
}

void NoteTracker::trackNotesForMessage(const RecordedMidiMessage& message) {
    int status = message.data[0];
    int type = status & 0xf0;
    int chan = (status & 0x0f);
    int val = message.data[2];
    if (type == MIDI_NOTE_OFF ||
        (type == MIDI_NOTE_ON && val == 0)) {
        if (_activeNotes[chan][message.data[1]] == NOTE_STATE_NONE) {
            _activeNotes[chan][message.data[1]] = -val;
        }
        else if (_activeNotes[chan][message.data[1]] > 0) {
            _activeNotes[chan][message.data[1]] = NOTE_STATE_NONE;
        }
    }
    else if (type == MIDI_NOTE_ON) {
        if (_activeNotes[chan][message.data[1]] == NOTE_STATE_NONE) {
            _activeNotes[chan][message.data[1]] = val;
        }
        else if (_activeNotes[chan][message.data[1]] <= 0) {
            _activeNotes[chan][message.data[1]] = NOTE_STATE_NONE;
        }
    }
}

std::vector<NoteOnMessage> NoteTracker::allNoteOnMessages() {
    std::vector<NoteOnMessage> result;
    
    for (uint8_t ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (uint8_t n = 0; n < MIDI_NOTES; ++n) {
            int8_t state = _activeNotes[ch][n];
            if (_activeNotes[ch][n] > 0) {
                result.push_back(NoteOnMessage(ch, n, state));
            }
        }
    }

    return result;
}

std::vector<NoteOffMessage> NoteTracker::allNoteOffMessages() {
    std::vector<NoteOffMessage> result;
    
    for (uint8_t ch = 0; ch < MIDI_CHANNELS; ++ch) {
        for (uint8_t n = 0; n < MIDI_NOTES; ++n) {
            int8_t state = _activeNotes[ch][n];
            if (_activeNotes[ch][n] != NOTE_STATE_NONE && _activeNotes[ch][n] <= 0) {
                result.push_back(NoteOffMessage(ch, n, -state));
            }
        }
    }

    return result;
}
