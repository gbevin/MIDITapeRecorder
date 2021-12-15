//
//  MidiRecordedPreview.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/13/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <vector>

#include "MidiPreviewProvider.h"
#include "PreviewPixelData.h"

typedef std::vector<PreviewPixelData> RecordedPreviewVector;

class RecordedMidiMessage;

struct MidiRecordedPreview : public MidiPreviewProvider {
    MidiRecordedPreview();
    MidiRecordedPreview(const MidiRecordedPreview&) = delete;
    MidiRecordedPreview& operator= (const MidiRecordedPreview&) = delete;
    
    void updateWithOffsetBeats(double offsetBeats);
    void updateWithMessage(RecordedMidiMessage& message);
    
    unsigned long pixelCount() override;
    PreviewPixelData& pixelData(int pixel) override;

    RecordedPreviewVector pixels { };
};
