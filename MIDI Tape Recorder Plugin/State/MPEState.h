//
//  MPEState.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
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

    // clears the detected MPE configuration back to its defaults; keep in sync
    // with the member initializers above (atomics can't be copy-reset in bulk)
    void reset() {
        enabled = false;
        zone1Active = false;
        zone1Members = 0;
        zone1ManagerPitchSens = 0.f;
        zone1MemberPitchSens = 0.f;
        zone2Active = false;
        zone2Members = 0;
        zone2ManagerPitchSens = 0.f;
        zone2MemberPitchSens = 0.f;
    }
};
