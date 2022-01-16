//
//  MidiRecorderKernel.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "DSPKernel.h"

#include <atomic>

#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/AUViewController.h>

#include "BufferedAudioBus.hpp"

#import "MidiRecorderKernel.h"
#import "DSPKernelAdapter.h"

@implementation DSPKernelAdapter {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    MidiRecorderKernel _kernel;
    BufferedInputBus _inputBus;
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription {
    if (self = [super init]) {
        if (componentDescription.componentType == kAudioUnitType_MusicDevice) {
            _kernel._ioState.instrument.test_and_set();
        }
        
        AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
        
        // Create a DSP kernel to handle the signal processing.
        _kernel._ioState.channelCount = format.channelCount;
        _kernel._ioState.sampleRate = format.sampleRate;

        // Create the input and output busses.
        if (!self.isInstrument) {
            _inputBus.init(format, 2);
        }
        _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
        _outputBus.maximumChannelCount = 2;
    }
    return self;
}

- (AUAudioUnitBus*)inputBus {
    return _inputBus.bus;
}

- (BOOL)isInstrument {
    return _kernel._ioState.instrument.test();
}

- (MidiRecorderState*)state {
    return &_kernel._state;
}

- (AudioUnitIOState*)ioState {
    return &_kernel._ioState;
}

- (void)setParameter:(AUParameter*)parameter value:(AUValue)value {
    _kernel.setParameter(parameter.address, value);
}

- (AUValue)valueForParameter:(AUParameter*)parameter {
    return _kernel.getParameter(parameter.address);
}

- (AUAudioFrameCount)maximumFramesToRender {
    return _kernel.maximumFramesToRender();
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {
    _kernel.setMaximumFramesToRender(maximumFramesToRender);
}

- (BOOL)shouldBypassEffect {
    return _kernel.isBypassed();
}

- (void)setShouldBypassEffect:(BOOL)bypass {
    _kernel.setBypass(bypass);
}

- (void)allocateRenderResources {
    if (!self.isInstrument) {
        _inputBus.allocateRenderResources(self.maximumFramesToRender);
    }
    _kernel._ioState.channelCount = self.outputBus.format.channelCount;
    _kernel._ioState.sampleRate = self.outputBus.format.sampleRate;
}

- (void)deallocateRenderResources {
    _kernel.cleanup();
    if (!self.isInstrument) {
        _inputBus.deallocateRenderResources();
    }
}

// MARK: -  AUAudioUnit (AUAudioUnitImplementation)

// Subclassers must provide a AUInternalRenderBlock (via a getter) to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    // Specify captured objects are mutable.
    __block MidiRecorderKernel* kernel = &_kernel;
    __block BufferedInputBus* input = &_inputBus;

    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags*                actionFlags,
                              const AudioTimeStamp*                      timestamp,
                              AVAudioFrameCount           				 frameCount,
                              NSInteger                   				 outputBusNumber,
                              AudioBufferList*                           outputData,
                              const AURenderEvent*                       realtimeEventListHead,
                              AURenderPullInputBlock __unsafe_unretained pullInputBlock) {
        AudioUnitRenderActionFlags pullFlags = 0;

        if (frameCount > kernel->maximumFramesToRender()) {
            return kAudioUnitErr_TooManyFramesToProcess;
        }

        AudioBufferList* inAudioBufferList = nullptr;
        AudioBufferList* outAudioBufferList = outputData;
        
        if (!kernel->_ioState.instrument.test()) {
            AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);

            if (err != noErr) { return err; }

            inAudioBufferList = input->mutableAudioBufferList;

            /*
             Important:
             If the caller passed non-null output pointers (outputData->mBuffers[x].mData), use those.

             If the caller passed null output buffer pointers, process in memory owned by the Audio Unit
             and modify the (outputData->mBuffers[x].mData) pointers to point to this owned memory.
             The Audio Unit is responsible for preserving the validity of this memory until the next call to render,
             or deallocateRenderResources is called.

             If your algorithm cannot process in-place, you will need to preallocate an output buffer
             and use it here.

             See the description of the canProcessInPlace property.
             */

            // If passed null output buffer pointers, process in-place in the input buffer.
            if (outAudioBufferList->mBuffers[0].mData == nullptr) {
                for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                    outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
                }
            }
        }

        if (kernel->_ioState.transportStateBlock) {
            AUHostTransportStateFlags transport_state_flags;
            
            // transport position
            double sample_position;
            kernel->_ioState.transportStateBlock(&transport_state_flags, &sample_position, nil, nil);
            if (kernel->_ioState.transportSamplePosition != sample_position) {
                kernel->_ioState.transportSamplePosition = sample_position;
                kernel->_ioState.transportPositionProcessed.clear();
            }

            // transport changed
            if (transport_state_flags & AUHostTransportStateChanged) {
                kernel->_ioState.transportChangeProcessed.clear();
            }
            BOOL moving = transport_state_flags & AUHostTransportStateMoving;
            if (moving != kernel->_ioState.transportMoving.test()) {
                kernel->_ioState.transportChangeProcessed.clear();
            }
            
            // transport moving
            if (moving) {
                kernel->_ioState.transportMoving.test_and_set();
            }
            else {
                kernel->_ioState.transportMoving.clear();
            }
        }
        // when there's no transport state block or the host transport shouldn't be followed,
        // set all transport state to neutral values
        else {
            kernel->_ioState.transportPositionProcessed.test_and_set();
            kernel->_ioState.transportChangeProcessed.test_and_set();
            kernel->_ioState.transportMoving.clear();
        }
        
        if (kernel->_ioState.musicalContext) {
            double tempo = 120.0;
            double beat_position = 0.0;
            kernel->_ioState.musicalContext(&tempo, nil, nil, &beat_position, nil, nil);
            kernel->_ioState.currentBeatPosition = beat_position;
            kernel->_state.tempo = tempo;
            kernel->_state.secondsToBeats = tempo / 60.0;
            kernel->_state.beatsToSeconds = 60.0 / tempo;
        }
        
        kernel->_ioState.frameCount = frameCount;
        kernel->_ioState.timestamp = timestamp;
        const double frames_seconds = double(frameCount) / kernel->_ioState.sampleRate;
        kernel->_ioState.framesBeats = frames_seconds * kernel->_state.secondsToBeats;

        // call into the kernel functions
        double time_sample_seconds = double(timestamp->mSampleTime - frameCount) / kernel->_ioState.sampleRate;
        kernel->setBuffers(inAudioBufferList, outAudioBufferList);
        kernel->handleBufferStart(time_sample_seconds);
        kernel->handleScheduledTransitions(time_sample_seconds);
        kernel->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        kernel->processOutput(time_sample_seconds);

        return noErr;
    };
}

@end
