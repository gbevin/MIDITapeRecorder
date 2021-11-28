//
//  AudioUnitIOState.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 11/27/21.
//

#pragma once

#import <CoreAudio/CoreAudioTypes.h>

struct AudioUnitIOState {
    AUMIDIOutputEventBlock midiOutputEventBlock     { nullptr };
    AUHostTransportStateBlock transportStateBlock   { nullptr };
    AUHostMusicalContextBlock musicalContext        { nullptr };
 
    void reset() {
        midiOutputEventBlock = nullptr;
        transportStateBlock = nullptr;
        musicalContext = nullptr;
    }
};
