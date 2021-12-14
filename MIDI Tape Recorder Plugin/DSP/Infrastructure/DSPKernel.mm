//
//  DSPKernel.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "DSPKernel.h"

void DSPKernel::handleOneEvent(AURenderEvent const* event) {
    switch (event->head.eventType) {
        case AURenderEventParameter: {
            handleParameterEvent(event->parameter);
            break;
        }

        case AURenderEventMIDI:
            handleMIDIEvent(event->MIDI);
            break;

        default:
            break;
    }
}

void DSPKernel::performAllSimultaneousEvents(double bufferEndTimeSamples, AURenderEvent const*& event) {
    while (event && event->head.eventSampleTime <= bufferEndTimeSamples) {
        handleOneEvent(event);
        event = event->head.next;
    }
}

AUAudioFrameCount DSPKernel::maximumFramesToRender() const {
    return maxFramesToRender;
}

void DSPKernel::setMaximumFramesToRender(const AUAudioFrameCount& maxFrames) {
    maxFramesToRender = maxFrames;
}
