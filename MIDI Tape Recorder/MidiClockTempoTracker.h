//
//  MidiClockTempoTracker.h
//  MIDI Tape Recorder
//
//  derives a smoothed tempo (BPM) from incoming MIDI clock pulses (0xF8, 24 per
//  quarter note) and tracks whether clock is currently being received. pure
//  foundation: no CoreMIDI, no audio, no UI, so it can be unit tested directly.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MIDI clock runs at 24 pulses per quarter note.
extern const double MidiClockPulsesPerQuarter;
// derived tempos outside this range are treated as noise and ignored.
extern const double MidiClockMinBPM;
extern const double MidiClockMaxBPM;
// weight given to the running average vs. the newest measurement when smoothing.
extern const double MidiClockSmoothingRetained;
// the clock is considered stopped if no pulse arrives within this window.
extern const NSTimeInterval MidiClockTimeout;

@interface MidiClockTempoTracker : NSObject

// smoothed tempo in BPM. 0 until at least two pulses have established an interval.
@property (nonatomic, readonly) double tempo;

// YES once a pulse has been seen and until the clock is reset or times out.
@property (nonatomic, readonly, getter=isActive) BOOL active;

// feeds one clock pulse observed at the given monotonic time (seconds). returns
// YES if this pulse produced a new (in-range) smoothed tempo.
- (BOOL)pulseAtSeconds:(double)seconds;

// marks the clock inactive if no pulse has arrived within MidiClockTimeout of the
// given time. returns YES if this call transitioned from active to inactive.
- (BOOL)expireIfStaleAtSeconds:(double)seconds;

// clears all state (tempo, activity, last pulse time).
- (void)reset;

@end

NS_ASSUME_NONNULL_END
