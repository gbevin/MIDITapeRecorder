//
//  MidiRecordedData.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/12/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "MidiRecordedData.h"

#include <cmath>

MidiRecordedData::MidiRecordedData() {
};
    
unsigned long MidiRecordedData::beatCount() {
    return beats.size();
}

RecordedDataVector& MidiRecordedData::beatData(int beat) {
    return beats[beat];
}

void MidiRecordedData::trimDuration() {
    duration = ceil(lastBeatOffset);
}

bool MidiRecordedData::empty() {
    return !hasMessages;
}

void MidiRecordedData::populateUpToBeat(int beat) {
    while (beat > beats.size()) {
        beats.push_back(RecordedDataVector());
    }
}

void MidiRecordedData::addMessageToBeat(RecordedMidiMessage& message) {
    int beat = (int)message.offsetBeats;
    while (beat >= beats.size()) {
        beats.push_back(RecordedDataVector());
    }
    
    beats[beat].push_back(message);
    
    hasMessages = true;
    lastBeatOffset = message.offsetBeats;
    duration = message.offsetBeats;
}
