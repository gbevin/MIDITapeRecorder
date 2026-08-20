//
//  MidiQueueProcessor.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiQueueProcessor.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "Logging.h"
#include "MidiFileConverter.h"
#include "MidiHelper.h"

#import "MidiTrackRecorder.h"
#import "MidiRecorderState.h"

#define DEBUG_MIDI_QUEUE 0

@implementation MidiQueueProcessor {
    MidiRecorderState* _state;
    MidiTrackRecorder* _recorder[MIDI_TRACKS];
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _state = nullptr;
        
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            _recorder[t] = [[MidiTrackRecorder alloc] initWithOrdinal:t];
        }
    }
    
    return self;
}

#pragma mark Queue Processing

- (void)processMidiQueue:(TPCircularBuffer*)queue {
    uint32_t bufferedBytes;
    uint32_t availableBytes;
    void* bytes;
    
    bytes = TPCircularBufferTail(queue, &bufferedBytes);
    availableBytes = bufferedBytes;
    while (bytes && availableBytes >= QUEUED_MSG_SIZE && bufferedBytes >= QUEUED_MSG_SIZE) {
        QueuedMidiMessage message;
        memcpy(&message, bytes, QUEUED_MSG_SIZE);
        
#if DEBUG_MIDI_QUEUE
        if (message.length > 0) {
            logQueuedMidiMessage(@"QUE", message);
        }
#endif
        
        if (_state) {
            for (int t = 0; t < MIDI_TRACKS; ++t) {
                if (message.length == 0) {
                    [_recorder[t] ping:message];
                }
                else if (_state->track[t].sourceCable == message.cable) {
                    _state->track[t].processedActivityInput.clear();
                    [_recorder[t] recordMidiMessage:message];
                }
            }
        }

        TPCircularBufferConsume(queue, QUEUED_MSG_SIZE);
        bufferedBytes -= QUEUED_MSG_SIZE;
        bytes = TPCircularBufferTail(queue, &availableBytes);
    }
}

#pragma mark State

- (void)setState:(MidiRecorderState*)state {
    _state = state;

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        [_recorder[t] setState:state];
    }
}

#pragma mark MIDI files

- (NSData*)recordedTracksAsMidiFile {
    NSMutableData* data = [NSMutableData new];
    
    NSMutableData* tracks = [NSMutableData new];
    int tracks_count = 0;
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        NSData* track = [_recorder[t] recordedAsMidiTrackChunk];
        if (track != nil) {
            [tracks appendData:track];
            tracks_count += 1;
        }
    }
    
    [data appendData:[self recordedAsMidiFileChunk:tracks_count]];
    [data appendData:tracks];

    return data;
}

- (NSData*)recordedTrackAsMidiFile:(int)ordinal {
    if (ordinal < 0 || ordinal >= MIDI_TRACKS) {
        return nil;
    }
    
    NSMutableData* data = [NSMutableData new];
    
    NSData* track = [_recorder[ordinal] recordedAsMidiTrackChunk];

    [data appendData:[self recordedAsMidiFileChunk:track == nil ? 0 : 1]];
    
    if (track != nil) {
        // add the track
        [data appendData:track];
    }

    return data;
}

- (NSData*)recordedAsMidiFileChunk:(int)ntrks {
    return midifile::writeFileHeader(ntrks);
}

- (void)midiFileToRecordedTrack:(NSData*)data ordinal:(int)ordinal {
    if (data == nil || ordinal < -1 || ordinal >= MIDI_TRACKS) {
        return;
    }

    // validate the header and split the file into track chunk bodies
    uint16_t division = 0;
    NSArray<NSData*>* chunks = midifile::trackChunks(data, division);
    if (chunks.count == 0) {
        return;
    }

    // For a single-track import we fill the requested ordinal; for a full import
    // we fill recorder tracks 0..MIDI_TRACKS-1. Empty/meta-only chunks (such as a
    // format-1 conductor track) are skipped so that note content lands in order.
    int imported_ordinal = (ordinal != -1) ? ordinal : 0;
    int max_ordinal = (ordinal != -1) ? (ordinal + 1) : MIDI_TRACKS;

    for (NSData* chunk in chunks) {
        if (imported_ordinal >= max_ordinal) {
            break;
        }
        if ([_recorder[imported_ordinal] midiTrackChunkToRecorded:chunk division:division]) {
            imported_ordinal += 1;
        }
    }

    // a valid file with no note content for the destination still counts as an
    // import: the destination gets cleared rather than silently left alone, and
    // a full import likewise clears the tracks the file didn't fill
    for (int t = imported_ordinal; t < max_ordinal; ++t) {
        [_recorder[t] importEmptyTrack];
    }
}

#pragma mark Getters and Setter

- (MidiTrackRecorder*)recorder:(int)ordinal {
    if (ordinal < 0 || ordinal >= MIDI_TRACKS) {
        return nil;
    }
    
    return _recorder[ordinal];
}

@end
