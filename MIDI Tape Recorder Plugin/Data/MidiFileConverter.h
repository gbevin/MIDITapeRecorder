//
//  MidiFileConverter.h
//  MIDI Tape Recorder
//
//  Standard MIDI File (SMF) reading and writing, working purely on vectors of
//  RecordedMidiMessage. Shared by the plugin (MidiQueueProcessor / MidiTrackRecorder)
//  and the standalone host so the file format lives in one place.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#import <Foundation/Foundation.h>

#include <vector>

#include "RecordedMidiMessage.h"

namespace midifile {

// One track's worth of recorded messages plus its total duration in beats.
struct Track {
    std::vector<RecordedMidiMessage> messages;
    double durationBeats = 0.0;
};

// ---- Writing ----

// A 14-byte MThd header (format 1) describing `ntrks` tracks at the tick resolution.
NSData* writeFileHeader(int ntrks);

// One MTrk chunk (header + body) for a track: a Set Tempo meta for `bpm`, the
// channel-voice messages with delta times, and an End Of Track meta. INTERNAL
// (overdub) markers are not written.
NSData* writeTrackChunk(const Track& track, double bpm);

// A complete SMF for the given tracks (one chunk each), tempo `bpm`.
NSData* writeFile(const std::vector<Track>& tracks, double bpm);

// ---- Reading ----

// Validates the MThd header. Returns NO for non-SMF, unsupported (SMPTE) or
// malformed files. On success yields the tick division, declared track count, and
// the byte offset of the first chunk.
BOOL parseHeader(NSData* file, uint16_t& division, uint16_t& ntrks, long& firstChunkOffset);

// The MTrk chunk bodies (excluding their 8-byte chunk headers), in file order,
// skipping any non-track chunks. `division` is filled from the header. Returns an
// empty array if the file is invalid.
NSArray<NSData*>* trackChunks(NSData* file, uint16_t& division);

// Parses one MTrk chunk body into channel-voice messages and a raw duration (in
// beats). Returns NO if the chunk produced no channel content (e.g. a conductor
// track), in which case `outTrack` should be ignored.
BOOL parseTrackChunk(NSData* chunkBody, uint16_t division, Track& outTrack);

}  // namespace midifile
