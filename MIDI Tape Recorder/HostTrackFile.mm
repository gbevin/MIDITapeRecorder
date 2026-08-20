//
//  HostTrackFile.mm
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "HostTrackFile.h"

#include <vector>

#include "Constants.h"
#include "MidiFileConverter.h"
#include "RecordedTrackDict.h"

// the plugin serializes each track in fullState as a dictionary whose keys and
// blob layout are defined in RecordedTrackDict.h. we read and write that exact
// representation so the plugin restores it natively.

@implementation HostTrackFile

+ (NSData*)midiFileFromFullState:(NSDictionary*)fullState tempo:(double)tempo {
    std::vector<midifile::Track> tracks;

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        NSDictionary* recorder = [fullState objectForKey:recordedTrackStateKey(t)];
        if (![recorder isKindOfClass:[NSDictionary class]] || !recordedTrackDictIsCompatible(recorder)) {
            continue;
        }
        const RecordedMidiMessage* messages = nullptr;
        NSUInteger count = 0;
        if (!recordedTrackBlobGetMessages([recorder objectForKey:kRecordedTrackKeyRecorded], messages, count)) {
            continue;
        }

        midifile::Track track;
        track.messages.assign(messages, messages + count);

        id duration = [recorder objectForKey:kRecordedTrackKeyDuration];
        track.durationBeats = [duration isKindOfClass:[NSNumber class]] ? [duration doubleValue] : 0.0;

        tracks.push_back(std::move(track));
    }

    if (tracks.empty()) {
        return nil;
    }
    return midifile::writeFile(tracks, tempo);
}

+ (NSDictionary*)fullStateByImporting:(NSData*)midiFile intoFullState:(NSDictionary*)fullState {
    uint16_t division = 0;
    NSArray<NSData*>* chunks = midifile::trackChunks(midiFile, division);
    if (chunks.count == 0) {
        return nil;
    }

    // parse note-bearing chunks (skipping conductor/meta-only) into track blobs
    NSMutableArray<NSDictionary*>* imported = [NSMutableArray array];
    for (NSData* chunk in chunks) {
        if ((int)imported.count >= MIDI_TRACKS) {
            break;
        }
        midifile::Track track;
        if (!midifile::parseTrackChunk(chunk, division, track)) {
            continue;
        }
        NSMutableData* blob = [NSMutableData new];
        recordedTrackBlobAppendMessages(blob, track.messages.data(), track.messages.size());
        [imported addObject:@{ kRecordedTrackKeyRecorded: blob,
                               kRecordedTrackKeyDuration: @(track.durationBeats),
                               kRecordedTrackKeyFormat: @(kRecordedTrackFormatVersion) }];
    }

    // a valid file with no note content still imports: it clears every track,
    // consistent with the plugin's own import behavior
    NSMutableDictionary* newState = fullState ? [fullState mutableCopy] : [NSMutableDictionary new];
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (t < (int)imported.count) {
            newState[recordedTrackStateKey(t)] = imported[t];
        }
        else {
            // replacing "all tracks" means clearing the ones the file didn't fill
            newState[recordedTrackStateKey(t)] = @{};
        }
    }
    return newState;
}

@end
