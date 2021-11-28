//
//  AudioUnitIOState.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 11/27/21.
//

#pragma once

#import <CoreAudio/CoreAudioTypes.h>

struct AudioUnitIOState {
    int32_t channelCount    { 0 };
    float sampleRate        { 44100.f };
    
    const AudioTimeStamp* currentRenderTimestamp    { nullptr };

    AUMIDIOutputEventBlock midiOutputEventBlock     { nullptr };
    AUHostTransportStateBlock transportStateBlock   { nullptr };
    AUHostMusicalContextBlock musicalContext        { nullptr };
 
    void reset() {
        channelCount = 0;
        sampleRate = 44100.f;
        
        currentRenderTimestamp = nullptr;
        
        midiOutputEventBlock = nullptr;
        transportStateBlock = nullptr;
        musicalContext = nullptr;
    }
};
