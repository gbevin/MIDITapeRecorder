//
//  MidiQueueProcessor.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//

#import "MidiQueueProcessor.h"

#include <mach/mach_time.h>

#import <CoreAudioKit/CoreAudioKit.h>

#define DEBUG_MIDI_INPUT 0

static const int32_t MSG_SIZE = sizeof(QueuedMidiMessage);

@interface MidiQueueProcessor ()
@end

@implementation MidiQueueProcessor {
    dispatch_queue_t _dispatchQueue;
    
    double _hostTimeToSeconds;
    double _secondsToHostTime;

    NSMutableData* _recording;
    double _recordingStart;
    double _recordingTime;
    double _recordingFirstMessageTime;
    uint32_t _recordingCount;
    
    NSData* _recorded;
    double _recordedTime;
    uint32_t _recordedCount;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _dispatchQueue = dispatch_queue_create("com.uwyn.midirecorder.Recording", DISPATCH_QUEUE_CONCURRENT);
        
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        _hostTimeToSeconds = ((double)info.numer) / ((double)info.denom) * 1.0e-9;
        _secondsToHostTime = (1.0e9 * (double)info.denom) / ((double)info.numer);

        _recording = [NSMutableData new];
        _recordingStart = 0.0;
        _recordingTime = 0.0;
        _recordingFirstMessageTime = 0.0;
        _recordingCount = 0;
        
        _recorded = nil;
        _recordedTime = 0.0;
        _recordedCount = 0;
    }
    
    return self;
}

- (double)hostTimeInSeconds:(double)time {
    return time * _hostTimeToSeconds;
}

- (double)secondsInHostTime:(double)time {
    return time * _secondsToHostTime;
}

- (double)currentHostTimeInSeconds {
    return ((double)mach_absolute_time()) * _hostTimeToSeconds;
}

#pragma mark Transport

- (void)setPlay:(BOOL)play {
    if (_play == play) {
        return;
    }
    
    _play = play;
    
    [self setRecord:NO];
    
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_delegate) {
            if (play == YES) {
                [_delegate playRecorded:_recorded.bytes length:_recordedCount];
            }
            else {
                [_delegate stopRecorded];
            }
        }
    });
}

- (void)setRecord:(BOOL)record {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record == record) {
            return;
        }
        
        if (_delegate) {
            [_delegate invalidateRecorded];
        }
        
        _record = record;
        
        if (record == NO) {
            _recorded = _recording;
            _recordedTime = _recordingTime;
            _recordedCount = _recordingCount;

            _recording = [NSMutableData new];
            _recordingStart = 0.0;
            _recordingTime = 0.0;
            _recordingFirstMessageTime = 0.0;
            _recordingCount = 0;
        }
        else {
            _recorded = nil;
            _recordedTime = 0;
            _recordedCount = 0;
        }
    });
}

#pragma mark Queue Processing

- (void)processMidiQueue:(TPCircularBuffer*)queue {
    uint32_t bufferedBytes;
    uint32_t availableBytes;
    void* bytes;
    
    bytes = TPCircularBufferTail(queue, &bufferedBytes);
    availableBytes = bufferedBytes;
    while (bytes && availableBytes >= MSG_SIZE && bufferedBytes >= MSG_SIZE) {
        QueuedMidiMessage message;
        memcpy(&message, bytes, MSG_SIZE);
        
#if DEBUG_MIDI_INPUT
        [self logMidiMessage:message];
#endif
        
        [self recordMidiMessage:message];
        
        TPCircularBufferConsume(queue, MSG_SIZE);
        bufferedBytes -= MSG_SIZE;
        bytes = TPCircularBufferTail(queue, &availableBytes);
    }
}

- (void)logMidiMessage:(QueuedMidiMessage&)message {
    uint8_t status = message.data[0] & 0xf0;
    uint8_t channel = message.data[0] & 0x0f;
    uint8_t data1 = message.data[1];
    uint8_t data2 = message.data[2];
    
    if (message.length == 2) {
        NSLog(@"%f %d : %d - %2s [%3s %3s    ]",
              message.timestampSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String);
    }
    else {
        NSLog(@"%f %d : %d - %2s [%3s %3s %3s]",
              message.timestampSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String,
              [NSString stringWithFormat:@"%d", data2].UTF8String);
    }
}

- (void)ping {
    dispatch_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_recordingStart == 0.0) {
                _recordingTime = 0.0;
            }
            else {
                _recordingTime = [self currentHostTimeInSeconds] - _recordingStart;
            }
        }
    });
}

#pragma mark Recording

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record && _recording != nil) {
            if (_recordingCount == 0) {
                _recordingStart = [self currentHostTimeInSeconds];
                _recordingTime = 0.0;
                _recordingFirstMessageTime = message.timestampSeconds;
            }
            
            message.timestampSeconds -= _recordingFirstMessageTime;
            [_recording appendBytes:&message length:MSG_SIZE];
            _recordingTime = [self currentHostTimeInSeconds] - _recordingStart;
            _recordingCount += 1;
        }
    });
}

#pragma mark Getters

- (double)recordedTime {
    __block double time = 0.0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_recorded != nil) {
            time = _recordedTime;
        }
        else {
            time = _recordingTime;
        }
    });
    
    return time;
}

- (uint32_t)recordedCount {
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

@end
