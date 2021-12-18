//
//  NoteTracker.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/18/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <cstdint>
#include <vector>

#include "Constants.h"
#include "NoteState.h"
#include "RecordedMidiMessage.h"

class NoteTracker {
public:
    NoteTracker();
    NoteTracker(const NoteTracker&) = delete;
    NoteTracker& operator= (const NoteTracker&) = delete;
    
    void trackNotesForMessage(const RecordedMidiMessage& message);

    std::vector<NoteOnMessage> allNoteOnMessages();
    std::vector<NoteOffMessage> allNoteOffMessages();

private:
    int8_t _activeNotes[MIDI_CHANNELS][MIDI_NOTES];
};
