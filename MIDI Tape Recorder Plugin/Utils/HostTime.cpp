//
//  HostTime.cpp
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/6/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#include "HostTime.h"

#include <mach/mach_time.h>

double HostTime::hostTimeInSeconds(double time) {
    return time * _hostTimeToSeconds;
}

double HostTime::secondsInHostTime(double time) {
    return time * _secondsToHostTime;
}

uint64_t HostTime::currentMachTime() {
    return mach_absolute_time();
}

double HostTime::currentMachTimeInSeconds() {
    return ((double)mach_absolute_time()) * _hostTimeToSeconds;
}

HostTime::HostTime() {
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    _hostTimeToSeconds = ((double)info.numer) / ((double)info.denom) * 1.0e-9;
    _secondsToHostTime = (1.0e9 * (double)info.denom) / ((double)info.numer);
}
