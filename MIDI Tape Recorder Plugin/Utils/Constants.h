//
//  Constants.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

static const int MIDI_TRACKS = 4;

static const int MIDI_NOTE_OFF = 128;
static const int MIDI_NOTE_ON = 144;

static const int PIXELS_PER_BEAT = 32;
static const int MAX_PREVIEW_EVENTS = 0xf;

static const int32_t MIDI_BEAT_TICKS = 0x7fff;

enum {
    // We group all the per-track parameters sequentially so that we can just apply an offset
    // to determine which track parameter needs to be addressed
    ID_RECORD_1,
    ID_RECORD_2,
    ID_RECORD_3,
    ID_RECORD_4,
    ID_MONITOR_1,
    ID_MONITOR_2,
    ID_MONITOR_3,
    ID_MONITOR_4,
    ID_MUTE_1,
    ID_MUTE_2,
    ID_MUTE_3,
    ID_MUTE_4,
    // All non-track specific parameter follow below
    ID_REPEAT,
    ID_GRID,
    ID_CHASE,
    ID_PUNCH_INOUT
};
