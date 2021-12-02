//
//  MidiRecorderDSPKernel.cpp
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorderDSPKernel.h"

#include <iostream>

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
    if (_isPlaying == YES) {
        _state.transportStartMachSeconds = 0.0;
        _state.playStartSampleSeconds = 0.0;
        _state.playDurationSeconds = 0.0;
    }
    _state.playDurationSeconds = 0;
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        _state.track[t].playCounter = 0;
    }
}

void MidiRecorderDSPKernel::play() {
    if (_isPlaying == NO) {
        _state.scheduledStop = false;
        
        _state.playStartSampleSeconds = 0.0;
        _isPlaying = YES;
    }
}

void MidiRecorderDSPKernel::stop() {
    _state.transportStartMachSeconds = 0.0;

    if (_isPlaying == YES) {
        _isPlaying = NO;
    }
}

void MidiRecorderDSPKernel::setParameter(AUParameterAddress address, AUValue value) {
    switch (address) {
        case paramOne:
            break;
    }
}

AUValue MidiRecorderDSPKernel::getParameter(AUParameterAddress address) {
    switch (address) {
        case paramOne:
            // Return the goal. It is not thread safe to return the ramping value.
            return 0.f;

        default: return 0.f;
    }
}

void MidiRecorderDSPKernel::setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {
    _inBufferList = inBufferList;
    _outBufferList = outBufferList;
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

void MidiRecorderDSPKernel::handleMIDIEvent(AUMIDIEvent const& midiEvent) {
    if (midiEvent.cable < 0 || midiEvent.cable >= 4) {
        return;
    }

    if (isBypassed()) {
        // pass through MIDI events
        if (_ioState.midiOutputEventBlock) {

            Float64 frame_offset = midiEvent.eventSampleTime - _ioState.timestamp->mSampleTime;
            _state.track[midiEvent.cable].activityOutput = 1.f;
            _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + frame_offset, midiEvent.cable, midiEvent.length, midiEvent.data);
        }
    }
    else {
        queueMIDIEvent(midiEvent);
    }
}

void MidiRecorderDSPKernel::processOutput() {
    if (!_isPlaying) {
        turnOffAllNotes();
    }
    else {
        if (_state.playStartSampleSeconds == 0.0) {
            // get a reference timestamp to measure the play duration
            _state.playStartSampleSeconds = _ioState.timestamp->mSampleTime / _ioState.sampleRate;
            
            // if we had a previous play duration, offset the reference timestamp so that we start later on the timeline
            _state.playStartSampleSeconds -= _state.playDurationSeconds;
        }
        
        const double current_time = _ioState.timestamp->mSampleTime / _ioState.sampleRate;
        const double frames_seconds = double(_ioState.frameCount) / _ioState.sampleRate;
        
        _state.playDurationSeconds = current_time - _state.playStartSampleSeconds;

        BOOL reached_end = YES;
        
        // process all the messages on all the tracks
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            MidiTrackState& state = _state.track[t];
            
            // don't play if the track is recording
            if (state.recording) {
                reached_end = NO;
            }
            // play when there are recorded messages
            else if (state.recordedMessages != nullptr && state.recordedLength > 0) {
                
                // try to play as many recorded messages as possible
                uint64_t play_counter;
                while ((play_counter = state.playCounter) < state.recordedLength) {
                    const RecordedMidiMessage* message = &state.recordedMessages[play_counter];
                    
                    // check if the time offset of the message falls without the advancement of the playhead
                    if (message->offsetSeconds < _state.playDurationSeconds + frames_seconds) {
                        
                        // if the track is not muted and a MIDI output block exists,
                        // send the message
                        if (!state.mute && _ioState.midiOutputEventBlock) {
                            const double offset_seconds = message->offsetSeconds - _state.playDurationSeconds;
                            const double offset_samples = offset_seconds * _ioState.sampleRate;
                            
                            // indicate output activity
                            state.activityOutput = 1.f;
                            
                            // track note on/off states
                            trackNotesForTrack(t, message);

                            // send the MIDI output message
                            _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + offset_samples,
                                                          t, message->length, &message->data[0]);
                        }
                        // if the track is muted, ensure we have no lingering note on messages
                        else {
                            turnOffAllNotesForTrack(t);
                        }

                        // advance through the recorded messages
                        state.playCounter += 1;
                    }
                    // stop playing recorded messages if the one we processed is scheduled for later
                    else {
                        break;
                    }
                }
                
                if (state.playCounter < state.recordedLength) {
                    reached_end = NO;
                }
            }
        }
        
        if (reached_end) {
            _isPlaying = NO;
            _state.scheduledStop = true;
        }
    }
}

void MidiRecorderDSPKernel::trackNotesForTrack(int track, const RecordedMidiMessage* message) {
    int status = message->data[0];
    int type = status & 0xf0;
    int chan = (status & 0x0f);
    int val = message->data[2];
    if (type == MIDI_NOTE_OFF ||
        (type == MIDI_NOTE_ON && val == 0)) {
        if (_noteStates[track][chan][message->data[1]] == true &&
            _noteCounts[track] > 0) {
            _noteCounts[track] -= 1;
        }
        _noteStates[track][chan][message->data[1]] = false;
    }
    else if (type == MIDI_NOTE_ON) {
        if (_noteStates[track][chan][message->data[1]] == false) {
            _noteCounts[track] += 1;
        }
        _noteStates[track][chan][message->data[1]] = true;
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
    const int32_t length = sizeof(QueuedMidiMessage);
    
    QueuedMidiMessage message;
    message.timeSampleSeconds = midiEvent.eventSampleTime / _ioState.sampleRate;
    message.cable = midiEvent.cable;
    message.length = midiEvent.length;
    message.data[0] = midiEvent.data[0];
    message.data[1] = midiEvent.data[1];
    message.data[2] = midiEvent.data[2];
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, length);
}
