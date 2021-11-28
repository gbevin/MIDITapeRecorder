//
//  AudioUnitGUIState.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 11/28/21.
//

#pragma once

struct AudioUnitGUIState {
    float midiActivityInput[8] = { 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f };
    float midiActivityOutput[8] = { 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f };
};
