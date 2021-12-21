//
//  Logging.mm
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/20/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "Logging.h"

#include "QueuedMidiMessage.h"
#include "RecordedMidiMessage.h"

void logQueuedMidiMessage(NSString* type, const QueuedMidiMessage& message) {
    uint8_t status = message.data[0] & 0xf0;
    uint8_t channel = message.data[0] & 0x0f;
    uint8_t data1 = message.data[1];
    uint8_t data2 = message.data[2];
    
    if (message.length == 2) {
        NSLog(@"%@ %f %d : %d - %2s [%3s %3s    ]",
              type, message.timeSampleSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String);
    }
    else {
        NSLog(@"%@ %f %d : %d - %2s [%3s %3s %3s]",
              type, message.timeSampleSeconds, message.cable, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String,
              [NSString stringWithFormat:@"%d", data2].UTF8String);
    }
}

void logRecordedMidiMessage(int track, NSString* type, const RecordedMidiMessage& message) {
    uint8_t status = message.data[0] & 0xf0;
    uint8_t channel = message.data[0] & 0x0f;
    uint8_t data1 = message.data[1];
    uint8_t data2 = message.data[2];
    
    if (message.length == 2) {
        NSLog(@"%@ %f %d : %d - %d - %2s [%3s %3s    ]",
              type, message.offsetBeats, track, message.type, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String);
    }
    else {
        NSLog(@"%@ %f %d : %d - %d - %2s [%3s %3s %3s]",
              type, message.offsetBeats, track, message.type, message.length,
              [NSString stringWithFormat:@"%d", channel].UTF8String,
              [NSString stringWithFormat:@"%d", status].UTF8String,
              [NSString stringWithFormat:@"%d", data1].UTF8String,
              [NSString stringWithFormat:@"%d", data2].UTF8String);
    }
}
