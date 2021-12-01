//
//  HostTime.h
//  MIDI Recorder
//
//  Created by Geert Bevin on 12/1/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

#include <mach/mach_time.h>

class HostTime {
public:

    double hostTimeInSeconds(double time) {
        return time * _hostTimeToSeconds;
    }

    double secondsInHostTime(double time) {
        return time * _secondsToHostTime;
    }

    uint64_t currentMachTime() {
        return mach_absolute_time();
    }

    double currentMachTimeInSeconds() {
        return ((double)mach_absolute_time()) * _hostTimeToSeconds;
    }

    HostTime() {
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        _hostTimeToSeconds = ((double)info.numer) / ((double)info.denom) * 1.0e-9;
        _secondsToHostTime = (1.0e9 * (double)info.denom) / ((double)info.numer);
    }

private:
    double _hostTimeToSeconds;
    double _secondsToHostTime;
};

static HostTime HOST_TIME;
