//
//  MidiRecorder.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import "MidiRecorder.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "HostTime.h"

@implementation MidiRecorder {
    int _ordinal;
    
    dispatch_queue_t _dispatchQueue;
    
    NSMutableData* _recording;
    NSMutableData* _recordingPreview;
    double _recordingStart;
    double _recordingDuration;
    double _recordingFirstMessageTime;
    uint32_t _recordingCount;
    
    NSData* _recorded;
    NSData* _recordedPreview;
    double _recordedDuration;
    uint32_t _recordedCount;
}

- (instancetype)initWithOrdinal:(int)ordinal {
    self = [super init];
    
    if (self) {
        _ordinal = ordinal;
        _dispatchQueue = dispatch_queue_create([NSString stringWithFormat:@"com.uwyn.midirecorder.Recording%d", ordinal].UTF8String, DISPATCH_QUEUE_CONCURRENT);
        
        _recordingStart = 0.0;
        _recordingFirstMessageTime = 0.0;

        _recording = [NSMutableData new];
        _recordingPreview = [NSMutableData new];
        _recordingDuration = 0.0;
        _recordingCount = 0;
        
        _recorded = nil;
        _recordedPreview = nil;
        _recordedDuration = 0.0;
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
            _recorded = _recording;
            _recordedPreview = _recordingPreview;
            _recordedDuration = _recordingDuration;
            _recordedCount = _recordingCount;

            _recordingStart = 0.0;
            _recordingFirstMessageTime = 0.0;

            _recording = [NSMutableData new];
            _recordingPreview = [NSMutableData new];
            _recordingDuration = 0.0;
            _recordingCount = 0;
        }
        else {
            _recorded = nil;
            _recordedPreview = nil;
            _recordedDuration = 0;
            _recordedCount = 0;
        }
    });
}

#pragma mark Recording

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_recordingCount == 0) {
                _recordingStart = HOST_TIME.currentHostTimeInSeconds();
                _recordingDuration = 0.0;
                _recordingFirstMessageTime = message.timestampSeconds;
            }
            
            message.timestampSeconds -= _recordingFirstMessageTime;
            [_recording appendBytes:&message length:MSG_SIZE];
            _recordingDuration = HOST_TIME.currentHostTimeInSeconds() - _recordingStart;
            _recordingCount += 1;
            
            int32_t pixel = int32_t(message.timestampSeconds * PIXELS_PER_SECOND + 0.5);
            if (pixel >= _recordingPreview.length) {
                [_recordingPreview setLength:pixel + 1];
            }
            uint8_t* preview = (uint8_t*)_recordingPreview.mutableBytes;
            if (preview[pixel] < MAX_PREVIEW_EVENTS) {
                preview[pixel] += 1;
            }
        }
    });
}

- (void)ping {
    dispatch_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_recordingStart == 0.0) {
                _recordingDuration = 0.0;
            }
            else {
                _recordingDuration = HOST_TIME.currentHostTimeInSeconds() - _recordingStart;
            }
        }
    });
}

#pragma mark Getters

- (NSData*)recorded {
    __block NSData* recorded = nil;
    
    dispatch_sync(_dispatchQueue, ^{
        recorded = _recorded;
    });
    
    return recorded;
}

- (double)duration {
    __block double duration = 0.0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_recorded != nil) {
            duration = _recordedDuration;
        }
        else {
            duration = _recordingDuration;
        }
    });
    
    return duration;
}

- (uint32_t)count {
    __block uint32_t count = 0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_recorded != nil) {
            count = _recordedCount;
        }
        else {
            count = _recordingCount;
        }
    });
    
    return count;
}

- (NSData*)preview {
    __block NSData* preview = nil;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_recorded != nil) {
            preview = _recordedPreview;
        }
        else {
            preview = _recordingPreview;
        }
    });
    
    return preview;
}

@end
