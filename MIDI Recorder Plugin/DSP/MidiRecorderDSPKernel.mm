//
//  MidiRecorderDSPKernel.cpp
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorderDSPKernel.h"

#include <iostream>

MidiRecorderDSPKernel::MidiRecorderDSPKernel() : _state() {
    TPCircularBufferInit(&_state.midiBuffer, 16384);
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
        _state.playStartTime = 0;
    }
    _state.playDuration = 0;
    for (int i = 0; i < MIDI_TRACKS; ++i) {
        _state.track[i].playCounter = 0;
    }
}

void MidiRecorderDSPKernel::play() {
    if (_isPlaying == NO) {
        _state.scheduledStop = false;
        
        _state.playStartTime = 0;
        _isPlaying = YES;
    }
}

void MidiRecorderDSPKernel::stop() {
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
    if (_isPlaying) {
        if (_state.playStartTime == 0) {
            _state.playStartTime = _ioState.timestamp->mSampleTime / _ioState.sampleRate;
        }
        
        const double current_time = _ioState.timestamp->mSampleTime / _ioState.sampleRate;
        const double frames_seconds = double(_ioState.frameCount) / _ioState.sampleRate;
        
        _state.playDuration = current_time - _state.playStartTime;

        BOOL reached_end = YES;
        for (int i = 0; i < MIDI_TRACKS; ++i) {
            MidiTrackState& state = _state.track[i];
            if (state.recording) {
                reached_end = NO;
            }
            else if (state.recordedMessages != nullptr && state.recordedLength > 0) {
                uint64_t play_counter;
                while ((play_counter = state.playCounter) < state.recordedLength) {
                    const double recorded_delta = state.recordedMessages[play_counter].timestampSeconds;
                    if (recorded_delta < _state.playDuration + frames_seconds) {
                        const QueuedMidiMessage* message = &state.recordedMessages[play_counter];
                        
                        if (!state.mute && _ioState.midiOutputEventBlock) {
                            const double offset_seconds = recorded_delta - _state.playDuration;
                            const double offset_samples = offset_seconds * _ioState.sampleRate;
                            
                            state.activityOutput = 1.f;
                            _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + offset_samples, message->cable, message->length, &message->data[0]);
                        }

                        state.playCounter += 1;
                    }
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
            for (int i = 0; i < MIDI_TRACKS; ++i) {
                _state.track[i].playCounter = 0;
            }
            _state.scheduledStop = true;
        }
    }
}

void MidiRecorderDSPKernel::queueMIDIEvent(AUMIDIEvent const& midiEvent) {
    const int32_t length = sizeof(QueuedMidiMessage);
    
    QueuedMidiMessage message;
    message.timestampSeconds = midiEvent.eventSampleTime / _ioState.sampleRate;
    message.cable = midiEvent.cable;
    message.length = midiEvent.length;
    message.data[0] = midiEvent.data[0];
    message.data[1] = midiEvent.data[1];
    message.data[2] = midiEvent.data[2];
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, length);
}
