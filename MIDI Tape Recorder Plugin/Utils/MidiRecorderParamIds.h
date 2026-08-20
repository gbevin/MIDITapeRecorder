//
//  MidiRecorderParamIds.h
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <Foundation/Foundation.h>

// The AU parameter identifiers shared between the plugin (which registers the
// parameter tree) and the standalone host (which drives it by identifier).
// Both sides must use these constants: a mismatched identifier doesn't fail,
// it just returns a nil parameter and silently does nothing.

static NSString* const MTRParamIdPlay              = @"play";
static NSString* const MTRParamIdRecord            = @"record";
static NSString* const MTRParamIdRepeat            = @"repeat";
static NSString* const MTRParamIdRewind            = @"rewind";
static NSString* const MTRParamIdGrid              = @"grid";
static NSString* const MTRParamIdChase             = @"chase";
static NSString* const MTRParamIdPunchInOut        = @"punchInOut";
static NSString* const MTRParamIdClearAll          = @"clearAll";
static NSString* const MTRParamIdUndo              = @"undo";
static NSString* const MTRParamIdRedo              = @"redo";
static NSString* const MTRParamIdCanUndo           = @"canUndo";
static NSString* const MTRParamIdCanRedo           = @"canRedo";
static NSString* const MTRParamIdClearUndoHistory  = @"clearUndoHistory";

// per-track parameters; track numbers are 1-based in the identifiers
static inline NSString* MTRParamIdRecordTrack(int track) {
    return [NSString stringWithFormat:@"record%d", track];
}

static inline NSString* MTRParamIdMonitorTrack(int track) {
    return [NSString stringWithFormat:@"monitor%d", track];
}

static inline NSString* MTRParamIdMuteTrack(int track) {
    return [NSString stringWithFormat:@"mute%d", track];
}

static inline NSString* MTRParamIdClearTrack(int track) {
    return [NSString stringWithFormat:@"clear%d", track];
}
