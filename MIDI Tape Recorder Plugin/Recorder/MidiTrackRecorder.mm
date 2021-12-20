//
//  MidiTrackRecorder.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiTrackRecorder.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "MidiHelper.h"
#include "MidiRecorderState.h"

@implementation MidiTrackRecorder {
    dispatch_queue_t _dispatchQueue;
    
    MidiRecorderState* _state;
    
    int16_t _lastRpnMsb[MIDI_CHANNELS];
    int16_t _lastRpnLsb[MIDI_CHANNELS];
    int16_t _lastDataMsb[MIDI_CHANNELS];
    int16_t _lastDataLsb[MIDI_CHANNELS];

    std::unique_ptr<MidiRecordedData> _recordingData;
    std::unique_ptr<MidiRecordedPreview> _recordingPreview;
}

- (instancetype)initWithOrdinal:(int)ordinal {
    self = [super init];
    
    if (self) {
        _ordinal = ordinal;
        _dispatchQueue = dispatch_queue_create([NSString stringWithFormat:@"com.uwyn.midirecorder.Recording%d", ordinal].UTF8String, DISPATCH_QUEUE_CONCURRENT);
        
        _state = nil;
        
        for (int ch = 0; ch < MIDI_CHANNELS; ++ch) {
            _lastRpnMsb[ch] = 0x7f;
            _lastRpnLsb[ch] = 0x7f;
            _lastDataMsb[ch] = 0;
            _lastDataLsb[ch] = 0;
        }
        
        _recordingData.reset(new MidiRecordedData());
        _recordingPreview.reset(new MidiRecordedPreview());
    }
    
    return self;
}

#pragma mark Transport

- (void)setRecord:(BOOL)record {
    __block BOOL finish_recording = NO;
    
    dispatch_barrier_sync(_dispatchQueue, ^{
        if (_record == record) {
            return;
        }
        
        _record = record;
        
        if (record == NO) {
            // when recording is stopped, we move the recording data to the recorded data
            auto recorded_data = std::move(_recordingData);
            auto recorded_preview = std::move(_recordingPreview);

            _recordingData.reset(new MidiRecordedData());
            _recordingPreview.reset(new MidiRecordedPreview());
            
            MidiTrackState& track_state = _state->track[_ordinal];
            track_state.pendingRecordedData = std::move(recorded_data);
            track_state.pendingRecordedPreview = std::move(recorded_preview);
            
            // reset state
            _state->processedResetRecording[_ordinal].clear();
            track_state.hasRecordedEvents.clear();

            finish_recording = YES;
        }
    });

    if (_delegate && finish_recording) {
        [_delegate finishRecording:_ordinal];
    }
}

#pragma mark State

- (NSDictionary*)recordedAsDict {
    __block NSDictionary* result;
    dispatch_barrier_sync(_dispatchQueue, ^{
        MidiTrackState& track_state = _state->track[_ordinal];
        NSDictionary* mpe_dict = @{
            @"zone1Members" : @(track_state.mpeState.zone1Members.load()),
            @"zone1ManagerPitchSens" : @(track_state.mpeState.zone1ManagerPitchSens.load()),
            @"zone1MemberPitchSens" : @(track_state.mpeState.zone1MemberPitchSens.load()),
            @"zone2Members" : @(track_state.mpeState.zone2Members.load()),
            @"zone2ManagerPitchSens" : @(track_state.mpeState.zone2ManagerPitchSens.load()),
            @"zone2MemberPitchSens" : @(track_state.mpeState.zone2MemberPitchSens.load()),
        };
        
        auto recorded_data = track_state.recordedData.get();
        if (recorded_data == nullptr) {
            result = @{
                @"MPE" : mpe_dict
            };
        }
        else {
            NSMutableData* recorded_object = [NSMutableData new];
            for (RecordedDataVector& beat : recorded_data->getBeats()) {
                [recorded_object appendBytes:beat.data() length:beat.size()*sizeof(RecordedMidiMessage)];
            }
            result = @{
                @"Recorded" : recorded_object,
                @"Duration" : @(recorded_data->getDuration()),
                @"MPE" : mpe_dict
            };
        }
    });
    return result;
}

- (void)dictToRecorded:(NSDictionary*)dict {
    dispatch_barrier_sync(_dispatchQueue, ^{
        std::unique_ptr<MidiRecordedData> recorded_data(new MidiRecordedData());
        double recorded_duration = 0.0;

        NSData* recorded_object = [dict objectForKey:@"Recorded"];
        if (recorded_object) {
            RecordedMidiMessage* data = (RecordedMidiMessage*)recorded_object.bytes;
            unsigned long count = recorded_object.length / sizeof(RecordedMidiMessage);
            for (int i = 0; i < count; ++i) {
                recorded_data->addMessageToBeat(data[i]);
            }
        }
        
        id duration = [dict objectForKey:@"Duration"];
        if (duration) {
            recorded_duration = [duration doubleValue];
            if (_state->autoTrimRecordings.test()) {
                recorded_duration = ceil(recorded_duration);
            }
            recorded_data->increaseDuration(recorded_duration);
        }
        
        NSDictionary* mpe = [dict objectForKey:@"MPE"];
        if (mpe) {
            MPEState& mpe_state = _state->track[_ordinal].mpeState;
            
            NSNumber* zone1_members = [mpe objectForKey:@"zone1Members"];
            if (zone1_members) {
                mpe_state.zone1Members = zone1_members.intValue;
                mpe_state.zone1Active = (mpe_state.zone1Members != 0);
            }

            NSNumber* zone1_manager_pitch = [mpe objectForKey:@"zone1ManagerPitchSens"];
            if (zone1_manager_pitch) {
                mpe_state.zone1ManagerPitchSens = zone1_manager_pitch.floatValue;
            }

            NSNumber* zone1_member_pitch = [mpe objectForKey:@"zone1MemberPitchSens"];
            if (zone1_member_pitch) {
                mpe_state.zone1MemberPitchSens = zone1_member_pitch.floatValue;
            }

            NSNumber* zone2_members = [mpe objectForKey:@"zone2Members"];
            if (zone2_members) {
                mpe_state.zone2Members = zone2_members.intValue;
                mpe_state.zone2Active = (mpe_state.zone2Members != 0);
            }

            NSNumber* zone2_manager_pitch = [mpe objectForKey:@"zone2ManagerPitchSens"];
            if (zone2_manager_pitch) {
                mpe_state.zone2ManagerPitchSens = zone2_manager_pitch.floatValue;
            }

            NSNumber* zone2_member_pitch = [mpe objectForKey:@"zone2MemberPitchSens"];
            if (zone2_member_pitch) {
                mpe_state.zone2MemberPitchSens = zone2_member_pitch.floatValue;
            }

            mpe_state.enabled = (mpe_state.zone1Active || mpe_state.zone2Active);
        }
        

        // update preview
        std::unique_ptr<MidiRecordedPreview> recorded_preview(new MidiRecordedPreview());
        if (recorded_data) {
            for (RecordedDataVector& beat : recorded_data->getBeats()) {
                for (RecordedMidiMessage& message : beat) {
                    recorded_preview->updateWithMessage(message);
                }
            }
        }
        
        MidiTrackState& track_state = _state->track[_ordinal];
        track_state.pendingRecordedData = std::move(recorded_data);
        track_state.pendingRecordedPreview = std::move(recorded_preview);
    });

    if (_delegate) {
        [_delegate finishImport:_ordinal];
    }
}

#pragma mark MIDI files

- (NSData*)recordedAsMidiTrackChunk {
    MidiTrackState& state = _state->track[_ordinal];
    auto recorded_data = state.recordedData.get();
    if (!recorded_data || recorded_data->empty()) {
        return nil;
    }

    // accumulate the track data in a seperate object so that
    // we can provide the length before adding its data
    NSMutableData* track = [NSMutableData new];

    // add tempo to track
    writeMidiVarLen(track, 0);
    // we can't have more than 0xffffff microseconds per beat
    int32_t beat_micros = MIN(1000000.0 * 60.0 / _state->tempo, 0xffffff);
    uint8_t meta_tempo[] = { 0xff, 0x51, 0x03 };
    [track appendBytes:&meta_tempo[0] length:3];
    uint8_t bm1 = (beat_micros >> 16) & 0xff;
    [track appendBytes:&bm1 length:1];
    uint8_t bm2 = (beat_micros >> 8) & 0xff;
    [track appendBytes:&bm2 length:1];
    uint8_t bm3 = beat_micros & 0xff;
    [track appendBytes:&bm3 length:1];

    // add midi events to track
    int64_t last_offset_ticks = 0;
    for (RecordedDataVector& beat : recorded_data->getBeats()) {
        for (RecordedMidiMessage& message : beat) {
            if (message.type == INTERNAL) {
                continue;
            }
            
            int64_t offset_ticks = int64_t(MAX(message.offsetBeats, 0.0) * MIDI_BEAT_TICKS);
            uint32_t delta_ticks = uint32_t(offset_ticks - last_offset_ticks);
            writeMidiVarLen(track, delta_ticks);
            for (int d = 0; d < message.length; ++d) {
                [track appendBytes:&message.data[d] length:1];
            }
            
            last_offset_ticks = offset_ticks;
        }
    }
    
    // add end of track meta event
    int64_t offset_ticks = int64_t(recorded_data->getDuration() * MIDI_BEAT_TICKS);
    uint32_t delta_ticks = uint32_t(offset_ticks - last_offset_ticks);
    writeMidiVarLen(track, delta_ticks);
    uint8_t meta_end_of_track[] = { 0xff, 0x2f, 0x00 };
    [track appendBytes:&meta_end_of_track[0] length:3];
    
    // create the full track chunk, including the header
    NSMutableData* data = [NSMutableData new];

    // we know we're using ASCII character, so UTF-8 will only use those characters
    [data appendBytes:[@"MTrk" UTF8String] length:4];

    // track chunk length
    uint32_t track_header_length = needsMidiByteSwap() ? CFSwapInt32((uint32_t)track.length) : (uint32_t)track.length;
    [data appendBytes:&track_header_length length:4];
    
    // add the previously accumulated track events
    [data appendData:track];

    return data;
}

- (void)midiTrackChunkToRecorded:(NSData*)track division:(uint16_t)division{
    if (track == nil || track.length == 0) {
        return;
    }

    dispatch_barrier_sync(_dispatchQueue, ^{
        // prepare local data to accumulate into
        std::unique_ptr<MidiRecordedData> recorded_data(new MidiRecordedData());
        std::unique_ptr<MidiRecordedPreview> recorded_preview(new MidiRecordedPreview());
        double recorded_duration = 0.0;

        // process the track events
        int64_t last_offset_ticks = 0;
        uint8_t running_status = 0;
        uint32_t i = 0;
        uint8_t* track_bytes = (uint8_t*)track.bytes;
        while (i < track.length) {
            // read variable length delta time
            uint32_t delta_ticks;
            i += readMidiVarLen(&track_bytes[i], delta_ticks);
            
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
                    // capture the event length
                    uint32_t length;
                    i += readMidiVarLen(&track_bytes[i], length);
                    // skip over the event data
                    i += length;
                    break;
                }
                // meta event
                case 0xff: {
                    // skip over the event type
                    i += 1;
                    // capture the event length
                    uint32_t length;
                    i += readMidiVarLen(&track_bytes[i], length);
                    // skip over the event data
                    i += length;
                    break;
                }
                // midi event
                default: {
                    uint8_t d0 = event_identifier;
                    // check for status byte
                    if ((d0 & 0x80) != 0) {
                        running_status = d0;
                    }
                    // not a status byte, we'll reuse the previous one as running status
                    else {
                        d0 = running_status;
                    }
                    
                    RecordedMidiMessage msg;
                    msg.offsetBeats = duration_beats;

                    // get the data bytes based on the active state
                    // one data byte
                    if ((d0 & 0xf0) == 0xc0 || (d0 & 0xf0) == 0xd0) {
                        uint8_t d1 = track_bytes[i];
                        i += 1;
                        
                        msg.length = 2;
                        msg.data[0] = d0;
                        msg.data[1] = d1;
                        msg.data[2] = 0;
                    }
                    // two data bytes
                    else {
                        uint8_t d1 = track_bytes[i];
                        i += 1;
                        uint8_t d2 = track_bytes[i];
                        i += 1;
                        
                        msg.length = 3;
                        msg.data[0] = d0;
                        msg.data[1] = d1;
                        msg.data[2] = d2;
                    }

                    // add the recorded message
                    recorded_data->addMessageToBeat(msg);
                    
                    // update the preview
                    recorded_preview->updateWithMessage(msg);

                    break;
                }
            }
        }
        
        recorded_duration = double(last_offset_ticks) / division;
        if (_state->autoTrimRecordings.test()) {
            recorded_duration = ceil(recorded_duration);
            recorded_data->increaseDuration(recorded_duration);
        }
        
        // transfer all the accumulated data to the active recorded data
        MidiTrackState& track_state = _state->track[_ordinal];
        track_state.pendingRecordedData = std::move(recorded_data);
        track_state.pendingRecordedPreview = std::move(recorded_preview);
    });
    
    if (_delegate) {
        [_delegate finishImport:_ordinal];
    }
}

#pragma mark Recording

- (void)ping:(double)timeSampleSeconds {
    dispatch_barrier_sync(_dispatchQueue, ^{
        // don't record if record enable isn't active
        if (!_record || !_recordingData) {
            return;
        }
        
        // if transport isn't running, don't update recording
        if (_state->transportStartSampleSeconds == 0.0) {
            return;
        }
        
        // we might have to reset the recording if no events were recorded and it wasn't manually stopped
        if (!_state->processedResetRecording[_ordinal].test_and_set()) {
            _recordingData.reset(new MidiRecordedData());
            _recordingPreview.reset(new MidiRecordedPreview());
        }

        // if punch in/out is enabled, only record during the punch in/out positions
        if (_state->inactivePunchInOut()) {
            return;
        }

        // mark the first time the recording had processing
        _recordingData->setStartIfNeeded(_state->playPositionBeats);
        
        // update the recording duration even when there's no incoming messages
        _recordingData->increaseDuration((timeSampleSeconds - _state->transportStartSampleSeconds) * _state->secondsToBeats);
        
        _recordingData->populateUpToBeat(_recordingData->getDuration());
        
        // update the preview in case of gaps
        if (_recordingPreview) {
            _recordingPreview->setStartIfNeeded(_recordingData->getStart());
            _recordingPreview->updateWithOffsetBeats(_recordingData->getDuration());
        }
    });
}

- (void)handleMidiRPNValue:(int)channel {
    int rpn_param = (_lastRpnMsb[channel] << 7) + _lastRpnLsb[channel];
    
    switch (rpn_param) {
        // pitchbend sensitivity
        case 0: {
            float sensitivity = float(_lastDataMsb[channel]) + float(_lastDataLsb[channel]) / 100.f;
            MPEState& mpe_state = _state->track[_ordinal].mpeState;
            if (mpe_state.zone1Active) {
                if (channel == 0) {
                    mpe_state.zone1ManagerPitchSens = sensitivity;
                }
                else if (channel <= mpe_state.zone1Members) {
                    mpe_state.zone1MemberPitchSens = sensitivity;
                }
            }
            if (mpe_state.zone2Active) {
                if (channel == 15) {
                    mpe_state.zone2ManagerPitchSens = sensitivity;
                }
                else if (channel <= 15 - mpe_state.zone2Members) {
                    mpe_state.zone2MemberPitchSens = sensitivity;
                }
            }
            break;
        }
        // MPE configuration message
        case 6: {
            MPEState& mpe_state = _state->track[_ordinal].mpeState;

            // only accept MCM on channels 1 and 16
            if (channel == 0) {
                mpe_state.zone1Members = _lastDataMsb[channel];
                if (mpe_state.zone1Members == 0) {
                    mpe_state.zone1Active = false;
                    mpe_state.zone1ManagerPitchSens = 0.f;
                    mpe_state.zone1MemberPitchSens = 0.f;
                }
                else {
                    mpe_state.zone1Active = true;
                    mpe_state.zone1ManagerPitchSens = 2.f;
                    mpe_state.zone1MemberPitchSens = 48.f;
                }
                
                // disable zone 2 when zone 1 uses all member channels
                if (mpe_state.zone1Members >= 14) {
                    mpe_state.zone2Members = 0;
                    mpe_state.zone2Active = false;
                    mpe_state.zone2ManagerPitchSens = 0.f;
                    mpe_state.zone2MemberPitchSens = 0.f;
                }
                // reduce the zone 2 member channels if they overlap zone 1 member channels
                else if (mpe_state.zone2Active) {
                    mpe_state.zone2Members = MIN(14 - mpe_state.zone1Members.load(), mpe_state.zone2Members.load());
                }
            }
            else if (channel == 15) {
                mpe_state.zone2Members = _lastDataMsb[channel];
                if (mpe_state.zone2Members == 0) {
                    mpe_state.zone2Active = false;
                    mpe_state.zone2ManagerPitchSens = 0.f;
                    mpe_state.zone2MemberPitchSens = 0.f;
                }
                else {
                    mpe_state.zone2Active = true;
                    mpe_state.zone2ManagerPitchSens = 2.f;
                    mpe_state.zone2MemberPitchSens = 48.f;
                }
                
                // disable zone 1 when zone 2 uses all member channels
                if (mpe_state.zone2Members >= 14) {
                    mpe_state.zone1Members = 0;
                    mpe_state.zone1Active = false;
                    mpe_state.zone1ManagerPitchSens = 0.f;
                    mpe_state.zone1MemberPitchSens = 0.f;
                }
                // reduce the zone 1 member channels if they overlap zone 2 member channels
                else if (mpe_state.zone1Active) {
                    mpe_state.zone1Members = MIN(14 - mpe_state.zone2Members.load(), mpe_state.zone1Members.load());
                }
            }
            
            mpe_state.enabled = (mpe_state.zone1Active || mpe_state.zone2Active);
            
            _state->processedUIMpeConfigChange.clear();
            
            break;
        }
    }
}

- (void)recordMidiMessage:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        // track the MPE Configuration Message and RPN 0 PitchBend sensitivity
        // when recording is enabled for this track
        // we only look at CC messages for this
        if (_state->track[_ordinal].recordEnabled.test() &&
            message.length == 3 &&
            (message.data[0] & 0xf0) == 0xb0) {
            uint8_t channel = (message.data[0] & 0x0f);
            uint8_t cc_num = message.data[1];
            uint8_t cc_val = message.data[2];
            
            switch (cc_num) {
                // RPN parameter number
                case 100:
                    _lastRpnLsb[channel] = cc_val;
                    break;
                case 101:
                    _lastRpnMsb[channel] = cc_val;
                    break;
                // RPN parameter value
                case 6:
                    if (_lastRpnMsb[channel] != 0x7f || _lastRpnLsb[channel] != 0x7f) {
                        _lastDataMsb[channel] = cc_val;
                        _lastDataLsb[channel] = 0;
                        
                        [self handleMidiRPNValue:channel];
                    }
                    break;
                case 38:
                    if (_lastRpnMsb[channel] != 0x7f || _lastRpnLsb[channel] != 0x7f) {
                        _lastDataLsb[channel] = cc_val;
                        
                        [self handleMidiRPNValue:channel];
                    }
                    break;
            }
        }
        
        // don't record if record enable isn't active
        if (!_record || !_recordingData) {
            return;
        }
        
        // if punch in/out is enabled, only record during the punch in/out positions
        if (_state->inactivePunchInOut()) {
            return;
        }

        // auto start the recording on the first received message
        // if the recording hasn't started yet
        if (_recordingData->empty() && _state->transportStartSampleSeconds == 0.0) {
            if (_delegate) {
                _state->transportStartSampleSeconds = message.timeSampleSeconds - _state->playPositionBeats * _state->beatsToSeconds;
                [_delegate startRecord];
            }
        }

        // calculate timing offsets
        double offset_seconds = message.timeSampleSeconds - _state->transportStartSampleSeconds;
        double offset_beats = offset_seconds * _state->secondsToBeats;

        // add message to the recording
        RecordedMidiMessage recorded_message;
        recorded_message.offsetBeats = offset_beats;
        recorded_message.length = message.length;
        recorded_message.data[0] = message.data[0];
        recorded_message.data[1] = message.data[1];
        recorded_message.data[2] = message.data[2];
        _recordingData->addMessageToBeat(recorded_message);
        _state->track[_ordinal].hasRecordedEvents.test_and_set();
        
        // update the preview
        _recordingPreview->updateWithMessage(recorded_message);
    });
}

- (void)clear {
    dispatch_barrier_sync(_dispatchQueue, ^{
        _record = NO;

        if (_delegate) {
            [_delegate invalidateRecording:_ordinal];
        }

        _recordingData.reset(new MidiRecordedData());
        _recordingPreview.reset(new MidiRecordedPreview());
    });
}

#pragma mark Getters and Setter

- (void)setState:(MidiRecorderState*)state {
    _state = state;
}

- (double)activeDuration {
    __block double duration = 0.0;
    
    dispatch_sync(_dispatchQueue, ^{
        if (_record == YES) {
            duration = _recordingData->getDuration();
        }
        if (_state && _state->track[_ordinal].recordedData) {
            duration = MAX(duration, _state->track[_ordinal].recordedData->getDuration());
        }
    });
    
    return duration;
}

#pragma mark MidiPreviewProvider

- (unsigned long)previewPixelCount {
    unsigned long count = 0;
    
    if (_state && _state->track[_ordinal].recordedPreview) {
        count = _state->track[_ordinal].recordedPreview->getPixels().size();
    }
    
    if (_record == YES) {
        count = MAX(count, _recordingPreview->getPixels().size());
    }
    
    return count;
}

- (PreviewPixelData)previewPixelData:(int)pixel {
    PreviewPixelData data;
    
    if (_state && _state->track[_ordinal].recordedPreview) {
        MidiRecordedPreview* recorded_preview = _state->track[_ordinal].recordedPreview.get();
        if (recorded_preview->hasStarted() && pixel >= recorded_preview->getStartPixel() && pixel < recorded_preview->getPixels().size()) {
            data = recorded_preview->getPixels()[pixel];
            data.dirty = false;
        }
    }
    
    if (_record == YES) {
        if (_recordingPreview->hasStarted() && pixel >= _recordingPreview->getStartPixel() && pixel < _recordingPreview->getPixels().size()) {
            data = _recordingPreview->getPixels()[pixel];
            data.dirty = true;
        }
    }
    
    return data;
}

- (BOOL)refreshPreviewBeat:(int)beat {
    if (_state == nullptr) {
        return YES;
    }
    int play_beat = _state->playPositionBeats;
    return _record == YES && (play_beat == beat || play_beat - 1 == beat);
}

@end
