//
//  RecordedTrackDict.h
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <Foundation/Foundation.h>

#include "RecordedMidiMessage.h"

// The wire format for a track's recorded content, shared between the plugin
// (fullState get/set in MidiTrackRecorder and AudioUnitViewController) and the
// standalone host (session documents and .mid export/import in HostTrackFile).
// Everything that reads or writes these dictionaries goes through this header,
// so there is exactly one definition of the keys and the blob layout.
//
// Each track lives in fullState under "Recorder<n>" as a dictionary:
//   Recorded : NSData, a raw array of RecordedMidiMessage structs
//   Duration : NSNumber (double), the track duration in beats
//   MPE      : NSDictionary, the detected MPE configuration
//   Format   : NSNumber (int), wire format version (absent means version 1)

static NSString* const kRecordedTrackKeyRecorded = @"Recorded";
static NSString* const kRecordedTrackKeyDuration = @"Duration";
static NSString* const kRecordedTrackKeyMPE      = @"MPE";
static NSString* const kRecordedTrackKeyFormat   = @"Format";

// the current wire format version; bump this together with a migration path
// whenever the blob layout or the dictionary shape changes
static const int kRecordedTrackFormatVersion = 1;

// the fullState entry name for a track's dictionary
static inline NSString* recordedTrackStateKey(int track) {
    return [NSString stringWithFormat:@"Recorder%d", track];
}

#ifdef __cplusplus

// the "Recorded" blob is a raw memory image of RecordedMidiMessage structs, so
// its layout IS the file format of saved sessions and plugin state. this pins
// the layout: if the struct changes, this fails to compile, and the change has
// to come with a format version bump and a migration for existing content.
static_assert(sizeof(RecordedMidiMessage) == 16,
              "RecordedMidiMessage layout is serialized raw into sessions and fullState; "
              "changing it requires bumping kRecordedTrackFormatVersion and migrating");

// whether a track dictionary uses a wire format this build can read
static inline BOOL recordedTrackDictIsCompatible(NSDictionary* dict) {
    id format = [dict objectForKey:kRecordedTrackKeyFormat];
    if (format == nil) {
        // written before the version key existed: version 1
        return YES;
    }
    return [format isKindOfClass:[NSNumber class]] && [format intValue] <= kRecordedTrackFormatVersion;
}

// validated view over a track's "Recorded" blob; returns NO when the data is
// missing, not a whole number of messages, or empty
static inline BOOL recordedTrackBlobGetMessages(NSData* blob,
                                                const RecordedMidiMessage*& outMessages,
                                                NSUInteger& outCount) {
    if (![blob isKindOfClass:[NSData class]]
            || blob.length == 0
            || blob.length % sizeof(RecordedMidiMessage) != 0) {
        return NO;
    }
    outMessages = (const RecordedMidiMessage*)blob.bytes;
    outCount = blob.length / sizeof(RecordedMidiMessage);
    return YES;
}

// appends messages to a "Recorded" blob under construction
static inline void recordedTrackBlobAppendMessages(NSMutableData* blob,
                                                   const RecordedMidiMessage* messages,
                                                   NSUInteger count) {
    [blob appendBytes:messages length:count * sizeof(RecordedMidiMessage)];
}

#endif  // __cplusplus
