//
//  MidiPreviewProvider.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/15/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include "PreviewPixelData.h"

class MidiPreviewProvider {
public:
    virtual unsigned long pixelCount() = 0;
    virtual PreviewPixelData& pixelData(int pixel) = 0;
};
