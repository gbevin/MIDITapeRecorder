//
//  MidiQueueProcessorDelegate.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

@class MidiRecorder;

@protocol MidiQueueProcessorDelegate <NSObject>

- (void)invalidateRecorded;
- (void)playRecorded:(MidiRecorder*)recorder;
- (void)stopRecorded;

@end
