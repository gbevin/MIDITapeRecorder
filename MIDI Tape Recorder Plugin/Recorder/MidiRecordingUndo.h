//
//  MidiRecordingUndo.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

@protocol MidiRecordingUndoDelegate <NSObject>

- (NSDictionary*)recordedStateForTrack:(int)track;
- (void)registerUndoRestoreForTrack:(int)track withState:(NSDictionary*)state;

@end

// Holds each recording track's pre-take state so that a take undoes as a whole,
// however many passes, punch ranges or loop cycles it ended up spanning.
@interface MidiRecordingUndo : NSObject

@property (nonatomic, weak) id<MidiRecordingUndoDelegate> delegate;
@property (nonatomic, readonly) BOOL takeInProgress;

- (void)beginTake;
- (void)captureTrack:(int)track;
- (void)recaptureTrack:(int)track;
- (void)discardTrack:(int)track;
- (void)finishTrack:(int)track changedContent:(BOOL)changedContent;
- (void)endTake;

@end
