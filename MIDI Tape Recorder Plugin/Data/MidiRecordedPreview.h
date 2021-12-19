//
//  MidiRecordedPreview.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/13/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <vector>

#include "PreviewPixelData.h"
#include "RecordedMidiMessage.h"

typedef std::vector<PreviewPixelData> RecordedPreviewVector;

class RecordedMidiMessage;

class MidiRecordedPreview {
public:
    MidiRecordedPreview();
    MidiRecordedPreview(const MidiRecordedPreview&) = delete;
    MidiRecordedPreview& operator= (const MidiRecordedPreview&) = delete;

    bool hasStarted() const;
    int getStartPixel() const;
    RecordedPreviewVector& getPixels();
    
    void setStartIfNeeded(double beats);

    void applyOverdubInfo(const MidiRecordedPreview& overdub);

    void updateWithOffsetBeats(double offsetBeats);
    void updateWithMessage(RecordedMidiMessage& message);
    
private:
    int _startPixel               { -1 };
    RecordedPreviewVector _pixels { };
};
