//
//  HostTime.h
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include "stdint.h"

class HostTime {
public:
    double hostTimeInSeconds(double time);
    double secondsInHostTime(double time);
    uint64_t currentMachTime();
    double currentMachTimeInSeconds();
    
    HostTime();

private:
    double _hostTimeToSeconds;
    double _secondsToHostTime;
};

static HostTime HOST_TIME;
