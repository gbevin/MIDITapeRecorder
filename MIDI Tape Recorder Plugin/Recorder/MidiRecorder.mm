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
#include "HostTime.h"
#include "MidiRecorderState.h"
#include "RecordedMidiMessage.h"

@implementation MidiRecorder {
    dispatch_queue_t _dispatchQueue;
    
    MidiRecorderState* _state;

    NSMutableData* _recording;
    NSMutableData* _recordingPreview;
    double _recordingDurationSeconds;
    double _recordingFirstMessageTime;
    uint32_t _recordingCount;
    
    NSData* _recorded;
    NSData* _recordedPreview;
    double _recordedDurationSeconds;
    uint32_t _recordedCount;
}

- (instancetype)initWithOrdinal:(int)ordinal {
    self = [super init];
    
    if (self) {
        _ordinal = ordinal;
        _dispatchQueue = dispatch_queue_create([NSString stringWithFormat:@"com.uwyn.midirecorder.Recording%d", ordinal].UTF8String, DISPATCH_QUEUE_CONCURRENT);
        
        _state = nil;
        
        _recordingFirstMessageTime = 0.0;

        _recording = [NSMutableData new];
        _recordingPreview = [NSMutableData new];
        _recordingDurationSeconds = 0.0;
        _recordingCount = 0;
        
        _recorded = nil;
        _recordedPreview = nil;
        _recordedDurationSeconds = 0.0;
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
            _recordedDurationSeconds = _recordingDurationSeconds;
            _recordedCount = _recordingCount;

            // then re-initialize the recording for the next time
            _recordingFirstMessageTime = 0.0;

            _recording = [NSMutableData new];
            _recordingPreview = [NSMutableData new];
            _recordingDurationSeconds = 0.0;
            _recordingCount = 0;
            
            if (_delegate) {
                [_delegate finishRecording:_ordinal data:(const RecordedMidiMessage*)_recorded.bytes count:_recordedCount duration:_recordedDurationSeconds];
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
                @"Duration" : @(_recordedDurationSeconds),
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
        _recordedDurationSeconds = 0.0;
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
            _recordedDurationSeconds = [duration doubleValue];
        }
        
        id count = [dict objectForKey:@"Count"];
        if (count) {
            _recordedCount = [count intValue];
        }
        
        if (_delegate) {
            [_delegate finishRecording:_ordinal data:(const RecordedMidiMessage*)_recorded.bytes count:_recordedCount duration:_recordedDurationSeconds];
        }
    });
}

- (void)writeMidiVarLen:(NSMutableData*)track value:(uint32_t)value {
    uint32_t buffer = 0;
    buffer = value & 0x7f;
    while ((value >>= 7) > 0) {
        buffer <<= 8;
        buffer |= 0x80;
        buffer += (value & 0x7f);
    }
    while (YES) {
        uint8_t b = buffer & 0xff;
        [track appendBytes:&b length:1];
        if (buffer & 0x80) {
            buffer >>= 8;
        }
        else {
            break;
        }
    }
}

- (NSData*)recordedAsMidiFile {
    NSMutableData* data = [NSMutableData new];

    BOOL needs_byte_swap = NO;
    if (CFByteOrderGetCurrent() == CFByteOrderLittleEndian) {
        needs_byte_swap = YES;
    }
    
    // we know we're using ASCII character, so UTF-8 will only use those characters
    [data appendBytes:[@"MThd" UTF8String] length:4];
    
    uint32_t file_header_length = needs_byte_swap ? CFSwapInt32(6) : 6;
    [data appendBytes:&file_header_length length:4];
    
    uint16_t file_header_format = needs_byte_swap ? CFSwapInt16(1) : 1;
    [data appendBytes:&file_header_format length:2];
    
    uint16_t file_header_ntrks = needs_byte_swap ? CFSwapInt16(1) : 1;
    [data appendBytes:&file_header_ntrks length:2];
    
    double bpm = 120.0;
    // get as close a millisecond ticks as possible
    double beat_seconds = 60.0 / bpm;
    double beat_milliseconds = 1000.0 * beat_seconds;
    // we can't have more than 0x7fff ticks
    int32_t beat_ticks = MIN(beat_milliseconds, 0x7fff);
    
    // number of ticks per quarter note
    uint16_t file_header_division = needs_byte_swap ? CFSwapInt16(beat_ticks) : beat_ticks;
    [data appendBytes:&file_header_division length:2];
    
    // we know we're using ASCII character, so UTF-8 will only use those characters
    [data appendBytes:[@"MTrk" UTF8String] length:4];
    
    // accumulate the track data in a seperate object so that
    // we can provide the length before adding its data
    NSMutableData* track = [NSMutableData new];

    // add tempo to track
    [self writeMidiVarLen:track value:0];
    // we can't have more than 0xffffff microseconds per beat
    int32_t beat_micros = MIN(1000000.0 * beat_seconds, 0xffffff);
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
        int64_t offset_ticks = int64_t(((message.offsetSeconds * bpm) / 60.0) * beat_ticks);
        uint32_t delta_ticks = uint32_t(offset_ticks - last_offset_ticks);
        [self writeMidiVarLen:track value:delta_ticks];
        for (int d = 0; d < message.length; ++d) {
            [track appendBytes:&message.data[d] length:1];
        }
        
        last_offset_ticks = offset_ticks;
    }

    uint32_t track_header_length = needs_byte_swap ? CFSwapInt32((uint32_t)track.length) : (uint32_t)track.length;
    [data appendBytes:&track_header_length length:4];
    
    [data appendData:track];

    return data;
}

#pragma mark Recording

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    double now_mach = HOST_TIME.currentMachTimeInSeconds();
    
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (!_record || _recording == nil) {
            return;
        }

        // auto start the recording on the first received message
        // if the recording hasn't started yet
        if (_recordingCount == 0 && _state->transportStartMachSeconds == 0.0) {
            if (_delegate) {
                _state->transportStartMachSeconds = now_mach;
                _state->playDurationSeconds = 0;
                [_delegate startRecord];
            }
        }

        // keep track of the time of the first message so that the offset of all messages
        // can be calculated off of this
        // if the recording of this track started later than the others, compensate that
        // with an additional offset to the time of the first message
        if (_recordingCount == 0) {
            _recordingFirstMessageTime = message.timeSampleSeconds - (now_mach - _state->transportStartMachSeconds);
        }
        
        // add message to the recording
        RecordedMidiMessage recorded_message;
        recorded_message.offsetSeconds = message.timeSampleSeconds - _recordingFirstMessageTime;
        recorded_message.length = message.length;
        recorded_message.data[0] = message.data[0];
        recorded_message.data[1] = message.data[1];
        recorded_message.data[2] = message.data[2];
        [_recording appendBytes:&recorded_message length:RECORDED_MSG_SIZE];
        _recordingDurationSeconds = HOST_TIME.currentMachTimeInSeconds() - _state->transportStartMachSeconds;
        _recordingCount += 1;
        
        // update the preview
        int32_t pixel = int32_t(recorded_message.offsetSeconds * PIXELS_PER_SECOND + 0.5);
        if (pixel >= _recordingPreview.length) {
            [_recordingPreview setLength:pixel + 1];
        }
        uint8_t* preview = (uint8_t*)_recordingPreview.mutableBytes;
        if (preview[pixel] < MAX_PREVIEW_EVENTS) {
            preview[pixel] += 1;
        }
    });
}

- (void)clear {
    _record = NO;

    _recordingFirstMessageTime = 0.0;

    _recording = [NSMutableData new];
    _recordingPreview = [NSMutableData new];
    _recordingDurationSeconds = 0.0;
    _recordingCount = 0;

    _recorded = nil;
    _recordedPreview = nil;
    _recordedDurationSeconds = 0.0;
    _recordedCount = 0;
    
    if (_delegate) {
        [_delegate invalidateRecording:_ordinal];
    }
}

- (void)ping {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_state->transportStartMachSeconds == 0.0) {
                _recordingDurationSeconds = 0.0;
            }
            else {
                _recordingDurationSeconds = HOST_TIME.currentMachTimeInSeconds() - _state->transportStartMachSeconds;
            }
        }
    });
}

#pragma mark Getters and Setter

- (void)setState:(MidiRecorderState*)state {
    _state = state;
}

- (double)duration {
    __block double duration = 0.0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_record == YES) {
            duration = _recordingDurationSeconds;
        }
        else {
            duration = _recordedDurationSeconds;
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
