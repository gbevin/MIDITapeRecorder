//
//  MidiRecordedPreview.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/13/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "MidiRecordedPreview.h"

#include "Constants.h"
#include "RecordedMidiMessage.h"

MidiRecordedPreview::MidiRecordedPreview() {
};
    
void MidiRecordedPreview::updateWithOffsetBeats(double offsetBeats) {
    int32_t pixel = std::max(0, int32_t(offsetBeats * PIXELS_PER_BEAT + 0.5));
    
    PreviewPixelData last_pixel_data;
    if (pixel > 0 && !pixels.empty()) {
        last_pixel_data = pixels.back();
    }
    if (pixel >= pixels.size()) {
        last_pixel_data.events = 0;
        while (pixels.size() <= pixel) {
            pixels.push_back(last_pixel_data);
        }
    }
}

void MidiRecordedPreview::updateWithMessage(RecordedMidiMessage& message) {
    updateWithOffsetBeats(message.offsetBeats);
    
    int32_t pixel = std::max(0, int32_t(message.offsetBeats * PIXELS_PER_BEAT + 0.5));
    PreviewPixelData& pixel_data = pixels[pixel];

    // track the note and the events independently
    if (message.type == INTERNAL) {
        if (message.isOverdubStart() || message.isOverdubStop()) {
            pixel_data.notes = 0;
        }
    }
    else if (message.length == 3 &&
        ((message.data[0] & 0xf0) == 0x90 ||
         (message.data[0] & 0xf0) == 0x80)) {
        // note on
        if ((message.data[0] & 0xf0) == 0x90) {
            // note on with zero velocity == note off
            if (message.data[2] == 0) {
                if (pixel_data.notes > 0) {
                    pixel_data.notes -= 1;
                }
            }
            else {
                if (pixel_data.notes < 0x7f) {
                    pixel_data.notes += 1;
                }
            }
        }
        // note off
        else if ((message.data[0] & 0xf0) == 0x80) {
            if (pixel_data.notes > 0) {
                pixel_data.notes -= 1;
            }
        }
    }
    else if (pixel_data.events < 0xff) {
        pixel_data.events += 1;
    }
}
