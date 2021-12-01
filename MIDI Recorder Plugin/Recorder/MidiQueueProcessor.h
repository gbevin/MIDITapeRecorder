//
//  MidiQueueProcessor.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import <Foundation/Foundation.h>

#include "TPCircularBuffer.h"

#import "MidiQueueProcessorDelegate.h"

@class MidiRecorder;

@interface MidiQueueProcessor : NSObject

@property id<MidiQueueProcessorDelegate> delegate;

@property(nonatomic) BOOL play;
@property(nonatomic) BOOL record;

- (void)processMidiQueue:(TPCircularBuffer*)queue;

- (void)ping;

- (MidiRecorder*)recorder:(int)ordinal;

@end
