//
//  MidiPreviewProvider.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/15/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#include "PreviewPixelData.h"

@protocol MidiPreviewProvider <NSObject>

- (unsigned long)previewPixelCount;
- (PreviewPixelData)previewPixelData:(int)pixel;
- (BOOL)refreshPreviewBeat:(int)beat;

@end
