//
//  MidiRecordingUndo.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecordingUndo.h"

@implementation MidiRecordingUndo {
    NSMutableDictionary<NSNumber*, NSDictionary*>* _snapshots;
}

- (BOOL)takeInProgress {
    return _snapshots != nil;
}

- (void)beginTake {
    _snapshots = [NSMutableDictionary dictionary];
}

// a track that starts recording mid-take needs its pre-take state captured too,
// and only the first capture of a take is the pre-take one
- (void)captureTrack:(int)track {
    if (_snapshots == nil || _snapshots[@(track)] != nil) {
        return;
    }

    NSDictionary* state = [_delegate recordedStateForTrack:track];
    if (state != nil) {
        _snapshots[@(track)] = state;
    }
}

// content that replaces the track wholesale while a take runs becomes the state the
// take started from, so undoing the take returns to it rather than reaching back past
// it to what the track held before
- (void)recaptureTrack:(int)track {
    if (_snapshots == nil) {
        return;
    }

    NSDictionary* state = [_delegate recordedStateForTrack:track];
    if (state != nil) {
        _snapshots[@(track)] = state;
    }
}

- (void)discardTrack:(int)track {
    [_snapshots removeObjectForKey:@(track)];
}

// a take that left the track as it found it needs no undo step, and without a
// pre-take state there is nothing to restore anyway: the track was cleared while the
// take ran, the clear registered its own undo step, and the discarded content must
// not come back through the take
- (void)finishTrack:(int)track changedContent:(BOOL)changedContent {
    NSDictionary* snapshot = _snapshots[@(track)];
    [_snapshots removeObjectForKey:@(track)];

    if (snapshot == nil || !changedContent) {
        return;
    }

    [_delegate registerUndoRestoreForTrack:track withState:snapshot];
}

- (void)endTake {
    _snapshots = nil;
}

@end
