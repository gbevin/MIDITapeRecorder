//
//  MidiRecorderDelegate.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include <memory>
#include <vector>

class RecordedMidiMessage;

@class MidiRecorder;

@protocol MidiRecorderDelegate <NSObject>

- (void)startRecord;
- (void)finishRecording:(int)ordinal
                   data:(std::unique_ptr<std::vector<RecordedMidiMessage>>)data
            beatToIndex:(std::unique_ptr<std::vector<int>>)beatToIndex
               duration:(double)duration;
- (void)invalidateRecording:(int)ordinal;

@end
