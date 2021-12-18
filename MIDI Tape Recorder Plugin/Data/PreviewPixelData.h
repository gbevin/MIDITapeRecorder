//
//  PreviewPixelData.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/10/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

struct PreviewPixelData {
    PreviewPixelData() {
        notes = 0;
        recording = false;
    }
    
    uint8_t notes:7;
    bool recording:1;
    
    uint8_t events  { 0 };
};
