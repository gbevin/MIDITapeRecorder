//
//  MidiRecorderDelegate.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include <memory>

class MidiRecordedData;
class MidiRecordedPreview;
class RecordedMidiMessage;

@class MidiRecorder;

@protocol MidiRecorderDelegate <NSObject>

- (void)startRecord;
- (void)finishRecording:(int)ordinal
                   data:(std::unique_ptr<MidiRecordedData>)data
                preview:(std::shared_ptr<MidiRecordedPreview>)preview;
- (void)prepareRecording:(int)ordinal;
- (void)invalidateRecording:(int)ordinal;

@end
