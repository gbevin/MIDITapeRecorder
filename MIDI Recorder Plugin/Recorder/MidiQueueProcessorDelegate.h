//
//  MidiQueueProcessorDelegate.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

@protocol MidiQueueProcessorDelegate <NSObject>

- (void)invalidateRecorded;
- (void)playRecorded:(const void*)buffer length:(uint64_t)length;
- (void)stopRecorded;

@end
