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
    return _beats.size();
}

RecordedDataVector& MidiRecordedData::beatData(int beat) {
    return _beats[beat];
}

void MidiRecordedData::trimDuration() {
    if (_hasMessages) {
        _duration = ceil(_lastBeatOffset);
    }
}

bool MidiRecordedData::empty() {
    return !_hasMessages;
}

RecordedBeatVector& MidiRecordedData::getBeats() {
    return _beats;
}

double MidiRecordedData::getStart() const {
    return _start;
}

double MidiRecordedData::getDuration() const {
    return _duration;
}

void MidiRecordedData::setStartIfNeeded(double beats) {
    if (_start < 0) {
        _start = beats;
    }
}

void MidiRecordedData::increaseDuration(double duration) {
    _duration  = std::max(_duration, duration);
}

void MidiRecordedData::applyOverdubInfo(const MidiRecordedData& overdub) {
    _hasMessages = _hasMessages | overdub._hasMessages;
    _start = std::min(_start, overdub._start);
    _lastBeatOffset = std::max(_lastBeatOffset, overdub._lastBeatOffset);
    _duration = std::max(_duration, overdub._duration);
}

void MidiRecordedData::populateUpToBeat(int beat) {
    while (beat >= _beats.size()) {
        _beats.push_back(RecordedDataVector());
    }
}

void MidiRecordedData::addMessageToBeat(RecordedMidiMessage& message) {
    int beat = std::max(0, (int)message.offsetBeats);
    populateUpToBeat(beat);
    
    _beats[beat].push_back(message);
    
    _hasMessages = true;
    _lastBeatOffset = message.offsetBeats;
    increaseDuration(message.offsetBeats);
}
