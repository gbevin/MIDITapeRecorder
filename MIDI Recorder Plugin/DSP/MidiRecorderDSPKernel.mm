//
//  MidiRecorderDSPKernel.cpp
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//

#import "MidiRecorderDSPKernel.h"

#include <iostream>

MidiRecorderDSPKernel::MidiRecorderDSPKernel() {
    TPCircularBufferInit(&_guiState.midiBuffer, 16384);
}

void MidiRecorderDSPKernel::cleanup() {
    TPCircularBufferCleanup(&_guiState.midiBuffer);
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
        _guiState.playStartTime = 0;
    }
    _guiState.playDuration = 0;
    _guiState.playCounter1 = 0;
}

void MidiRecorderDSPKernel::play() {
    if (_isPlaying == NO) {
        _guiState.scheduledStop = false;
        
        _guiState.playStartTime = 0;
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
            _guiState.midiActivityOutput[midiEvent.cable] = 1.f;
            _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + frame_offset, midiEvent.cable, midiEvent.length, midiEvent.data);
        }
    }
    else {
        _guiState.midiActivityInput[midiEvent.cable] = 1.f;
        queueMIDIEvent(midiEvent);
    }
}

void MidiRecorderDSPKernel::processOutput() {
    if (_isPlaying) {
        if (_guiState.playStartTime == 0) {
            _guiState.playStartTime = _ioState.timestamp->mSampleTime / _ioState.sampleRate;
        }
        
        const double current_time = _ioState.timestamp->mSampleTime / _ioState.sampleRate;
        const double frames_seconds = double(_ioState.frameCount) / _ioState.sampleRate;
        
        _guiState.playDuration = current_time - _guiState.playStartTime;

        if (_guiState.recordedLength1 > 0) {
            uint64_t play_counter1;
            while ((play_counter1 = _guiState.playCounter1) < _guiState.recordedLength1) {
                const double recorded_delta = _guiState.recordedBytes1[play_counter1].timestampSeconds;
                if (recorded_delta < _guiState.playDuration + frames_seconds) {
                    const QueuedMidiMessage* message = &_guiState.recordedBytes1[play_counter1];
                    
                    if (_ioState.midiOutputEventBlock) {
                        const double offset_seconds = recorded_delta - _guiState.playDuration;
                        const double offset_samples = offset_seconds * _ioState.sampleRate;
                        
                        _guiState.midiActivityOutput[message->cable] = 1.f;
                        _ioState.midiOutputEventBlock(_ioState.timestamp->mSampleTime + offset_samples, message->cable, message->length, &message->data[0]);
                    }

                    _guiState.playCounter1 += 1;
                }
                else {
                    break;
                }
            }
            
            if (_guiState.playCounter1 >= _guiState.recordedLength1) {
                _isPlaying = NO;
                _guiState.playCounter1 = 0;
                _guiState.scheduledStop = true;
            }
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
    
    TPCircularBufferProduceBytes(&_guiState.midiBuffer, &message, length);
}
