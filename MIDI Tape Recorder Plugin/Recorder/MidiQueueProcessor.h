//
//  MidiQueueProcessor.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

#include "TPCircularBuffer.h"

@class MidiRecorder;
class MidiRecorderState;

@interface MidiQueueProcessor : NSObject

- (void)processMidiQueue:(TPCircularBuffer*)queue;

- (void)setState:(MidiRecorderState*)state;
- (MidiRecorder*)recorder:(int)ordinal;

- (NSData*)recordedTracksAsMidiFile;
- (NSData*)recordedTrackAsMidiFile:(int)ordinal;
- (void)midiFileToRecordedTrack:(NSData*)data ordinal:(int)ordinal;

@end
