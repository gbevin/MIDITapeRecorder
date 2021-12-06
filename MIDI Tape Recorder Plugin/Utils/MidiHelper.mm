//
//  MidiHelper.mm
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/6/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "MidiHelper.h"

#import <CoreFoundation/CoreFoundation.h>

BOOL needsMidiByteSwap() {
    if (CFByteOrderGetCurrent() == CFByteOrderLittleEndian) {
        return YES;
    }
    
    return NO;
}


void writeMidiVarLen(NSMutableData* data, uint32_t value) {
    uint32_t buffer = 0;
    buffer = value & 0x7f;
    while ((value >>= 7) > 0) {
        buffer <<= 8;
        buffer |= 0x80;
        buffer += (value & 0x7f);
    }
    while (YES) {
        uint8_t b = buffer & 0xff;
        [data appendBytes:&b length:1];
        if (buffer & 0x80) {
            buffer >>= 8;
        }
        else {
            break;
        }
    }
}


uint32_t readMidiVarLen(uint8_t* data, uint32_t& value) {
    value = 0;
    
    uint32_t count = 0;
    uint8_t c;
    if ((value = data[count++]) & 0x80) {
        value &= 0x7f;
        do {
            value = (value << 7) + ((c = data[count++]) & 0x7f);
        }
        while (c & 0x80);
    }
    
    return count;
}
