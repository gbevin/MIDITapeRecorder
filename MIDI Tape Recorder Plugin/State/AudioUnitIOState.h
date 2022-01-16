//
//  AudioUnitIOState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <atomic>

#import <AudioToolbox/AUAudioUnit.h>
#import <CoreAudio/CoreAudioTypes.h>

struct AudioUnitIOState {
    std::atomic_flag instrument         { false };
    std::atomic<int32_t> channelCount   { 0 };
    std::atomic<float> sampleRate       { 44100.f };
    std::atomic<uint32_t> frameCount    { 0 };
    std::atomic<double> framesBeats     { 0.0 };

    std::atomic_flag transportMoving            { false };
    std::atomic<double> transportSamplePosition { 0.0 };
    std::atomic_flag transportChangeProcessed   { true };
    std::atomic_flag transportPositionProcessed { true };
    
    std::atomic<double> currentBeatPosition     { 0.0 };

    const AudioTimeStamp* timestamp         { nullptr };
    std::atomic<double> timeSampleSeconds   { 0.0 };

    AUMIDIOutputEventBlock midiOutputEventBlock     { nullptr };
    AUHostTransportStateBlock transportStateBlock   { nullptr };
    AUHostMusicalContextBlock musicalContext        { nullptr };

    void reset() {
        channelCount = 0;
        sampleRate = 44100.f;
        frameCount = 0;
        
        timestamp = nullptr;
        
        midiOutputEventBlock = nullptr;
        transportStateBlock = nullptr;
        musicalContext = nullptr;
    }
};
