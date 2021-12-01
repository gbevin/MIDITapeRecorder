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
#include "RecordedMidiMessage.h"

@implementation MidiRecorder {
    dispatch_queue_t _dispatchQueue;
    
    NSMutableData* _recording;
    NSMutableData* _recordingPreview;
    double _recordingStartMachSeconds;
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
        
        _recordingStartMachSeconds = 0.0;
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
            _recordingStartMachSeconds = 0.0;
            _recordingFirstMessageTime = 0.0;

            _recording = [NSMutableData new];
            _recordingPreview = [NSMutableData new];
            _recordingDurationSeconds = 0.0;
            _recordingCount = 0;
            
            if (_delegate) {
                [_delegate finishRecording:_ordinal data:(const RecordedMidiMessage*)_recorded.bytes count:_recordedCount];
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

- (void)startRecord:(double)machTimeSeconds {
    if (_record && _recordingStartMachSeconds == 0.0) {
        _recordingStartMachSeconds = machTimeSeconds;
        _recordingDurationSeconds = 0.0;
    }
}

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record == NO) {
            return;
        }
        
        if (_record && _recording != nil) {
            if (_recordingCount == 0) {
                double now_mach = HOST_TIME.currentMachTimeInSeconds();
                
                // auto start the recording on the first received message
                // if the recording hasn't started yet
                if (_recordingStartMachSeconds == 0.0) {
                    if (_delegate) {
                        [_delegate startRecord:now_mach];
                    }
                }
                
                // keep track of the time of the first message so that the offset of all messages
                // can be calculated off of this
                // if the recording of this track started later than the others, compensate that
                // with an additional offset to the time of the first message
                _recordingFirstMessageTime = message.timeSampleSeconds - (now_mach - _recordingStartMachSeconds);
            }
            
            // add message to the recording
            RecordedMidiMessage recorded_message;
            recorded_message.cable = _ordinal;
            recorded_message.offsetSeconds = message.timeSampleSeconds - _recordingFirstMessageTime;
            recorded_message.length = message.length;
            recorded_message.data[0] = message.data[0];
            recorded_message.data[1] = message.data[1];
            recorded_message.data[2] = message.data[2];
            [_recording appendBytes:&recorded_message length:RECORDED_MSG_SIZE];
            _recordingDurationSeconds = HOST_TIME.currentMachTimeInSeconds() - _recordingStartMachSeconds;
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
        }
    });
}

- (void)ping {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_recordingStartMachSeconds == 0.0) {
                _recordingDurationSeconds = 0.0;
            }
            else {
                _recordingDurationSeconds = HOST_TIME.currentMachTimeInSeconds() - _recordingStartMachSeconds;
            }
        }
    });
}

#pragma mark Getters

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
