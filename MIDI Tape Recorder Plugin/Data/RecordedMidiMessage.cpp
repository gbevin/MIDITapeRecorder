//
//  RecordedMidiMessage.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/18/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "RecordedMidiMessage.h"

#include <iostream>
#include <iomanip>

RecordedMidiMessage::RecordedMidiMessage() {
    length = 0;
    type = MIDI_1_0;
}

bool RecordedMidiMessage::isOverdubStart() const {
    return type == INTERNAL && length == 1 && data[0] == OVERDUB_START_MESSAGE;
}

bool RecordedMidiMessage::isOverdubStop() const {
    return type == INTERNAL && length == 1 && data[0] == OVERDUB_STOP_MESSAGE;
}

RecordedMidiMessage RecordedMidiMessage::makeOverdubStartMessage(double offsetBeats) {
    RecordedMidiMessage msg;
    msg.offsetBeats = offsetBeats;
    msg.length = 1;
    msg.type = INTERNAL;
    msg.data[0] = OVERDUB_START_MESSAGE;
    return msg;
}

RecordedMidiMessage RecordedMidiMessage::makeOverdubStopMessage(double offsetBeats) {
    RecordedMidiMessage msg;
    msg.offsetBeats = offsetBeats;
    msg.length = 1;
    msg.type = INTERNAL;
    msg.data[0] = OVERDUB_STOP_MESSAGE;
    return msg;
}
