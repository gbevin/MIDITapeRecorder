//
//  MidiTrackRecorder.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiTrackRecorder.h"

#import <CoreAudioKit/CoreAudioKit.h>

#include "Constants.h"
#include "Logging.h"
#include "MidiFileConverter.h"
#include "MidiHelper.h"
#include "MidiRecorderState.h"
#include "RecordedTrackDict.h"

#define DEBUG_MIDI_RECORD 0

@implementation MidiTrackRecorder {
    dispatch_queue_t _dispatchQueue;
    
    MidiRecorderState* _state;
    
    int16_t _lastRpnMsb[MIDI_CHANNELS];
    int16_t _lastRpnLsb[MIDI_CHANNELS];
    int16_t _lastDataMsb[MIDI_CHANNELS];
    int16_t _lastDataLsb[MIDI_CHANNELS];

    double _recordingStartSampleSeconds;
    std::unique_ptr<MidiRecordedData> _recordingData;
    std::unique_ptr<MidiRecordedPreview> _recordingPreview;

    // last playhead offset we've seen in the record stream (pings and messages).
    // when it jumps backwards we've hit the loop wrap, which is where we capture
    // a pending loop-record pass so each message ends up in the right pass.
    double _lastPassOffsetBeats;

    // set when a take ends while the previous loop pass is still waiting to be
    // blended: we keep the final partial pass in the recording buffers until
    // flushDeferredFinish can hand it off. atomic so the UI render loop can
    // check it cheaply without going through the dispatch queue.
    std::atomic<bool> _finishAwaitingBlend;

    // set once a continuous loop-record take has captured at least one full
    // pass. after that every new pass covers the whole loop, so we pin its
    // start to the loop start for the overdub blend.
    BOOL _takeHasCapturedPass;
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
        
        _recordingStartSampleSeconds = 0.0;
        _recordingData.reset(new MidiRecordedData());
        _recordingPreview.reset(new MidiRecordedPreview());
        _lastPassOffsetBeats = 0.0;
        _finishAwaitingBlend = false;
        _takeHasCapturedPass = NO;
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

        // changing the record state cancels any pending loop-record cycle capture
        _state->processedCaptureRecording[_ordinal].test_and_set();
        _lastPassOffsetBeats = 0.0;
        _takeHasCapturedPass = NO;

        // hand off (or drop) a final pass that was still deferred when the
        // previous take ended, before this new take starts using the buffers
        if (record == YES && _finishAwaitingBlend.load()) {
            _finishAwaitingBlend = false;

            MidiTrackState& track_state = _state->track[_ordinal];
            if (track_state.pendingRecordedData == nullptr && _recordingData->getDuration() > 0.0) {
                track_state.pendingRecordedData = std::move(_recordingData);
                track_state.pendingRecordedPreview = std::move(_recordingPreview);
                _state->processedBlendRecording[_ordinal].clear();
            }

            _recordingStartSampleSeconds = 0.0;
            _recordingData.reset(new MidiRecordedData());
            _recordingPreview.reset(new MidiRecordedPreview());
        }

        if (record == NO) {
            if (_recordingData->getDuration() > 0.0) {
                MidiTrackState& track_state = _state->track[_ordinal];

                // when recording is stopped, we move the recording data to the recorded data
                if (track_state.pendingRecordedData == nullptr) {
                    auto recorded_data = std::move(_recordingData);
                    auto recorded_preview = std::move(_recordingPreview);

                    _recordingStartSampleSeconds = 0.0;
                    _recordingData.reset(new MidiRecordedData());
                    _recordingPreview.reset(new MidiRecordedPreview());

                    track_state.pendingRecordedData = std::move(recorded_data);
                    track_state.pendingRecordedPreview = std::move(recorded_preview);
                }
                // if the stop raced a loop-record cycle capture whose full pass
                // hasn't been blended yet, hold on to this partial pass and hand
                // it off once the kernel has taken the previous one (flushDeferredFinish)
                else {
                    _finishAwaitingBlend = true;
                }

                // reset state
                _state->processedResetRecording[_ordinal].test_and_set();
                track_state.hasRecordedEvents.clear();

                finish_recording = YES;
            }
        }
    });

    if (_delegate && finish_recording) {
        [_delegate finishRecording:_ordinal];
    }
}

#pragma mark State

- (NSMutableDictionary*)recordedAsDict {
    __block NSMutableDictionary* result = [NSMutableDictionary new];
    dispatch_barrier_sync(_dispatchQueue, ^{
        MidiTrackState& track_state = _state->track[_ordinal];
        NSMutableDictionary* mpe_dict = [NSMutableDictionary new];
        [mpe_dict addEntriesFromDictionary:@{
            @"zone1Members" : @(track_state.mpeState.zone1Members.load()),
            @"zone1ManagerPitchSens" : @(track_state.mpeState.zone1ManagerPitchSens.load()),
            @"zone1MemberPitchSens" : @(track_state.mpeState.zone1MemberPitchSens.load()),
            @"zone2Members" : @(track_state.mpeState.zone2Members.load()),
            @"zone2ManagerPitchSens" : @(track_state.mpeState.zone2ManagerPitchSens.load()),
            @"zone2MemberPitchSens" : @(track_state.mpeState.zone2MemberPitchSens.load()),
        }];
        
        auto recorded_data = track_state.recordedData.get();
        if (recorded_data == nullptr) {
            [result addEntriesFromDictionary:@{
                kRecordedTrackKeyMPE : mpe_dict
            }];
        }
        else {
            NSMutableData* recorded_object = [NSMutableData new];
            for (RecordedDataVector& beat : recorded_data->getBeats()) {
                recordedTrackBlobAppendMessages(recorded_object, beat.data(), beat.size());
            }
            [result addEntriesFromDictionary:@{
                kRecordedTrackKeyRecorded : recorded_object,
                kRecordedTrackKeyDuration : @(recorded_data->getDuration()),
                kRecordedTrackKeyMPE : mpe_dict,
                kRecordedTrackKeyFormat : @(kRecordedTrackFormatVersion)
            }];
        }
    });
    return result;
}

- (void)dictToRecorded:(NSDictionary*)dict {
    // content written by a newer wire format than this build understands is
    // left alone rather than misread
    if (!recordedTrackDictIsCompatible(dict)) {
        return;
    }

    dispatch_barrier_sync(_dispatchQueue, ^{
        // restored content replaces whatever a deferred finish would blend into
        [self dropDeferredFinishLocked];

        std::unique_ptr<MidiRecordedData> recorded_data(new MidiRecordedData());
        double recorded_duration = 0.0;

        const RecordedMidiMessage* messages = nullptr;
        NSUInteger count = 0;
        if (recordedTrackBlobGetMessages([dict objectForKey:kRecordedTrackKeyRecorded], messages, count)) {
            for (NSUInteger i = 0; i < count; ++i) {
                RecordedMidiMessage message = messages[i];
                recorded_data->addMessageToBeat(message);
            }
        }

        id duration = [dict objectForKey:kRecordedTrackKeyDuration];
        if (duration) {
            recorded_duration = [duration doubleValue];
            if (_state->autoTrimRecordings.test()) {
                recorded_duration = ceil(recorded_duration);
            }
            recorded_data->increaseDuration(recorded_duration);
        }
        
        NSDictionary* mpe = [dict objectForKey:kRecordedTrackKeyMPE];
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

    // gather the recorded messages and hand the SMF encoding to the shared converter
    midifile::Track track;
    for (RecordedDataVector& beat : recorded_data->getBeats()) {
        for (RecordedMidiMessage& message : beat) {
            track.messages.push_back(message);
        }
    }
    track.durationBeats = recorded_data->getDuration();

    return midifile::writeTrackChunk(track, _state->tempo);
}

- (BOOL)midiTrackChunkToRecorded:(NSData*)track division:(uint16_t)division{
    if (track == nil || track.length == 0 || division == 0) {
        return NO;
    }

    // parse the SMF track bytes into messages with the shared converter
    __block midifile::Track parsed;
    if (!midifile::parseTrackChunk(track, division, parsed)) {
        // chunks without note content (e.g. a conductor track) don't take up a
        // destination track; the import driver decides whether the destination
        // is cleared instead (see importEmptyTrack)
        return NO;
    }

    [self importParsedTrack:parsed];
    return YES;
}

// replaces the track's content with emptiness through the regular import path,
// so importing a track that carries no note content clears the destination
// rather than silently doing nothing
- (void)importEmptyTrack {
    __block midifile::Track parsed;
    [self importParsedTrack:parsed];
}

- (void)importParsedTrack:(midifile::Track&)parsed {
    dispatch_barrier_sync(_dispatchQueue, ^{
        // imported content replaces whatever a deferred finish would blend into
        [self dropDeferredFinishLocked];

        // build the recorded data and preview from the parsed messages
        std::unique_ptr<MidiRecordedData> recorded_data(new MidiRecordedData());
        std::unique_ptr<MidiRecordedPreview> recorded_preview(new MidiRecordedPreview());

        for (RecordedMidiMessage& msg : parsed.messages) {
            recorded_data->addMessageToBeat(msg);
            recorded_preview->updateWithMessage(msg);
        }

        if (_state->autoTrimRecordings.test()) {
            double recorded_duration = ceil(parsed.durationBeats);
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

// hands off a final pass that had to wait for a racing loop-record blend to be
// taken by the kernel. driven from the UI render loop, since no more MIDI
// messages come through the recorder once recording has ended.
- (void)flushDeferredFinish {
    // fast path: nothing deferred (checked without entering the queue)
    if (!_finishAwaitingBlend.load()) {
        return;
    }

    dispatch_barrier_sync(_dispatchQueue, ^{
        if (!_finishAwaitingBlend.load()) {
            return;
        }

        MidiTrackState& track_state = _state->track[_ordinal];

        // the previous pass hasn't been blended yet; try again on the next tick
        if (track_state.pendingRecordedData != nullptr) {
            return;
        }

        _finishAwaitingBlend = false;

        if (_recordingData->getDuration() > 0.0) {
            auto recorded_data = std::move(_recordingData);
            auto recorded_preview = std::move(_recordingPreview);

            _recordingStartSampleSeconds = 0.0;
            _recordingData.reset(new MidiRecordedData());
            _recordingPreview.reset(new MidiRecordedPreview());

            track_state.pendingRecordedData = std::move(recorded_data);
            track_state.pendingRecordedPreview = std::move(recorded_preview);

            _state->processedBlendRecording[_ordinal].clear();
        }
    });
}

// drops a deferred final pass when the content it would blend into is being
// replaced anyway (clear, crop, state restore, import).
// must be called on _dispatchQueue.
- (void)dropDeferredFinishLocked {
    if (!_finishAwaitingBlend.load()) {
        return;
    }

    _finishAwaitingBlend = false;
    _recordingStartSampleSeconds = 0.0;
    _recordingData.reset(new MidiRecordedData());
    _recordingPreview.reset(new MidiRecordedPreview());
}

// captures a pending loop-record pass when the message stream crosses the loop
// wrap. the kernel flags the capture at the wrap, and the first message that jumps
// back before the last one we saw belongs to the new cycle. the finished pass
// moves to the track's pending data for the kernel to blend as an overdub, and
// recording carries on into a fresh pass.
// must be called on _dispatchQueue.
- (void)captureLoopPassAtOffset:(double)offsetBeats {
    // nothing to do without a pending capture request
    if (_state->processedCaptureRecording[_ordinal].test()) {
        return;
    }

    // wait for the first message that belongs to the new cycle
    if (_lastPassOffsetBeats <= 0.0 || offsetBeats >= _lastPassOffsetBeats) {
        return;
    }

    MidiTrackState& track_state = _state->track[_ordinal];

    // an earlier pass hasn't been blended yet; retry on the next message
    if (track_state.pendingRecordedData != nullptr) {
        return;
    }

    _state->processedCaptureRecording[_ordinal].test_and_set();
    _lastPassOffsetBeats = 0.0;

    if (_recordingData->getDuration() > 0.0) {
        // the pass ran past the loop end, but its duration only reaches the last
        // queued message; stretch it to the end of the loop window (like a final
        // ping at the boundary would have) so the overdub blend replaces the whole
        // span instead of leaving an old tail behind
        double capture_stop = _state->stopPositionBeats;
        if (_state->punchInOut.test()) {
            capture_stop = MIN(capture_stop, _state->punchOutPositionBeats.load());
        }
        if (capture_stop > 0.0) {
            _recordingData->increaseDuration(capture_stop);
            _recordingData->populateUpToBeat(_recordingData->getDuration());
            if (_recordingPreview) {
                _recordingPreview->setStartIfNeeded(_recordingData->getStart());
                _recordingPreview->updateWithOffsetBeats(capture_stop);
            }
        }

        auto recorded_data = std::move(_recordingData);
        auto recorded_preview = std::move(_recordingPreview);

        _recordingStartSampleSeconds = 0.0;
        _recordingData.reset(new MidiRecordedData());
        _recordingPreview.reset(new MidiRecordedPreview());

        track_state.pendingRecordedData = std::move(recorded_data);
        track_state.pendingRecordedPreview = std::move(recorded_preview);

        // the next pass starts right at the loop wrap (or punch-in); pin its start
        // so its own blend covers the head of the loop instead of starting at the
        // first message after the wrap
        [self pinPassStartLocked];
        _takeHasCapturedPass = YES;

        // cancel any pending no-events reset and clear the per-cycle event marker
        _state->processedResetRecording[_ordinal].test_and_set();
        track_state.hasRecordedEvents.clear();

        _state->processedBlendRecording[_ordinal].clear();
    }
}

// pins a fresh pass's start to the loop start (or punch-in), so its overdub
// blend covers the head of the loop instead of starting at the first message
// or ping after the wrap. must be called on _dispatchQueue.
- (void)pinPassStartLocked {
    double pass_start = _state->startPositionBeats;
    if (_state->punchInOut.test()) {
        pass_start = MAX(pass_start, _state->punchInPositionBeats.load());
    }
    _recordingData->setStartIfNeeded(pass_start);
    _recordingPreview->setStartIfNeeded(pass_start);
}

- (void)ping:(QueuedMidiMessage&)message {
    dispatch_barrier_sync(_dispatchQueue, ^{
        // don't record if record enable isn't active
        if (!_record || !_recordingData) {
            return;
        }
        
        // if transport isn't running, don't update recording
        if (_state->transportStartSampleSeconds == 0.0) {
            return;
        }
        
        // if recording hasn't started on the kernel side, don't update recording
        if (!_state->track[_ordinal].recording.test()) {
            return;
        }
        
        // remember the recording start time
        if (_recordingStartSampleSeconds == 0.0) {
            _recordingStartSampleSeconds = _state->transportStartSampleSeconds.load();
        }

        // capture a pending loop-record pass at the wrap point
        if (message.hasBeatTime) {
            [self captureLoopPassAtOffset:message.offsetBeats];
            _lastPassOffsetBeats = message.offsetBeats;
        }

        // we might have to reset the recording if no events were recorded and it wasn't manually stopped
        if (!_state->processedResetRecording[_ordinal].test_and_set()) {
            _recordingStartSampleSeconds = _state->transportStartSampleSeconds.load();
            _recordingData.reset(new MidiRecordedData());
            _recordingPreview.reset(new MidiRecordedPreview());
            _lastPassOffsetBeats = 0.0;
            // mid-take, after we've captured a loop pass, the fresh pass still
            // covers the whole loop; keep its start pinned so old material can't
            // survive at the head of the next blend
            if (_takeHasCapturedPass) {
                [self pinPassStartLocked];
            }
        }

        // if punch in/out is enabled, only record during the punch in/out positions
        if (_state->inactivePunchInOut()) {
            return;
        }

        // mark the first time the recording had processing, using the playhead
        // captured when this message was queued rather than the live value
        _recordingData->setStartIfNeeded(message.playPositionBeats);
        
        // update the recording duration even when there's no incoming messages
        if (message.hasBeatTime) {
            _recordingData->increaseDuration(message.offsetBeats);
        }
        else {
            _recordingData->increaseDuration((message.timeSampleSeconds - _recordingStartSampleSeconds) * _state->secondsToBeats);
        }
        
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
        BOOL auto_started_record = NO;
        if (_state->transportStartSampleSeconds == 0.0) {
            if (_recordingData->empty()) {
                if (_delegate) {
                    _recordingStartSampleSeconds = message.timeSampleSeconds - message.playPositionBeats * _state->beatsToSeconds;
                    _state->transportStartSampleSeconds = _recordingStartSampleSeconds;
                    [_delegate startRecord];
                    _state->track[_ordinal].recording.test_and_set();
                    auto_started_record = YES;
                }
            }
        }
        if (!auto_started_record) {
            // if recording hasn't started on the kernel side, don't record the messages
            if (!_state->track[_ordinal].recording.test()) {
                return;
            }
            // remember the recording start time
            else if (_recordingStartSampleSeconds == 0.0) {
                _recordingStartSampleSeconds = _state->transportStartSampleSeconds.load();
            }
        }

        // capture a pending loop-record pass at the wrap point, so this message
        // lands in the new cycle's pass
        if (message.hasBeatTime) {
            [self captureLoopPassAtOffset:message.offsetBeats];
            _lastPassOffsetBeats = message.offsetBeats;
        }

        // calculate timing offsets
        double offset_beats;
        if (message.hasBeatTime) {
            offset_beats = message.offsetBeats;
        }
        else {
            double offset_seconds = message.timeSampleSeconds - _recordingStartSampleSeconds;
            offset_beats = offset_seconds * _state->secondsToBeats;
        }

        // add message to the recording
        RecordedMidiMessage recorded_message;
        recorded_message.offsetBeats = std::max(0.0, offset_beats);
        recorded_message.length = message.length;
        recorded_message.data[0] = message.data[0];
        recorded_message.data[1] = message.data[1];
        recorded_message.data[2] = message.data[2];
#if DEBUG_MIDI_RECORD
        logRecordedMidiMessage(_ordinal, @"REC", recorded_message);
#endif
        _recordingData->addMessageToBeat(recorded_message);
        _state->track[_ordinal].hasRecordedEvents.test_and_set();
        
        // update the preview
        if (_recordingPreview) {
            _recordingPreview->setStartIfNeeded(_recordingData->getStart());
            _recordingPreview->updateWithMessage(recorded_message);
        }
    });
}

- (void)clear {
    dispatch_barrier_sync(_dispatchQueue, ^{
        _record = NO;

        // discarding the recording cancels any pending loop-record cycle capture
        // or deferred finish
        _state->processedCaptureRecording[_ordinal].test_and_set();
        _lastPassOffsetBeats = 0.0;
        _takeHasCapturedPass = NO;
        [self dropDeferredFinishLocked];

        if (_delegate) {
            [_delegate invalidateRecording:_ordinal];
        }

        _recordingStartSampleSeconds = 0.0;
        _recordingData.reset(new MidiRecordedData());
        _recordingPreview.reset(new MidiRecordedPreview());

        // the MPE configuration is detected from the recorded content, so reset it
        // along with the content it was derived from
        MPEState& mpe = _state->track[_ordinal].mpeState;
        mpe.enabled = false;
        mpe.zone1Active = false;
        mpe.zone1Members = 0;
        mpe.zone1ManagerPitchSens = 0.f;
        mpe.zone1MemberPitchSens = 0.f;
        mpe.zone2Active = false;
        mpe.zone2Members = 0;
        mpe.zone2ManagerPitchSens = 0.f;
        mpe.zone2MemberPitchSens = 0.f;
    });
}

- (void)crop {
    dispatch_barrier_sync(_dispatchQueue, ^{
        _record = NO;

        // cropping cancels any pending loop-record cycle capture or deferred finish
        _state->processedCaptureRecording[_ordinal].test_and_set();
        _lastPassOffsetBeats = 0.0;
        _takeHasCapturedPass = NO;
        [self dropDeferredFinishLocked];

        std::unique_ptr<MidiRecordedData> cropped_data(new MidiRecordedData());
        std::unique_ptr<MidiRecordedPreview> cropped_preview(new MidiRecordedPreview());

        MidiTrackState& track_state = _state->track[_ordinal];
        if (track_state.recordedData) {
            double start = _state->startPositionBeats.load();
            double stop = _state->stopPositionBeats.load();
            for (RecordedDataVector& beat : track_state.recordedData->getBeats()) {
                for (RecordedMidiMessage message : beat) {
                    if (message.offsetBeats >= start && message.offsetBeats <= stop) {
                        message.offsetBeats = MAX(message.offsetBeats - start, 0.0);
                        cropped_data->setStartIfNeeded(message.offsetBeats);
                        cropped_data->addMessageToBeat(message);
                        cropped_preview->updateWithMessage(message);
                    }
                }
            }
            cropped_data->increaseDuration(stop - start);
        }

        track_state.pendingRecordedData = std::move(cropped_data);
        track_state.pendingRecordedPreview = std::move(cropped_preview);
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
