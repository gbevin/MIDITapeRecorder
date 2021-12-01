//
//  MidiRecorderDSPKernel.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import "DSPKernel.h"

#include <atomic>

#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/AUViewController.h>

#include "BufferedAudioBus.hpp"

#import "MidiRecorderDSPKernel.h"
#import "DSPKernelAdapter.h"

@implementation DSPKernelAdapter {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    MidiRecorderDSPKernel _kernel;
    BufferedInputBus _inputBus;
}

- (instancetype)init {
    if (self = [super init]) {
        AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
        
        // Create a DSP kernel to handle the signal processing.
        _kernel._ioState.channelCount = format.channelCount;
        _kernel._ioState.sampleRate = format.sampleRate;
        _kernel.setParameter(paramOne, 0);

        // Create the input and output busses.
        _inputBus.init(format, 2);
        _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
        _outputBus.maximumChannelCount = 2;
    }
    return self;
}

- (AUAudioUnitBus*)inputBus {
    return _inputBus.bus;
}

- (AudioUnitGUIState*)guiState {
    return &_kernel._guiState;
}

- (AudioUnitIOState*)ioState {
    return &_kernel._ioState;
}

- (void)rewind {
    _kernel.rewind();
}

- (void)play {
    _kernel.play();
}

- (void)stop {
    _kernel.stop();
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
    _inputBus.allocateRenderResources(self.maximumFramesToRender);
    _kernel._ioState.channelCount = self.outputBus.format.channelCount;
    _kernel._ioState.sampleRate = self.outputBus.format.sampleRate;
}

- (void)deallocateRenderResources {
    _kernel.cleanup();
    _inputBus.deallocateRenderResources();
}

// MARK: -  AUAudioUnit (AUAudioUnitImplementation)

// Subclassers must provide a AUInternalRenderBlock (via a getter) to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    // Specify captured objects are mutable.
    __block MidiRecorderDSPKernel* kernel = &_kernel;
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

        AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);

        if (err != noErr) { return err; }

        AudioBufferList* inAudioBufferList = input->mutableAudioBufferList;

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
        AudioBufferList* outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }

        kernel->_ioState.frameCount = frameCount;
        kernel->_ioState.timestamp = timestamp;
        
        kernel->setBuffers(inAudioBufferList, outAudioBufferList);
        kernel->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        kernel->processOutput();

        return noErr;
    };
}

@end
