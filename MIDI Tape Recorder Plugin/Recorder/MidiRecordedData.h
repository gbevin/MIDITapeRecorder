//
//  MidiRecordedData.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/12/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <vector>

#include "RecordedMidiMessage.h"

/*
 Each beat has an index in the first vector, all the messages in that beat
 are sequentially added to the second vector inside their beat.
 This allows for fast access to messages in any beat with low CPU cost of replacing
 when overdubbing.
 */
typedef std::vector<RecordedMidiMessage> RecordedDataVector;
typedef std::vector<RecordedDataVector> RecordedBeatVector;

struct MidiRecordedData {
    MidiRecordedData();
    MidiRecordedData(const MidiRecordedData&) = delete;
    MidiRecordedData& operator= (const MidiRecordedData&) = delete;
    
    unsigned long beatCount();
    RecordedDataVector& beatData(int beat);
    void trimDuration();
    
    bool empty();
    
    /*
     Fill in any beats that might have been missed. We keep this continually updated
     in the ping method to progressively catch up and reduce the load when a message is actually processed.
     We exclude the current beat since that will be handled when there's an actual message to process.
     */
    void populateUpToBeat(int beat);
    
    /*
     While recording, we keep track of the position in the recording that the beginning of a beat
     corresponds to, this allows for fast scanning later during playback.
     */
    void addMessageToBeat(RecordedMidiMessage& message);
    
    RecordedBeatVector beats    { };
    bool hasMessages            { false };
    double lastBeatOffset       { 0.0 };
    double duration             { 0.0 };
};
