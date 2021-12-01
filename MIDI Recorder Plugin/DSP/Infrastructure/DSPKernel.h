//
//  DSPKernel.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#pragma once

#include <algorithm>

#import <AudioToolbox/AudioToolbox.h>

// Put your DSP code into a subclass of DSPKernel.
class DSPKernel {
public:
    virtual void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) = 0;

    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}
    virtual void handleParameterEvent(AUParameterEvent const& parameterEvent) {}
    virtual void processOutput() {};

    void processWithEvents(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events);

    AUAudioFrameCount maximumFramesToRender() const;
    void setMaximumFramesToRender(const AUAudioFrameCount& maxFrames);

private:
    void handleOneEvent(AURenderEvent const* event);
    void performAllSimultaneousEvents(AUEventSampleTime now, AURenderEvent const*& event);

    AUAudioFrameCount maxFramesToRender = 1024;
};
