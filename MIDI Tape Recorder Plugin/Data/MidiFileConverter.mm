//
//  MidiFileConverter.mm
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiFileConverter.h"

#include <cmath>

#include "Constants.h"
#include "MidiHelper.h"

namespace midifile {

NSData* writeFileHeader(int ntrks) {
    NSMutableData* data = [NSMutableData new];

    BOOL needs_byte_swap = needsMidiByteSwap();

    // ASCII tag; UTF-8 yields the same bytes
    [data appendBytes:[@"MThd" UTF8String] length:4];

    uint32_t file_header_length = 6;
    if (needs_byte_swap) file_header_length = CFSwapInt32(file_header_length);
    [data appendBytes:&file_header_length length:4];

    uint16_t file_header_format = 1;
    if (needs_byte_swap) file_header_format = CFSwapInt16(file_header_format);
    [data appendBytes:&file_header_format length:2];

    uint16_t file_header_ntrks = ntrks;
    if (needs_byte_swap) file_header_ntrks = CFSwapInt16(file_header_ntrks);
    [data appendBytes:&file_header_ntrks length:2];

    // number of ticks per quarter note
    int32_t beat_ticks = MIDI_BEAT_TICKS;
    uint16_t file_header_division = needs_byte_swap ? CFSwapInt16(beat_ticks) : beat_ticks;
    [data appendBytes:&file_header_division length:2];

    return data;
}

NSData* writeTrackChunk(const Track& track, double bpm) {
    // accumulate the body separately so we can prefix it with its length
    NSMutableData* body = [NSMutableData new];

    // tempo meta event at delta 0
    writeMidiVarLen(body, 0);
    // we can't have more than 0xffffff microseconds per beat
    int32_t beat_micros = MIN(1000000.0 * 60.0 / bpm, 0xffffff);
    uint8_t meta_tempo[] = { 0xff, 0x51, 0x03 };
    [body appendBytes:&meta_tempo[0] length:3];
    uint8_t bm1 = (beat_micros >> 16) & 0xff;
    [body appendBytes:&bm1 length:1];
    uint8_t bm2 = (beat_micros >> 8) & 0xff;
    [body appendBytes:&bm2 length:1];
    uint8_t bm3 = beat_micros & 0xff;
    [body appendBytes:&bm3 length:1];

    // midi events
    int64_t last_offset_ticks = 0;
    for (const RecordedMidiMessage& message : track.messages) {
        if (message.type == INTERNAL) {
            continue;
        }

        int64_t offset_ticks = int64_t(ceil(MAX(message.offsetBeats, 0.0) * MIDI_BEAT_TICKS));
        uint32_t delta_ticks = uint32_t(MAX(offset_ticks - last_offset_ticks, (int64_t)0));
        writeMidiVarLen(body, delta_ticks);
        [body appendBytes:message.data length:message.length];

        last_offset_ticks = offset_ticks;
    }

    // end of track meta event
    int64_t offset_ticks = int64_t(ceil(MAX(track.durationBeats, 0.0) * MIDI_BEAT_TICKS));
    uint32_t delta_ticks = uint32_t(MAX(offset_ticks - last_offset_ticks, (int64_t)0));
    writeMidiVarLen(body, delta_ticks);
    uint8_t meta_end_of_track[] = { 0xff, 0x2f, 0x00 };
    [body appendBytes:&meta_end_of_track[0] length:3];

    // full chunk, including the header
    NSMutableData* data = [NSMutableData new];
    [data appendBytes:[@"MTrk" UTF8String] length:4];
    uint32_t track_header_length = needsMidiByteSwap() ? CFSwapInt32((uint32_t)body.length) : (uint32_t)body.length;
    [data appendBytes:&track_header_length length:4];
    [data appendData:body];

    return data;
}

NSData* writeFile(const std::vector<Track>& tracks, double bpm) {
    NSMutableData* data = [NSMutableData new];
    [data appendData:writeFileHeader((int)tracks.size())];
    for (const Track& track : tracks) {
        [data appendData:writeTrackChunk(track, bpm)];
    }
    return data;
}

BOOL parseHeader(NSData* file, uint16_t& division, uint16_t& ntrks, long& firstChunkOffset) {
    if (file == nil || file.length < 14) {
        return NO;
    }

    BOOL needs_byte_swap = needsMidiByteSwap();

    char file_type_bytes[5] = { 0, 0, 0, 0, 0 };
    [file getBytes:(void*)file_type_bytes range:NSMakeRange(0, 4)];
    if (![[NSString stringWithUTF8String:file_type_bytes] isEqualToString:@"MThd"]) {
        return NO;
    }

    uint32_t file_header_length;
    [file getBytes:(void*)&file_header_length range:NSMakeRange(4, 4)];
    if (needs_byte_swap) file_header_length = CFSwapInt32(file_header_length);
    if (file_header_length != 6) {
        return NO;
    }

    uint16_t file_header_format;
    [file getBytes:(void*)&file_header_format range:NSMakeRange(8, 2)];
    if (needs_byte_swap) file_header_format = CFSwapInt16(file_header_format);
    if (file_header_format != 0 && file_header_format != 1) {
        return NO;
    }

    uint16_t file_header_ntrks;
    [file getBytes:(void*)&file_header_ntrks range:NSMakeRange(10, 2)];
    if (needs_byte_swap) file_header_ntrks = CFSwapInt16(file_header_ntrks);
    if (file_header_ntrks < 1) {
        return NO;
    }

    uint16_t file_header_division;
    [file getBytes:(void*)&file_header_division range:NSMakeRange(12, 2)];
    if (needs_byte_swap) file_header_division = CFSwapInt16(file_header_division);
    if ((file_header_division & 0x8000) != 0) {
        // SMPTE-based timing is not supported
        return NO;
    }
    if (file_header_division == 0) {
        return NO;
    }

    division = file_header_division;
    ntrks = file_header_ntrks;
    firstChunkOffset = 14;
    return YES;
}

NSArray<NSData*>* trackChunks(NSData* file, uint16_t& division) {
    uint16_t ntrks = 0;
    long data_index = 0;
    if (!parseHeader(file, division, ntrks, data_index)) {
        return @[];
    }

    // need room for at least one track chunk header
    if (file.length < 22) {
        return @[];
    }

    BOOL needs_byte_swap = needsMidiByteSwap();
    NSMutableArray<NSData*>* chunks = [NSMutableArray array];
    int tracks_seen = 0;

    while (tracks_seen < ntrks) {
        // a chunk header is 8 bytes (4 type + 4 length)
        if (data_index + 8 > (long)file.length) {
            break;
        }

        char chunk_type[5] = { 0, 0, 0, 0, 0 };
        [file getBytes:(void*)chunk_type range:NSMakeRange(data_index, 4)];
        data_index += 4;

        uint32_t chunk_length;
        [file getBytes:(void*)&chunk_length range:NSMakeRange(data_index, 4)];
        data_index += 4;
        if (needs_byte_swap) chunk_length = CFSwapInt32(chunk_length);

        // the chunk body must fit within the remaining data
        if (data_index + (long)chunk_length > (long)file.length) {
            break;
        }

        // skip any non-track chunk type, as required by the SMF spec
        if (memcmp(chunk_type, "MTrk", 4) != 0) {
            data_index += chunk_length;
            continue;
        }
        tracks_seen += 1;

        [chunks addObject:[file subdataWithRange:NSMakeRange(data_index, chunk_length)]];
        data_index += chunk_length;
    }

    return chunks;
}

BOOL parseTrackChunk(NSData* chunkBody, uint16_t division, Track& outTrack) {
    if (chunkBody == nil || chunkBody.length == 0 || division == 0) {
        return NO;
    }

    outTrack.messages.clear();
    outTrack.durationBeats = 0.0;

    int64_t last_offset_ticks = 0;
    uint8_t running_status = 0;
    const uint32_t length = (uint32_t)chunkBody.length;
    uint8_t* track_bytes = (uint8_t*)chunkBody.bytes;
    uint32_t i = 0;
    while (i < length) {
        // read variable length delta time
        uint32_t delta_ticks = 0;
        i += readMidiVarLen(&track_bytes[i], length - i, delta_ticks);
        if (i >= length) {
            break;
        }

        int64_t offset_ticks = last_offset_ticks + delta_ticks;
        // sanitize the ticks in case they were generated from negative values
        if (offset_ticks > 0xfffffff) {
            offset_ticks = 0;
        }
        double duration_beats = double(offset_ticks) / division;
        last_offset_ticks = offset_ticks;

        // handle event
        uint8_t event_identifier = track_bytes[i];
        i += 1;
        switch (event_identifier) {
            // sysex event
            case 0xf0:
            case 0xf7: {
                // Note: the SMF spec says SysEx cancels running status, but many
                // real-world files keep it across these events, so we leave
                // running_status untouched for maximum compatibility.
                if (i >= length) { break; }
                uint32_t event_length = 0;
                i += readMidiVarLen(&track_bytes[i], length - i, event_length);
                i += event_length;
                break;
            }
            // meta event
            case 0xff: {
                if (i + 1 >= length) { i = length; break; }
                // skip over the meta event type
                i += 1;
                uint32_t event_length = 0;
                i += readMidiVarLen(&track_bytes[i], length - i, event_length);
                i += event_length;
                break;
            }
            // channel voice event (possibly using running status)
            default: {
                uint8_t status;
                uint8_t d1;
                if ((event_identifier & 0x80) != 0) {
                    // an explicit status byte; only channel voice messages
                    // (0x80-0xEF) carry running status and data we record.
                    // system common messages are skipped together with their
                    // data bytes (0xF1/0xF3 carry one, 0xF2 carries two), so
                    // the stream stays in sync for the events that follow
                    if (event_identifier >= 0xf0) {
                        if (event_identifier == 0xf1 || event_identifier == 0xf3) {
                            i += 1;
                        }
                        else if (event_identifier == 0xf2) {
                            i += 2;
                        }
                        if (i > length) {
                            i = length;
                        }
                        running_status = 0;
                        break;
                    }
                    status = event_identifier;
                    running_status = status;
                    if (i >= length) { i = length; break; }
                    d1 = track_bytes[i];
                    i += 1;
                }
                else {
                    // running status: the byte we just read is the first data byte
                    if (running_status == 0) {
                        // corrupt stream, stop parsing this track
                        i = length;
                        break;
                    }
                    status = running_status;
                    d1 = event_identifier;
                }

                RecordedMidiMessage msg;
                msg.offsetBeats = duration_beats;

                // program change and channel pressure carry a single data byte
                if ((status & 0xf0) == 0xc0 || (status & 0xf0) == 0xd0) {
                    msg.length = 2;
                    msg.data[0] = status;
                    msg.data[1] = d1;
                    msg.data[2] = 0;
                }
                // all other channel voice messages carry two data bytes
                else {
                    if (i >= length) { i = length; break; }
                    uint8_t d2 = track_bytes[i];
                    i += 1;

                    msg.length = 3;
                    msg.data[0] = status;
                    msg.data[1] = d1;
                    msg.data[2] = d2;
                }

                outTrack.messages.push_back(msg);
                break;
            }
        }
    }

    outTrack.durationBeats = double(last_offset_ticks) / division;
    return !outTrack.messages.empty();
}

}  // namespace midifile
