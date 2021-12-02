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

void DSPKernel::performAllSimultaneousEvents(AUEventSampleTime now, AURenderEvent const*& event) {
    do {
        handleOneEvent(event);

        // Go to next event.
        event = event->head.next;

    }
    // While event is not null and is simultaneous (or late).
    while (event && event->head.eventSampleTime <= now);
}

/**
 This function handles the event list processing and rendering loop for you.
 Call it inside your internalRenderBlock.
 */
void DSPKernel::processWithEvents(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events) {

    AUEventSampleTime now = AUEventSampleTime(timestamp->mSampleTime);
    AUAudioFrameCount framesRemaining = frameCount;
    AURenderEvent const* event = events;

    while (framesRemaining > 0) {
        // If there are no more events, we can process the entire remaining segment and exit.
        if (event == nullptr) {
            AUAudioFrameCount const bufferOffset = frameCount - framesRemaining;
            process(framesRemaining, bufferOffset);
            return;
        }

        // **** start late events late.
        auto timeZero = AUEventSampleTime(0);
        auto headEventTime = event->head.eventSampleTime;
        AUAudioFrameCount const framesThisSegment = AUAudioFrameCount(std::max(timeZero, headEventTime - now));

        // Compute everything before the next event.
        if (framesThisSegment > 0) {
            AUAudioFrameCount const bufferOffset = frameCount - framesRemaining;
            process(framesThisSegment, bufferOffset);

            // Advance frames.
            framesRemaining -= framesThisSegment;

            // Advance time.
            now += AUEventSampleTime(framesThisSegment);
        }

        performAllSimultaneousEvents(now, event);
    }
}

AUAudioFrameCount DSPKernel::maximumFramesToRender() const {
    return maxFramesToRender;
}

void DSPKernel::setMaximumFramesToRender(const AUAudioFrameCount& maxFrames) {
    maxFramesToRender = maxFrames;
}
