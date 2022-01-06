//
//  MidiTrackRecorder.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

#include "QueuedMidiMessage.h"

#import "MidiPreviewProvider.h"
#import "MidiTrackRecorderDelegate.h"

class MidiRecorderState;

@interface MidiTrackRecorder : NSObject<MidiPreviewProvider>

@property(readonly) int ordinal;
@property(nonatomic) BOOL record;

@property id<MidiTrackRecorderDelegate> delegate;

- (instancetype)init  __attribute__((unavailable("init not available")));
- (instancetype)initWithOrdinal:(int)ordinal;

- (NSMutableDictionary*)recordedAsDict;
- (void)dictToRecorded:(NSDictionary*)dict;
- (NSData*)recordedAsMidiTrackChunk;
- (void)midiTrackChunkToRecorded:(NSData*)track division:(uint16_t)division;

- (void)setState:(MidiRecorderState*)state;
- (void)ping:(QueuedMidiMessage&)message;
- (void)recordMidiMessage:(QueuedMidiMessage&)message;
- (void)clear;
- (void)crop;

- (double)activeDuration;

@end
