//
//  MidiRecorder.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorder.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "HostTime.h"

@implementation MidiRecorder {
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
            // when recording is stopped, we move the recording data to the recorded data
            _recorded = _recording;
            _recordedPreview = _recordingPreview;
            _recordedDuration = _recordingDuration;
            _recordedCount = _recordingCount;

            // then re-initialize the recording for the next time
            _recordingStart = 0.0;
            _recordingFirstMessageTime = 0.0;

            _recording = [NSMutableData new];
            _recordingPreview = [NSMutableData new];
            _recordingDuration = 0.0;
            _recordingCount = 0;
            
            if (_delegate) {
                [_delegate finishRecording:_ordinal data:(const QueuedMidiMessage*)_recorded.bytes count:_recordedCount];
            }
        }
        else {
            if (_delegate) {
                [_delegate invalidateRecording:_ordinal];
            }
        }
    });
}

#pragma mark Recording

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record == NO) {
            return;
        }
        
        if (_record && _recording != nil) {
            // keep track of when the recording started
            if (_recordingCount == 0) {
                _recordingStart = HOST_TIME.currentHostTimeInSeconds();
                _recordingDuration = 0.0;
                _recordingFirstMessageTime = message.timestampSeconds;
                
                if (_delegate) {
                    [_delegate startRecord:_ordinal];
                }
            }
            
            // adapt message data for recorded format
            message.cable = _ordinal;
            message.timestampSeconds -= _recordingFirstMessageTime;
            
            // add message to the recording
            [_recording appendBytes:&message length:MSG_SIZE];
            _recordingDuration = HOST_TIME.currentHostTimeInSeconds() - _recordingStart;
            _recordingCount += 1;
            
            // update the preview
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
    dispatch_barrier_sync(_dispatchQueue, ^{
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

- (double)duration {
    __block double duration = 0.0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_record == YES) {
            duration = _recordingDuration;
        }
        else {
            duration = _recordedDuration;
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
