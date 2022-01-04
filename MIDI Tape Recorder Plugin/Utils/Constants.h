//
//  Constants.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

const int MIDI_TRACKS = 4;
const int MIDI_CHANNELS = 16;
const int MIDI_NOTES = 128;

const int MIDI_NOTE_OFF = 128;
const int MIDI_NOTE_ON = 144;

const int PIXELS_PER_BEAT = 32;
const int MAX_PREVIEW_EVENTS = 0xf;

const int32_t MIDI_BEAT_TICKS = 0x7fff;

enum PluginParameters {
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
    ID_REWIND,
    ID_PLAY,
    ID_RECORD,
    ID_REPEAT,
    ID_GRID,
    ID_CHASE,
    ID_PUNCH_INOUT,
    ID_CLEAR_ALL,
    ID_CLEAR_1,
    ID_CLEAR_2,
    ID_CLEAR_3,
    ID_CLEAR_4
};
