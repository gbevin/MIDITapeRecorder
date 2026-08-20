//
//  MidiHelper.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/6/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <Foundation/Foundation.h>

BOOL needsMidiByteSwap();
void writeMidiVarLen(NSMutableData* data, uint32_t value);
// reads a variable-length quantity of at most `available` bytes; returns the
// number of bytes consumed (0 when nothing is available)
uint32_t readMidiVarLen(const uint8_t* data, uint32_t available, uint32_t& value);
