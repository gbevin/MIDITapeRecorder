//
//  MidiRecorder.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorder.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "MidiHelper.h"
#include "MidiRecorderState.h"
#include "RecordedMidiMessage.h"

@implementation MidiRecorder {
    dispatch_queue_t _dispatchQueue;
    
    MidiRecorderState* _state;

    NSMutableData* _recording;
    NSMutableData* _recordingPreview;
    double _recordingDurationBeats;
    uint32_t _recordingCount;
    
    NSData* _recorded;
    NSData* _recordedPreview;
    double _recordedDurationBeats;
    uint32_t _recordedCount;
}

- (instancetype)initWithOrdinal:(int)ordinal {
    self = [super init];
    
    if (self) {
        _ordinal = ordinal;
        _dispatchQueue = dispatch_queue_create([NSString stringWithFormat:@"com.uwyn.midirecorder.Recording%d", ordinal].UTF8String, DISPATCH_QUEUE_CONCURRENT);
        
        _state = nil;
        
        _recording = [NSMutableData new];
        _recordingPreview = [NSMutableData new];
        _recordingDurationBeats = 0.0;
        _recordingCount = 0;
        
        _recorded = nil;
        _recordedPreview = nil;
        _recordedDurationBeats = 0.0;
        _recordedCount = 0;
    }
    
    return self;
}

#pragma mark Transport

- (void)setRecord:(BOOL)record {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record == record) {
            return;
        }
        
        _record = record;
        
        if (record == NO) {
            // when recording is stopped, we move the recording data to the recorded data
            _recorded = _recording;
            _recordedPreview = _recordingPreview;
            if (_recordingCount == 0) {
                _recordedDurationBeats = 0.0;
            }
            else {
                _recordedDurationBeats = ceil(((const RecordedMidiMessage*)_recording.bytes)[_recordingCount-1].offsetBeats);
            }
            _recordedCount = _recordingCount;

            _recording = [NSMutableData new];
            _recordingPreview = [NSMutableData new];
            _recordingDurationBeats = 0.0;
            _recordingCount = 0;
            
            if (_delegate) {
                [_delegate finishRecording:_ordinal data:(const RecordedMidiMessage*)_recorded.bytes count:_recordedCount duration:_recordedDurationBeats];
            }
        }
        else {
            if (_delegate) {
                [_delegate invalidateRecording:_ordinal];
            }
        }
    });
}

#pragma mark State

- (NSDictionary*)recordedAsDict {
    __block NSDictionary* result;
    
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_recording == nil) {
            result = @{};
        }
        else {
            result = @{
                @"Recorded" : [NSData dataWithData:_recorded],
                @"Preview" : [NSData dataWithData:_recordedPreview],
                @"Duration" : @(_recordedDurationBeats),
                @"Count" : @(_recordedCount)
            };
        }
    });
    
    return result;
}

- (void)dictToRecorded:(NSDictionary*)dict {
    dispatch_barrier_sync(_dispatchQueue, ^{
        _recorded = nil;
        _recordedPreview = nil;
        _recordedDurationBeats = 0.0;
        _recordedCount = 0;
        
        id recorded = [dict objectForKey:@"Recorded"];
        if (recorded) {
            _recorded = recorded;
        }
        
        id preview = [dict objectForKey:@"Preview"];
        if (preview) {
            _recordedPreview = preview;
        }
        
        id duration = [dict objectForKey:@"Duration"];
        if (duration) {
            _recordedDurationBeats = ceil([duration doubleValue]);
        }
        
        id count = [dict objectForKey:@"Count"];
        if (count) {
            _recordedCount = [count intValue];
        }
        
        if (_delegate) {
            [_delegate finishRecording:_ordinal data:(const RecordedMidiMessage*)_recorded.bytes count:_recordedCount duration:_recordedDurationBeats];
        }
    });
}

#pragma mark MIDI files

- (NSData*)recordedAsMidiTrackChunk {
    if (_recordedCount == 0) {
        return nil;
    }

    // accumulate the track data in a seperate object so that
    // we can provide the length before adding its data
    NSMutableData* track = [NSMutableData new];

    // add tempo to track
    writeMidiVarLen(track, 0);
    // we can't have more than 0xffffff microseconds per beat
    int32_t beat_micros = MIN(1000000.0 * 60.0 / _state->tempo, 0xffffff);
    uint8_t meta_tempo[] = { 0xff, 0x51, 0x03 };
    [track appendBytes:&meta_tempo[0] length:3];
    uint8_t bm1 = (beat_micros >> 16) & 0xff;
    [track appendBytes:&bm1 length:1];
    uint8_t bm2 = (beat_micros >> 8) & 0xff;
    [track appendBytes:&bm2 length:1];
    uint8_t bm3 = beat_micros & 0xff;
    [track appendBytes:&bm3 length:1];

    // add midi events to track
    const RecordedMidiMessage* messages = (const RecordedMidiMessage*)_recorded.bytes;
    int64_t last_offset_ticks = 0;
    for (uint32_t i = 0; i < _recordedCount; ++i) {
        const RecordedMidiMessage& message = messages[i];
        int64_t offset_ticks = int64_t(message.offsetBeats * MIDI_BEAT_TICKS);
        uint32_t delta_ticks = uint32_t(offset_ticks - last_offset_ticks);
        writeMidiVarLen(track, delta_ticks);
        for (int d = 0; d < message.length; ++d) {
            [track appendBytes:&message.data[d] length:1];
        }
        
        last_offset_ticks = offset_ticks;
    }
    
    // add end of track meta event
    int64_t offset_ticks = int64_t(_recordedDurationBeats * MIDI_BEAT_TICKS);
    uint32_t delta_ticks = uint32_t(offset_ticks - last_offset_ticks);
    writeMidiVarLen(track, delta_ticks);
    uint8_t meta_end_of_track[] = { 0xff, 0x2f, 0x00 };
    [track appendBytes:&meta_end_of_track[0] length:3];
    
    // create the full track chunk, including the header
    NSMutableData* data = [NSMutableData new];

    // we know we're using ASCII character, so UTF-8 will only use those characters
    [data appendBytes:[@"MTrk" UTF8String] length:4];

    // track chunk length
    uint32_t track_header_length = needsMidiByteSwap() ? CFSwapInt32((uint32_t)track.length) : (uint32_t)track.length;
    [data appendBytes:&track_header_length length:4];
    
    // add the previously accumulated track events
    [data appendData:track];

    return data;
}

- (void)midiTrackChunkToRecorded:(NSData*)track division:(uint16_t)division{
    if (track == nil || track.length == 0) {
        return;
    }

    // prepare local data to accumulate into
    
    NSMutableData* recorded = [NSMutableData new];
    NSMutableData* recorded_preview = [NSMutableData new];
    double recorded_duration_beats = 0.0;
    uint32_t recorded_count = 0;

    // process the track events

    int64_t last_offset_ticks = 0;
    uint8_t running_status = 0;
    uint32_t i = 0;
    uint8_t* track_bytes = (uint8_t*)track.bytes;
    while (i < track.length) {
        // read variable length delta time
        uint32_t delta_ticks;
        i += readMidiVarLen(&track_bytes[i], delta_ticks);
        
        int64_t offset_ticks = last_offset_ticks + delta_ticks;
        double duration_beats = double(offset_ticks) / division;
        last_offset_ticks = offset_ticks;
        
        // handle event
        uint8_t event_identifier = track_bytes[i];
        i += 1;
        switch (event_identifier) {
            // sysex event
            case 0xf0:
            case 0xf7: {
                // capture the event length
                uint32_t length;
                i += readMidiVarLen(&track_bytes[i], length);
                // skip over the event data
                i += length;
                break;
            }
            // meta event
            case 0xff: {
                // skip over the event type
                i += 1;
                // capture the event length
                uint32_t length;
                i += readMidiVarLen(&track_bytes[i], length);
                // skip over the event data
                i += length;
                break;
            }
            // midi event
            default: {
                uint8_t d0 = event_identifier;
                // check for status byte
                if ((d0 & 0x80) != 0) {
                    running_status = d0;
                }
                // not a status byte, we'll reuse the previous one as running status
                else {
                    d0 = running_status;
                }
                
                RecordedMidiMessage msg;
                msg.offsetBeats = duration_beats;

                // get the data bytes based on the active state
                // one data byte
                if ((d0 & 0xf0) == 0xc0 || (d0 & 0xf0) == 0xd0) {
                    uint8_t d1 = track_bytes[i];
                    i += 1;
                    
                    msg.length = 2;
                    msg.data[0] = d0;
                    msg.data[1] = d1;
                    msg.data[2] = 0;
                }
                // two data bytes
                else {
                    uint8_t d1 = track_bytes[i];
                    i += 1;
                    uint8_t d2 = track_bytes[i];
                    i += 1;
                    
                    msg.length = 3;
                    msg.data[0] = d0;
                    msg.data[1] = d1;
                    msg.data[2] = d2;
                }
                
                [recorded appendBytes:&msg length:sizeof(RecordedMidiMessage)];
                recorded_count += 1;
                
                // update the preview
                [self updatePreview:recorded_preview withMessage:msg];

                break;
            }
        }
    }
    
    recorded_duration_beats = double(last_offset_ticks) / division;

    // transfer all the accumulated data to the active recorded data
    
    _recorded = recorded;
    _recordedPreview = recorded_preview;
    _recordedDurationBeats = ceil(recorded_duration_beats);
    _recordedCount = recorded_count;
    
    if (_delegate) {
        [_delegate finishRecording:_ordinal data:(const RecordedMidiMessage*)_recorded.bytes count:_recordedCount duration:_recordedDurationBeats];
    }
}

#pragma mark Recording

- (void)ping:(double)timeSampleSeconds {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_state->transportStartSampleSeconds == 0.0) {
                _recordingDurationBeats = 0.0;
            }
            else {
                _recordingDurationBeats = (timeSampleSeconds - _state->transportStartSampleSeconds) * _state->secondsToBeats;
                
                if (_recordingPreview && _recordingCount > 0) {
                    [self updatePreview:_recordingPreview withOffsetBeats:_recordingDurationBeats];
                }
            }
        }
    });
}

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (!_record || _recording == nil) {
            return;
        }

        // auto start the recording on the first received message
        // if the recording hasn't started yet
        if (_recordingCount == 0 && _state->transportStartSampleSeconds == 0.0) {
            if (_delegate) {
                _state->transportStartSampleSeconds = message.timeSampleSeconds;
                _state->playDurationBeats = 0.0;
                [_delegate startRecord];
            }
        }

        // add message to the recording
        RecordedMidiMessage recorded_message;
        double offset_seconds = message.timeSampleSeconds - _state->transportStartSampleSeconds;
        recorded_message.offsetBeats = offset_seconds * _state->secondsToBeats;
        recorded_message.length = message.length;
        recorded_message.data[0] = message.data[0];
        recorded_message.data[1] = message.data[1];
        recorded_message.data[2] = message.data[2];
        [_recording appendBytes:&recorded_message length:RECORDED_MSG_SIZE];
        _recordingDurationBeats = offset_seconds * _state->secondsToBeats;
        _recordingCount += 1;
        
        // update the preview
        [self updatePreview:_recordingPreview withMessage:recorded_message];
    });
}

- (void)updatePreview:(NSMutableData*)preview withOffsetBeats:(double)offsetBeats {
    int32_t pixel = int32_t(offsetBeats * PIXELS_PER_BEAT + 0.5);
    pixel *= 2;
    
    int8_t active_notes = 0;
    if (pixel > 0) {
        active_notes = ((int8_t*)preview.bytes)[preview.length-1];
    }
    if (pixel + 1 >= preview.length) {
        uint8_t zero = 0;
        while (preview.length < pixel + 2) {
            [preview appendBytes:&zero length:1];
            [preview appendBytes:&active_notes length:1];
        }
    }
}

- (void)updatePreview:(NSMutableData*)preview withMessage:(RecordedMidiMessage&)message {
    int32_t pixel = int32_t(message.offsetBeats * PIXELS_PER_BEAT + 0.5);
    pixel *= 2;
    
    [self updatePreview:preview withOffsetBeats:message.offsetBeats];
    
    uint8_t* preview_bytes = (uint8_t*)preview.mutableBytes;
    int8_t active_notes = preview_bytes[pixel + 1];

    // track the note and the events indepdently
    if (message.length == 3 &&
        ((message.data[0] & 0xf0) == 0x90 ||
         (message.data[0] & 0xf0) == 0x80)) {
        // note on
        if ((message.data[0] & 0xf0) == 0x90) {
            // note on with zero velocity == note off
            if (message.data[2] == 0) {
                active_notes -= 1;
            }
            else {
                active_notes += 1;
            }
        }
        // note off
        else if ((message.data[0] & 0xf0) == 0x80) {
            active_notes -= 1;
        }
    }
    else if (preview_bytes[pixel] < 0xff) {
        preview_bytes[pixel] += 1;
    }
    
    preview_bytes[pixel + 1] = active_notes;
}

- (void)clear {
    _record = NO;

    _recording = [NSMutableData new];
    _recordingPreview = [NSMutableData new];
    _recordingDurationBeats = 0.0;
    _recordingCount = 0;

    _recorded = nil;
    _recordedPreview = nil;
    _recordedDurationBeats = 0.0;
    _recordedCount = 0;
    
    if (_delegate) {
        [_delegate invalidateRecording:_ordinal];
    }
}

#pragma mark Getters and Setter

- (void)setState:(MidiRecorderState*)state {
    _state = state;
}

- (double)durationBeats {
    __block double duration = 0.0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_record == YES) {
            duration = _recordingDurationBeats;
        }
        else {
            duration = _recordedDurationBeats;
        }
    });
    
    return duration;
}

- (NSData*)preview {
    __block NSData* preview = nil;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_record == YES) {
            preview = _recordingPreview;
        }
        else {
            preview = _recordedPreview;
        }
    });
    
    return preview;
}

@end
