//
//  DSPKernel.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <algorithm>

#import <AudioToolbox/AudioToolbox.h>

// Put your DSP code into a subclass of DSPKernel.
class DSPKernel {
public:
    virtual void handleBufferStart(double timeSampleSeconds) {}
    virtual void handleScheduledTransitions(double timeSampleSeconds) {}
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}
    virtual void handleParameterEvent(AUParameterEvent const& parameterEvent) {}
    virtual void processOutput() {};

    void performAllSimultaneousEvents(double bufferEndTimeSamples, AURenderEvent const*& event);

    AUAudioFrameCount maximumFramesToRender() const;
    void setMaximumFramesToRender(const AUAudioFrameCount& maxFrames);

private:
    void handleOneEvent(AURenderEvent const* event);

    AUAudioFrameCount maxFramesToRender = 1024;
};
