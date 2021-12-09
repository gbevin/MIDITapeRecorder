//
//  MPEState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <atomic>

struct MPEState {
    MPEState() {};
    MPEState(const MPEState&) = delete;
    MPEState& operator= (const MPEState&) = delete;
    
    std::atomic<bool> enabled                   { false };

    std::atomic<bool> zone1Active               { false };
    std::atomic<uint8_t> zone1Members           { 0 };
    std::atomic<float> zone1ManagerPitchSens    { 0.f };
    std::atomic<float> zone1MemberPitchSens     { 0.f };

    std::atomic<bool> zone2Active               { false };
    std::atomic<uint8_t> zone2Members           { 0 };
    std::atomic<float> zone2ManagerPitchSens    { 0.f };
    std::atomic<float> zone2MemberPitchSens     { 0.f };
};
