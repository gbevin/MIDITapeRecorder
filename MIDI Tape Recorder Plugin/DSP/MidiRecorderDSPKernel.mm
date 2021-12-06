//
//  MidiRecorderDSPKernel.cpp
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
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
    _state.playDurationBeats = 0.0;
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        _state.track[t].playCounter = 0;
    }
    turnOffAllNotes();
}

void MidiRecorderDSPKernel::play() {
    if (_isPlaying == NO) {
        _state.scheduledStopAndRewind = false;
        _state.scheduledUIStopAndRewind = false;

        _isPlaying = YES;
    }
}

void MidiRecorderDSPKernel::stop() {
    _state.transportStartMachSeconds = 0.0;
    _isPlaying = NO;
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

void MidiRecorderDSPKernel::handleScheduledTransitions() {
    // we rely on the single-threaded nature of the audio callback thread to coordinate
    // important state transitions at the beginning of the callback, before anything else
    // this prevents split-state conditions to change semantics in the middle of processing
    
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        // begin recording
        {
            int32_t expected = true;
            if (_state.scheduledBeginRecording[t].compare_exchange_strong(expected, false)) {
                turnOffAllNotesForTrack(t);
                _state.track[t].recording = YES;
            }
        }
        // end recording
        {
            int32_t expected = true;
            if (_state.scheduledEndRecording[t].compare_exchange_strong(expected, false)) {
                _state.track[t].recording = NO;
            }
        }
        // ensure notes off
        {
            int32_t expected = true;
            if (_state.scheduledNotesOff[t].compare_exchange_strong(expected, false)) {
                turnOffAllNotesForTrack(t);
            }
        }
    }
    
    // rewind
    {
        int32_t expected = true;
        if (_state.scheduledRewind.compare_exchange_strong(expected, false)) {
            rewind();
        }
    }

    // play
    {
        int32_t expected = true;
        if (_state.scheduledPlay.compare_exchange_strong(expected, false)) {
            play();
        }
    }

    // stop
    {
        int32_t expected = true;
        if (_state.scheduledStop.compare_exchange_strong(expected, false)) {
            stop();
        }
    }

    // stop and rewind
    {
        int32_t expected = true;
        if (_state.scheduledStopAndRewind.compare_exchange_strong(expected, false)) {
            stop();
            rewind();
        }
    }

    // reach end
    {
        int32_t expected = true;
        if (_state.scheduledReachEnd.compare_exchange_strong(expected, false)) {
            _isPlaying = NO;
            _state.scheduledUIStopAndRewind = true;
        }
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

void MidiRecorderDSPKernel::handleBufferStart(AudioTimeStamp const* timestamp) {
    QueuedMidiMessage message;
    message.timeSampleSeconds = double(timestamp->mSampleTime - _ioState.frameCount) / _ioState.sampleRate;
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, sizeof(QueuedMidiMessage));
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
            MidiTrackState& state = _state.track[t];
            
            if (state.monitorEnabled && !state.muteEnabled && state.sourceCable == midiEvent.cable) {
                _state.track[t].activityOutput = 1.f;
                passThroughMIDIEvent(midiEvent, t);
            }
        }
        
        queueMIDIEvent(midiEvent);
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

        _state.playDurationBeats += frames_beats;

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
                    if (message->offsetBeats < _state.playDurationBeats + frames_beats) {
                        
                        // if the track is not muted and a MIDI output block exists,
                        // send the message
                        if (!state.muteEnabled && _ioState.midiOutputEventBlock) {
                            const double offset_seconds = (message->offsetBeats - _state.playDurationBeats) * _state.beatsToSeconds;
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
                
                if (_state.playDurationBeats < state.recordedDurationBeats) {
                    reached_end = NO;
                }
            }
        }
        
        if (reached_end) {
            _state.scheduledReachEnd = true;
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
    QueuedMidiMessage message;
    message.timeSampleSeconds = double(midiEvent.eventSampleTime) / _ioState.sampleRate;
    message.cable = midiEvent.cable;
    message.length = midiEvent.length;
    message.data[0] = midiEvent.data[0];
    message.data[1] = midiEvent.data[1];
    message.data[2] = midiEvent.data[2];
    
    TPCircularBufferProduceBytes(&_state.midiBuffer, &message, sizeof(QueuedMidiMessage));
}
