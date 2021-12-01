//
//  MidiQueueProcessor.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import <Foundation/Foundation.h>

#import "AudioUnitGUIState.h"
#import "MidiQueueProcessorDelegate.h"

@interface MidiQueueProcessor : NSObject

@property id<MidiQueueProcessorDelegate> delegate;

@property(nonatomic) BOOL play;
@property(nonatomic) BOOL record;

- (void)processMidiQueue:(TPCircularBuffer*)queue;

- (void)ping;

- (double_t)recordedTime;
- (uint32_t)recordedCount;
- (NSData*)recordedPreview;

@end
