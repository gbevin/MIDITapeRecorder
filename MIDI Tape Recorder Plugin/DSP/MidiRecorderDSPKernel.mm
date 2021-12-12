//
//  MidiRecorderDSPKernel.cpp
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorderDSPKernel.h"

#include <iostream>

#include "Constants.h"
#include "QueuedMidiMessage.h"

MidiRecorderDSPKernel::MidiRecorderDSPKernel() : _state() {
    TPCircularBufferInit(&_state.midiBuffer, 16384);
    
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        for (int ch = 0; ch < 16; ++ch) {
            for (int n = 0; n < 128; ++n) {
                _noteStates[t][ch][n] = false;
            }
        }
        
        _noteCounts[t] = 0;
    }
}

void MidiRecorderDSPKernel::cleanup() {
    TPCircularBufferCleanup(&_state.midiBuffer);
    _ioState.reset();
}

bool MidiRecorderDSPKernel::isBypassed() {
    return _bypassed;
}

void MidiRecorderDSPKernel::setBypass(bool shouldBypass) {
    _bypassed = shouldBypass;
}

void MidiRecorderDSPKernel::rewind() {
    // turn off recording
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        _state.track[t].recording.clear();
    }
    _state.processedUIEndRecord.clear();

    // rewind to start position or complete beginning
    double start_position = _state.startPositionBeats.load();
    if (_state.playPositionBeats > start_position) {
        _state.playPositionBeats = start_position;
    }
    else {
        _state.playPositionBeats = 0.0;
    }
    
    // ensure there are no lingering notes
    turnOffAllNotes();
}

void MidiRecorderDSPKernel::sendRpnMessage(uint8_t cable, uint8_t channel, uint16_t number, uint16_t value) {
    if (cable >= MIDI_TRACKS || channel > 0xf) {
        return;
    }
    
    if (_ioState.midiOutputEventBlock) {
        unsigned number_msb = (number & 0x3fff) >> 7;
        unsigned number_lsb = number & 0x7f;
        unsigned value_msb = (value & 0x3fff) >> 7;
        unsigned value_lsb = value & 0x7f;

        uint8_t data[3] = { 0, 0, 0 };
        data[0] = 0xb0 | channel;
        
        Float64 time = _ioState.timestamp->mSampleTime;
        data[1] = 0x65; data[2] = number_msb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x64; data[2] = number_lsb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x06; data[2] = value_msb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x26; data[2] = value_lsb;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x65; data[2] = 0x7f;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
        data[1] = 0x64; data[2] = 0x7f;
        _ioState.midiOutputEventBlock(time, cable, 3, &data[0]);
    }
}

void MidiRecorderDSPKernel::sendMCM(int t) {
    MPEState& mpe_state = _state.track[t].mpeState;
    if (!mpe_state.enabled) {
        return;
    }
    
    _state.track[t].processedActivityOutput.clear();

    if (mpe_state.zone1Active) {
        sendRpnMessage(t, 0, 0x6, mpe_state.zone1Members.load() << 7);
        sendRpnMessage(t, 0, 0x0, (int)mpe_state.zone1ManagerPitchSens.load() << 7);
        for (int i = 0; i < mpe_state.zone1Members.load(); ++i) {
            sendRpnMessage(t, 0x1 + i, 0x0, (int)mpe_state.zone1MemberPitchSens.load() << 7);
        }
    }
    if (mpe_state.zone2Active) {
        sendRpnMessage(t, 0xf, 0x6, mpe_state.zone2Members.load() << 7);
        sendRpnMessage(t, 0xf, 0x0, (int)mpe_state.zone2ManagerPitchSens.load() << 7);
        for (int i = 0; i < mpe_state.zone2Members.load(); ++i) {
            sendRpnMessage(t, 0xe - i, 0x0, (int)mpe_state.zone2MemberPitchSens.load() << 7);
        }
    }
}

void MidiRecorderDSPKernel::play() {
    if (_isPlaying == NO) {
        _state.processedStopAndRewind.test_and_set();
        _state.processedUIStopAndRewind.test_and_set();

        // send out MPE configuration messages based on each track's MPE mode
        if (_state.sendMpeConfigOnPlay.test()) {
            for (int t = 0; t < MIDI_TRACKS; ++t) {
                if (!_state.track[t].recording.test()) {
                    sendMCM(t);
                }
            }
        }

        _isPlaying = YES;
    }
}

void MidiRecorderDSPKernel::stop() {
    _state.transportStartSampleSeconds = 0.0;
    _isPlaying = NO;
}

void MidiRecorderDSPKernel::setParameter(AUParameterAddress address, AUValue value) {
    bool set = bool(value);
    switch (address) {
        case ID_RECORD_1:
            if (set) _state.track[0].recordEnabled.test_and_set();
            else     _state.track[0].recordEnabled.clear();
            break;
        case ID_RECORD_2:
            if (set) _state.track[1].recordEnabled.test_and_set();
            else     _state.track[1].recordEnabled.clear();
            break;
        case ID_RECORD_3:
            if (set) _state.track[2].recordEnabled.test_and_set();
            else     _state.track[2].recordEnabled.clear();
            break;
        case ID_RECORD_4:
            if (set) _state.track[3].recordEnabled.test_and_set();
            else     _state.track[3].recordEnabled.clear();
            break;
        case ID_MONITOR_1:
            if (set) _state.track[0].monitorEnabled.test_and_set();
            else     _state.track[0].monitorEnabled.clear();
            break;
        case ID_MONITOR_2:
            if (set) _state.track[1].monitorEnabled.test_and_set();
            else     _state.track[1].monitorEnabled.clear();
            break;
        case ID_MONITOR_3:
            if (set) _state.track[2].monitorEnabled.test_and_set();
            else     _state.track[2].monitorEnabled.clear();
            break;
        case ID_MONITOR_4:
            if (set) _state.track[3].monitorEnabled.test_and_set();
            else     _state.track[3].monitorEnabled.clear();
            break;
        case ID_MUTE_1:
            if (set) _state.track[0].muteEnabled.test_and_set();
            else     _state.track[0].muteEnabled.clear();
            break;
        case ID_MUTE_2:
            if (set) _state.track[1].muteEnabled.test_and_set();
            else     _state.track[1].muteEnabled.clear();
            break;
        case ID_MUTE_3:
            if (set) _state.track[2].muteEnabled.test_and_set();
            else     _state.track[2].muteEnabled.clear();
            break;
        case ID_MUTE_4:
            if (set) _state.track[3].muteEnabled.test_and_set();
            else     _state.track[3].muteEnabled.clear();
            break;
        case ID_REWIND:
            if (set) _state.rewind.test_and_set();
            else     _state.rewind.clear();
            break;
        case ID_PLAY:
            if (set) _state.play.test_and_set();
            else     _state.play.clear();
            break;
        case ID_RECORD:
            if (set) _state.record.test_and_set();
            else     _state.record.clear();
            break;
        case ID_REPEAT:
            if (set) _state.repeat.test_and_set();
            else     _state.repeat.clear();
            break;
        case ID_GRID:
            if (set) _state.grid.test_and_set();
            else     _state.grid.clear();
            break;
        case ID_CHASE:
            if (set) _state.chase.test_and_set();
            else     _state.chase.clear();
            break;
        case ID_PUNCH_INOUT:
            if (set) _state.punchInOut.test_and_set();
            else     _state.punchInOut.clear();
            break;
    }
}

AUValue MidiRecorderDSPKernel::getParameter(AUParameterAddress address) {
    // Return the goal. It is not thread safe to return the ramping value.
    switch (address) {
        case ID_RECORD_1:
            return _state.track[0].recordEnabled.test();
        case ID_RECORD_2:
            return _state.track[1].recordEnabled.test();
        case ID_RECORD_3:
            return _state.track[2].recordEnabled.test();
        case ID_RECORD_4:
            return _state.track[3].recordEnabled.test();
        case ID_MONITOR_1:
            return _state.track[0].monitorEnabled.test();
        case ID_MONITOR_2:
            return _state.track[1].monitorEnabled.test();
        case ID_MONITOR_3:
            return _state.track[2].monitorEnabled.test();
        case ID_MONITOR_4:
            return _state.track[3].monitorEnabled.test();
        case ID_MUTE_1:
            return _state.track[0].muteEnabled.test();
        case ID_MUTE_2:
            return _state.track[1].muteEnabled.test();
        case ID_MUTE_3:
            return _state.track[2].muteEnabled.test();
        case ID_MUTE_4:
            return _state.track[3].muteEnabled.test();
        case ID_REWIND:
            return _state.rewind.test();
        case ID_PLAY:
            return _state.play.test();
        case ID_RECORD:
            return _state.record.test();
        case ID_REPEAT:
            return _state.repeat.test();
        case ID_GRID:
            return _state.grid.test();
        case ID_CHASE:
            return _state.chase.test();
        case ID_PUNCH_INOUT:
            return _state.punchInOut.test();
        default:
            return 0.f;
    }
}

void MidiRecorderDSPKernel::setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {
    _inBufferList = inBufferList;
    _outBufferList = outBufferList;
}

void MidiRecorderDSPKernel::handleBufferStart(double timeSampleSeconds) {
    QueuedMidiMessage message;
    message.timeSampleSeconds = timeSampleSeconds;
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, sizeof(QueuedMidiMessage));
}

void MidiRecorderDSPKernel::handleScheduledTransitions(double timeSampleSeconds) {
    if (_ioState.transportChanged) {
        if (_ioState.transportMoving) {
            _state.processedPlay.clear();
            _state.processedUIPlay.clear();
        }
        else {
            _state.processedStop.clear();
            _state.processedUIStop.clear();
        }
    }
    
    // we rely on the single-threaded nature of the audio callback thread to coordinate
    // important state transitions at the beginning of the callback, before anything else
    // this prevents split-state conditions to change semantics in the middle of processing
    
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        // begin recording
        if (!_state.processedBeginRecording[t].test_and_set()) {
            turnOffAllNotesForTrack(t);
            _state.track[t].recording.test_and_set();
        }

        // end recording
        if (!_state.processedEndRecording[t].test_and_set()) {
            _state.track[t].recording.clear();
        }
        
        // ensure notes off
        if (!_state.processedNotesOff[t].test_and_set()) {
            turnOffAllNotesForTrack(t);
        }
        
        // invalidate
        if (!_state.processedInvalidate[t].test_and_set()) {
            MidiTrackState& track_state = _state.track[t];
            track_state.recordedMessages.reset();
            track_state.recordedBeatToIndex.reset();
            track_state.recordedPreview.reset();
            track_state.recordedLength = 0;
            track_state.recordedDuration = 0.0;
        }

        // send MCM
        if (!_state.processedSendMCM[t].test_and_set()) {
            sendMCM(t);
        }
    }
    
    // rewind
    if (!_state.processedRewind.test_and_set()) {
        if (_isPlaying) {
            _state.transportStartSampleSeconds = timeSampleSeconds;
        }
        rewind();
    }

    // play
    if (!_state.processedPlay.test_and_set()) {
        if (_state.transportStartSampleSeconds == 0.0) {
            _state.transportStartSampleSeconds = timeSampleSeconds - _state.playPositionBeats * _state.beatsToSeconds;
        }
        play();
    }

    // stop
    if (!_state.processedStop.test_and_set()) {
        stop();
    }

    // stop and rewind
    if (!_state.processedStopAndRewind.test_and_set()) {
        stop();
        rewind();
    }

    // reach end
    if (!_state.processedReachEnd.test_and_set()) {
        _isPlaying = NO;
        _state.processedUIStopAndRewind.clear();
    }
}

void MidiRecorderDSPKernel::process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) {
    for (int channel = 0; channel < _ioState.channelCount; ++channel) {
        if (_inBufferList->mBuffers[channel].mData ==  _outBufferList->mBuffers[channel].mData) {
            continue;
        }
        
        for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            const int frameOffset = int(frameIndex + bufferOffset);
            const float* in  = (float*)_inBufferList->mBuffers[channel].mData  + frameOffset;
            float* out = (float*)_outBufferList->mBuffers[channel].mData + frameOffset;
            *out = *in;
        }
    }
}

void MidiRecorderDSPKernel::handleParameterEvent(AUParameterEvent const& parameterEvent) {
    // we only have parameter state switches, so we don't need to ramp and it's all related to
    // user interface funtionality, so being sample accurate is not critical either
    setParameter(parameterEvent.parameterAddress, parameterEvent.value);
}

void MidiRecorderDSPKernel::handleMIDIEvent(AUMIDIEvent const& midiEvent) {
    if (midiEvent.cable < 0 || midiEvent.cable >= MIDI_TRACKS) {
        return;
    }

    if (isBypassed()) {
        // pass through MIDI events
        if (_ioState.midiOutputEventBlock) {
            passThroughMIDIEvent(midiEvent, midiEvent.cable);
        }
    }
    else {
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            MidiTrackState& track_state = _state.track[t];
            
            if (track_state.monitorEnabled.test() && !track_state.muteEnabled.test() && track_state.sourceCable == midiEvent.cable) {
                _state.track[t].processedActivityOutput.clear();
                passThroughMIDIEvent(midiEvent, t);
            }
        }
        
        // only queue channel voice messages
        if ((midiEvent.data[0] & 0xf0) != 0xf0) {
            queueMIDIEvent(midiEvent);
        }
    }
}

void MidiRecorderDSPKernel::passThroughMIDIEvent(AUMIDIEvent const& midiEvent, int cable) {
    if (_ioState.midiOutputEventBlock) {
        Float64 frame_offset = midiEvent.eventSampleTime - _ioState.timestamp->mSampleTime;
        _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + frame_offset, cable, midiEvent.length, midiEvent.data);
    }
}

void MidiRecorderDSPKernel::processOutput() {
    if (!_isPlaying) {
        turnOffAllNotes();
    }
    else {
        const double frames_seconds = double(_ioState.frameCount) / _ioState.sampleRate;
        const double frames_beats = frames_seconds * _state.secondsToBeats;

        // calculate the range of beat positions between which the recorded messages
        // should be played
        double play_position = _state.playPositionBeats;
        // if the host transport is moving, make that take precedence
        if (_ioState.transportMoving) {
            if (_state.repeat.test()) {
                double effective_max_duration = _state.stopPositionBeats.load() - _state.startPositionBeats.load();
                play_position = fmod(_ioState.currentBeatPosition, effective_max_duration);
            }
            else {
                play_position = _ioState.currentBeatPosition;
            }
            play_position += _state.startPositionBeats.load();
        }
        double beatrange_begin = play_position;
        double beatrange_end = beatrange_begin + frames_beats;

        // if there's a significant discontinuity between the output processing calls,
        // forcible ensure that all notes are turned off
        if (ABS(play_position - _state.playPositionBeats) >= frames_beats) {
            turnOffAllNotes();
        }
        
        // store the play duration for the next process call
        _state.playPositionBeats = beatrange_end;
        
        int playing_tracks = 0;
        bool reached_end = YES;

        // process all the messages on all the tracks
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            MidiTrackState& track_state = _state.track[t];
            
            // don't play if the track is recording
            if (track_state.recording.test()) {
                // no-op
            }
            // play when there are recorded messages
            else if (track_state.recordedMessages && track_state.recordedLength > 0) {
                playing_tracks += 1;
                
                uint64_t play_counter = track_state.recordedLength;

                int beat_begin = (int)beatrange_begin;
                if (beat_begin < track_state.recordedBeatToIndex->size()) {
                    play_counter = (*track_state.recordedBeatToIndex)[beat_begin];
                }

                while (play_counter < track_state.recordedLength) {
                    const RecordedMidiMessage& message = (*track_state.recordedMessages)[play_counter];
                    play_counter += 1;
                    
                    // check if the message is outdated
                    if (message.offsetBeats < beatrange_begin) {
                        continue;
                    }
                    // check if the time offset of the message falls within the advancement of the playhead
                    else if (message.offsetBeats < beatrange_end) {
                        // if the track is not muted and a MIDI output block exists,
                        // send the message
                        if (!track_state.muteEnabled.test() && _ioState.midiOutputEventBlock) {
                            const double offset_seconds = (message.offsetBeats - beatrange_end) * _state.beatsToSeconds;
                            const double offset_samples = offset_seconds * _ioState.sampleRate;
                            
                            // indicate output activity
                            track_state.processedActivityOutput.clear();
                            
                            // track note on/off states
                            trackNotesForTrack(t, message);

                            // send the MIDI output message
                            _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + offset_samples,
                                                          t, message.length, &message.data[0]);
                        }
                        // if the track is muted, ensure we have no lingering note on messages
                        else {
                            turnOffAllNotesForTrack(t);
                        }
                    }
                    // stop playing recorded messages if the one we processed is scheduled for later
                    else {
                        break;
                    }
                }
                
                if (beatrange_end < _state.stopPositionBeats.load()) {
                    reached_end = NO;
                }
            }
        }
        
        if (playing_tracks != 0 && reached_end) {
            if (_state.repeat.test()) {
                _state.processedRewind.clear();
            }
            else {
                _state.processedReachEnd.clear();
            }
        }
    }
}

void MidiRecorderDSPKernel::trackNotesForTrack(int track, const RecordedMidiMessage& message) {
    int status = message.data[0];
    int type = status & 0xf0;
    int chan = (status & 0x0f);
    int val = message.data[2];
    if (type == MIDI_NOTE_OFF ||
        (type == MIDI_NOTE_ON && val == 0)) {
        if (_noteStates[track][chan][message.data[1]] == true &&
            _noteCounts[track] > 0) {
            _noteCounts[track] -= 1;
        }
        _noteStates[track][chan][message.data[1]] = false;
    }
    else if (type == MIDI_NOTE_ON) {
        if (_noteStates[track][chan][message.data[1]] == false) {
            _noteCounts[track] += 1;
        }
        _noteStates[track][chan][message.data[1]] = true;
    }
}

void MidiRecorderDSPKernel::turnOffAllNotes() {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        turnOffAllNotesForTrack(t);
    }
}

void MidiRecorderDSPKernel::turnOffAllNotesForTrack(int track) {
    if (track < 0 || track >= MIDI_TRACKS) {
        return;
    }
    
    if (_noteCounts[track] == 0) {
        return;
    }
    
    if (_ioState.midiOutputEventBlock) {
        for (int ch = 0; ch < 16; ++ch) {
            for (int n = 0; n < 128; ++n) {
                if (_noteStates[track][ch][n]) {
                    uint8_t data[3];
                    data[0] = MIDI_NOTE_OFF | ch;
                    data[1] = n;
                    data[2] = 0x07;
                    _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + _ioState.frameCount,
                                                  track, 3, &data[0]);
                    _noteStates[track][ch][n] = false;
                    _noteCounts[track] -= 1;
                };
            }
        }
    }
}

void MidiRecorderDSPKernel::queueMIDIEvent(AUMIDIEvent const& midiEvent) {
    QueuedMidiMessage message;
    message.timeSampleSeconds = double(midiEvent.eventSampleTime) / _ioState.sampleRate;
    message.cable = midiEvent.cable;
    message.length = midiEvent.length;
    message.data[0] = midiEvent.data[0];
    message.data[1] = midiEvent.data[1];
    message.data[2] = midiEvent.data[2];
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, sizeof(QueuedMidiMessage));
}
