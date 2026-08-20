//
//  MidiTrackRecorder.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
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
// Parses a Standard MIDI File track chunk into this track's recorded data.
// Returns YES if the chunk contained note/channel content that was imported, or
// NO for empty/meta-only chunks (e.g. a format-1 conductor track).
- (BOOL)midiTrackChunkToRecorded:(NSData*)track division:(uint16_t)division;
// clears the track's content through the regular import path, for imports whose
// source has no note content for this destination
- (void)importEmptyTrack;

- (void)setState:(MidiRecorderState*)state;
- (void)ping:(QueuedMidiMessage&)message;
- (void)recordMidiMessage:(QueuedMidiMessage&)message;
- (void)clear;
- (void)crop;

// hands off a final pass that had to wait for a racing loop-record blend to
// finish. call this regularly from the UI render loop, since no more MIDI
// messages come through the recorder once recording has stopped.
- (void)flushDeferredFinish;

- (double)activeDuration;

@end
