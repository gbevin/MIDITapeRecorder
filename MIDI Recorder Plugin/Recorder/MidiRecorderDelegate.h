//
//  MidiRecorderDelegate.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

class QueuedMidiMessage;

@class MidiRecorder;

@protocol MidiRecorderDelegate <NSObject>

- (void)startRecord:(int)ordinal;
- (void)finishRecording:(int)ordinal data:(const QueuedMidiMessage*)data count:(uint32_t)count;
- (void)invalidateRecording:(int)ordinal;

@end
