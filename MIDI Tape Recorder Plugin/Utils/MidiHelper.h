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
uint32_t readMidiVarLen(uint8_t* data, uint32_t& value);
