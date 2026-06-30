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
#include "RecordedMidiMessage.h"

// the plugin serializes each track in fullState under "Recorder<n>" as a raw blob
// of RecordedMidiMessage structs ("Recorded") plus its "Duration" in beats. we read
// and write that exact representation so the plugin restores it natively.
static NSString* RecorderKey(int track) {
    return [NSString stringWithFormat:@"Recorder%d", track];
}

@implementation HostTrackFile

+ (NSData*)midiFileFromFullState:(NSDictionary*)fullState tempo:(double)tempo {
    std::vector<midifile::Track> tracks;

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        NSDictionary* recorder = [fullState objectForKey:RecorderKey(t)];
        if (![recorder isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSData* blob = [recorder objectForKey:@"Recorded"];
        if (![blob isKindOfClass:[NSData class]] || blob.length < sizeof(RecordedMidiMessage)) {
            continue;
        }

        midifile::Track track;
        const RecordedMidiMessage* messages = (const RecordedMidiMessage*)blob.bytes;
        NSUInteger count = blob.length / sizeof(RecordedMidiMessage);
        track.messages.assign(messages, messages + count);

        id duration = [recorder objectForKey:@"Duration"];
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
        NSData* blob = [NSData dataWithBytes:track.messages.data()
                                     length:track.messages.size() * sizeof(RecordedMidiMessage)];
        [imported addObject:@{ @"Recorded": blob, @"Duration": @(track.durationBeats) }];
    }
    if (imported.count == 0) {
        return nil;
    }

    NSMutableDictionary* newState = fullState ? [fullState mutableCopy] : [NSMutableDictionary new];
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (t < (int)imported.count) {
            newState[RecorderKey(t)] = imported[t];
        }
        else {
            // replacing "all tracks" means clearing the ones the file didn't fill
            newState[RecorderKey(t)] = @{};
        }
    }
    return newState;
}

@end
