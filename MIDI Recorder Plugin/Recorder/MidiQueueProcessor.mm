//
//  MidiQueueProcessor.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//

#import "MidiQueueProcessor.hpp"

#import <CoreAudioKit/CoreAudioKit.h>

#define DEBUG_MIDI_INPUT 0

@interface MidiQueueProcessor ()
@end

@implementation MidiQueueProcessor {
    dispatch_queue_t _dispatchQueue;
    
    NSMutableData* _recording;
    uint32_t _recordingCount;
    
    NSData* _recorded;
    uint32_t _recordedCount;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _dispatchQueue = dispatch_queue_create("com.uwyn.midirecorder.Recording", DISPATCH_QUEUE_CONCURRENT);
        
        _recording = [NSMutableData new];
        _recordingCount = 0;
        
        _recorded = nil;
        _recordedCount = 0;
    }
    
    return self;
}

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
            _recordedCount = _recordingCount;
            
            _recording = [NSMutableData new];
            _recordingCount = 0;
        }
        else {
            _recorded = nil;
            _recordedCount = 0;
        }
    });
}

- (void)processMidiQueue:(TPCircularBuffer*)queue {
    static const int32_t MSG_SIZE = sizeof(QueuedMidiMessage);
    uint32_t bufferedBytes;
    uint32_t availableBytes;
    void* bytes;
    
    bytes = TPCircularBufferTail(queue, &bufferedBytes);
    availableBytes = bufferedBytes;
    while (bytes && availableBytes >= MSG_SIZE && bufferedBytes >= MSG_SIZE) {
        QueuedMidiMessage message;
        memcpy(&message, bytes, MSG_SIZE);
        
#if DEBUG_MIDI_INPUT
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
#endif
        dispatch_barrier_sync(_dispatchQueue, ^{
            if (_record && _recording != nil) {
                [_recording appendBytes:&message length:MSG_SIZE];
                _recordingCount += 1;
            }
        });
        
        TPCircularBufferConsume(queue, MSG_SIZE);
        bufferedBytes -= MSG_SIZE;
        bytes = TPCircularBufferTail(queue, &availableBytes);
    }
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
