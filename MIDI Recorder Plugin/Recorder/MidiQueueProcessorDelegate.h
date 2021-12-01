//
//  MidiQueueProcessorDelegate.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//

@protocol MidiQueueProcessorDelegate <NSObject>

- (void)invalidateRecorded;
- (void)playRecorded:(const void*)buffer length:(uint64_t)length;
- (void)stopRecorded;

@end
