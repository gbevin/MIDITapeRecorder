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

#import "MidiRecorder.h"
#import "MidiRecorderState.h"

#define DEBUG_MIDI_INPUT 0

@implementation MidiQueueProcessor {
    MidiRecorderState* _state;
    MidiRecorder* _recorder[MIDI_TRACKS];
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _state = nullptr;
        
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            _recorder[t] = [[MidiRecorder alloc] initWithOrdinal:t];
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
        [self logMidiMessage:message];
#endif
        
        if (_state) {
            for (int t = 0; t < MIDI_TRACKS; ++t) {
                if (_state->track[t].sourceCable == message.cable) {
                    _state->track[t].activityInput = 1.0;
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
        NSLog(@"%f %d : %d - %2s [%3s %3s    ]",
              message.timeSampleSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String);
    }
    else {
        NSLog(@"%f %d : %d - %2s [%3s %3s %3s]",
              message.timeSampleSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String,
              [NSString stringWithFormat:@"%d", data2].UTF8String);
    }
}

- (void)ping {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        [_recorder[t] ping];
    }
}

#pragma mark Getters and Setter

- (void)setState:(MidiRecorderState*)state {
    _state = state;

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        [_recorder[t] setState:state];
    }
}

- (MidiRecorder*)recorder:(int)ordinal {
    if (ordinal < 0 || ordinal >= MIDI_TRACKS) {
        return nil;
    }
    
    return _recorder[ordinal];
}

@end
