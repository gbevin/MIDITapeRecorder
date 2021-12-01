//
//  MidiRecorder.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import <Foundation/Foundation.h>

#import "AudioUnitGUIState.h"

@interface MidiRecorder : NSObject

@property(nonatomic) BOOL record;

- (instancetype)init  __attribute__((unavailable("init not available")));
- (instancetype)initWithOrdinal:(int)ordinal;

- (void)recordMidiMessage:(QueuedMidiMessage&)message;

- (void)ping;

- (NSData*)recorded;

- (double_t)duration;
- (uint32_t)count;
- (NSData*)preview;

@end
