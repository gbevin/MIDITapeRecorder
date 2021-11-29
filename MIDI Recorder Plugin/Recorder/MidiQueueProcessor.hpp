//
//  MidiQueueProcessor.hpp
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//

#import <Foundation/Foundation.h>

#import "AudioUnitGUIState.hpp"
#import "MidiQueueProcessorDelegate.hpp"

@interface MidiQueueProcessor : NSObject

@property id<MidiQueueProcessorDelegate> delegate;

@property(nonatomic) BOOL play;
@property(nonatomic) BOOL record;

- (void)processMidiQueue:(TPCircularBuffer*)queue;

- (uint32_t)recordedCount;


@end
