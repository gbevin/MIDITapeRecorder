//
//  MidiRecorderDSPKernel.cpp
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//

#import "MidiRecorderDSPKernel.hpp"

MidiRecorderDSPKernel::MidiRecorderDSPKernel() {}

void MidiRecorderDSPKernel::init(int channelCount, double inSampleRate) {
    _chanCount = channelCount;
    _sampleRate = float(inSampleRate);
}

void MidiRecorderDSPKernel::reset() {
}

bool MidiRecorderDSPKernel::isBypassed() {
    return _bypassed;
}

void MidiRecorderDSPKernel::setBypass(bool shouldBypass) {
    _bypassed = shouldBypass;
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
    for (int channel = 0; channel < _chanCount; ++channel) {
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
    // pass through MIDI events
    if (_ioState.midiOutputEventBlock) {
        _ioState.midiOutputEventBlock(midiEvent.eventSampleTime, midiEvent.cable, midiEvent.length, midiEvent.data);
    }
    
    if (midiEvent.cable < 0 || midiEvent.cable >= 8) {
        return;
    }
    
    uint8_t status = midiEvent.data[0] & 0xf0;
    uint8_t channel = midiEvent.data[0] & 0x0f;
    uint8_t data1 = midiEvent.data[1];
    uint8_t data2 = midiEvent.data[2];
    
    NSLog(@"%lld %d %d %d %d", midiEvent.eventSampleTime, (int)status, (int)channel, (int)data1, (int)data2);
    
    _guiState.midiActivity[midiEvent.cable] = 1.f;
}
