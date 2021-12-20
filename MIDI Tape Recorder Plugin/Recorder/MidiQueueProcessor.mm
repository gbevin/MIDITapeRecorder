//
//  MidiQueueProcessor.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiQueueProcessor.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "MidiHelper.h"

#import "MidiTrackRecorder.h"
#import "MidiRecorderState.h"

#define DEBUG_MIDI_INPUT 0

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
        
#if DEBUG_MIDI_INPUT
        if (message.length > 0) {
            [self logMidiMessage:message];
        }
#endif
        
        if (_state) {
            for (int t = 0; t < MIDI_TRACKS; ++t) {
                if (message.length == 0) {
                    [_recorder[t] ping:message.timeSampleSeconds];
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

- (void)logMidiMessage:(QueuedMidiMessage&)message {
    uint8_t status = message.data[0] & 0xf0;
    uint8_t channel = message.data[0] & 0x0f;
    uint8_t data1 = message.data[1];
    uint8_t data2 = message.data[2];
    
    if (message.length == 2) {
        NSLog(@"IN  %f %d : %d - %2s [%3s %3s    ]",
              message.timeSampleSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String);
    }
    else {
        NSLog(@"IN  %f %d : %d - %2s [%3s %3s %3s]",
              message.timeSampleSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String,
              [NSString stringWithFormat:@"%d", data2].UTF8String);
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
    NSMutableData* data = [NSMutableData new];

    BOOL needs_byte_swap = needsMidiByteSwap();
    
    // we know we're using ASCII character, so UTF-8 will only use those characters
    [data appendBytes:[@"MThd" UTF8String] length:4];
    
    uint32_t file_header_length = 6;
    if (needs_byte_swap) file_header_length = CFSwapInt32(file_header_length);
    [data appendBytes:&file_header_length length:4];
    
    uint16_t file_header_format = 1;
    if (needs_byte_swap) file_header_format = CFSwapInt16(file_header_format);
    [data appendBytes:&file_header_format length:2];
    
    uint16_t file_header_ntrks = ntrks;
    if (needs_byte_swap) file_header_ntrks = CFSwapInt16(file_header_ntrks);
    [data appendBytes:&file_header_ntrks length:2];
    
    // number of ticks per quarter note
    int32_t beat_ticks = MIDI_BEAT_TICKS;
    uint16_t file_header_division = needs_byte_swap ? CFSwapInt16(beat_ticks) : beat_ticks;
    [data appendBytes:&file_header_division length:2];

    return data;
}

- (void)midiFileToRecordedTrack:(NSData*)data ordinal:(int)ordinal {
    if (data == nil || data.length == 0 ||
        ordinal < -1 || ordinal >= MIDI_TRACKS) {
        return;
    }

    BOOL needs_byte_swap = needsMidiByteSwap();

    // validate the file header and MIDI file type,
    // also obtain the division to evaluate the track event deltas
    if (data.length < 14) {
        return;
    }
    char file_type_bytes[5] = { 0, 0, 0, 0, 0 };
    [data getBytes:(void*)file_type_bytes range:NSMakeRange(0, 4)];
    if (![[NSString stringWithUTF8String:file_type_bytes] isEqualToString:@"MThd"]) {
        return;
    }
    
    uint32_t file_header_length;
    [data getBytes:(void*)&file_header_length range:NSMakeRange(4, 4)];
    if (needs_byte_swap) file_header_length = CFSwapInt32(file_header_length);
    if (file_header_length != 6) {
        return;
    }

    uint16_t file_header_format;
    [data getBytes:(void*)&file_header_format range:NSMakeRange(8, 2)];
    if (needs_byte_swap) file_header_format = CFSwapInt16(file_header_format);
    if (file_header_format != 0 && file_header_format != 1) {
        return;
    }

    uint16_t file_header_ntrks;
    [data getBytes:(void*)&file_header_ntrks range:NSMakeRange(10, 2)];
    if (needs_byte_swap) file_header_ntrks = CFSwapInt16(file_header_ntrks);
    if (file_header_ntrks < 1) {
        return;
    }

    uint16_t file_header_division;
    [data getBytes:(void*)&file_header_division range:NSMakeRange(12, 2)];
    if (needs_byte_swap) file_header_division = CFSwapInt16(file_header_division);
    if ((file_header_division & 0x8000) != 0) {
        return;
    }
    
    // validate at least one track header
    
    if (data.length < 22) {
        return;
    }

    int data_index = 14;

    int imported_ordinal = 0;
    int imported_tracks = 0;
    if (ordinal != -1) {
        file_header_ntrks = 1;
        imported_ordinal = ordinal;
    }
    
    while (imported_ordinal < 4 && imported_tracks < file_header_ntrks) {
        char track_type_bytes[5] = { 0, 0, 0, 0, 0 };
        [data getBytes:(void*)track_type_bytes range:NSMakeRange(data_index, 4)];
        data_index += 4;
        if (![[NSString stringWithUTF8String:track_type_bytes] isEqualToString:@"MTrk"]) {
            return;
        }
        
        uint32_t track_header_length;
        [data getBytes:(void*)&track_header_length range:NSMakeRange(data_index, 4)];
        data_index += 4;
        if (needs_byte_swap) track_header_length = CFSwapInt32(track_header_length);
        if (track_header_length == 0) {
            return;
        }

        // process the track events
        
        NSData* track = nil;
        @try {
            track = [data subdataWithRange:NSMakeRange(data_index, track_header_length)];
        }
        @catch (id e) {
            return;
        }
        
        [_recorder[imported_ordinal] midiTrackChunkToRecorded:track division:file_header_division];
        
        imported_ordinal += 1;
        imported_tracks += 1;
        
        data_index += track_header_length;
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
