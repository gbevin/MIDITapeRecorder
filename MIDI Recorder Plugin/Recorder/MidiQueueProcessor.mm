//
//  MidiQueueProcessor.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import "MidiQueueProcessor.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "HostTime.h"

#import "AudioUnitGUIState.h"
#import "MidiRecorder.h"

#define DEBUG_MIDI_INPUT 0

@implementation MidiQueueProcessor {
    dispatch_queue_t _dispatchQueue;
    
    MidiRecorder* _recorder1;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _dispatchQueue = dispatch_queue_create("com.uwyn.midirecorder.MidiQueue", DISPATCH_QUEUE_CONCURRENT);
        
        _recorder1 = [[MidiRecorder alloc] initWithOrdinal:0];
    }
    
    return self;
}

#pragma mark Transport

- (void)setPlay:(BOOL)play {
    if (_play == play) {
        return;
    }
    
    _play = play;
    
    _recorder1.record = NO;

    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_delegate) {
            if (play == YES) {
                [_delegate playRecorded:_recorder1];
            }
            else {
                [_delegate stopRecorded];
            }
        }
    });
}

- (void)setRecord:(BOOL)record {
    dispatch_barrier_sync(_dispatchQueue, ^{
        _recorder1.record = record;
        
        if (_delegate) {
            [_delegate invalidateRecorded];
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
        
        [_recorder1 recordMidiMessage:message];
        
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
    [_recorder1 ping];
}

#pragma mark Getters

- (MidiRecorder*)recorder:(int)ordinal {
    switch (ordinal) {
        case 0:
            return _recorder1;
    }
    
    return nil;
}

@end
