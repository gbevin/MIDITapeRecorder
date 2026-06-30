//
//  MidiClockTempoTracker.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiClockTempoTracker.h"

const double MidiClockPulsesPerQuarter   = 24.0;
const double MidiClockMinBPM             = 20.0;
const double MidiClockMaxBPM             = 400.0;
const double MidiClockSmoothingRetained  = 0.8;
const NSTimeInterval MidiClockTimeout    = 0.5;

@implementation MidiClockTempoTracker {
    BOOL _hasLastPulse;
    double _lastPulseSeconds;
    double _smoothedBpm;
    BOOL _active;
}

- (double)tempo {
    return _smoothedBpm;
}

- (BOOL)isActive {
    return _active;
}

- (BOOL)pulseAtSeconds:(double)seconds {
    _active = YES;

    BOOL updated = NO;
    if (_hasLastPulse && seconds > _lastPulseSeconds) {
        // seconds per pulse -> BPM
        double dt = seconds - _lastPulseSeconds;
        double bpm = 60.0 / (dt * MidiClockPulsesPerQuarter);
        if (bpm >= MidiClockMinBPM && bpm <= MidiClockMaxBPM) {
            _smoothedBpm = (_smoothedBpm <= 0.0)
                ? bpm
                : (_smoothedBpm * MidiClockSmoothingRetained +
                   bpm * (1.0 - MidiClockSmoothingRetained));
            updated = YES;
        }
    }
    _hasLastPulse = YES;
    _lastPulseSeconds = seconds;
    return updated;
}

- (BOOL)expireIfStaleAtSeconds:(double)seconds {
    if (_active && (seconds - _lastPulseSeconds) > MidiClockTimeout) {
        _active = NO;
        _hasLastPulse = NO;
        _lastPulseSeconds = 0.0;
        return YES;
    }
    return NO;
}

- (void)reset {
    _hasLastPulse = NO;
    _lastPulseSeconds = 0.0;
    _smoothedBpm = 0.0;
    _active = NO;
}

@end
