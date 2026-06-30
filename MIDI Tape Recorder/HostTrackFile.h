//
//  HostTrackFile.h
//  MIDI Tape Recorder
//
//  bridges the hosted AUv3's track data (carried in its fullState dictionary) to
//  and from Standard MIDI Files, using the shared midifile converter. this lets
//  the standalone host import/export all tracks without reaching across the
//  out-of-process boundary into the plugin's own MidiQueueProcessor.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HostTrackFile : NSObject

// builds a Standard MIDI File from the recorded tracks in an AU fullState
// dictionary (only non-empty tracks are written). returns nil if no track has
// any recorded content.
+ (nullable NSData*)midiFileFromFullState:(NSDictionary*)fullState tempo:(double)tempo;

// returns a copy of `fullState` with all four tracks replaced by the contents of
// the given Standard MIDI File: parsed tracks fill ordinals 0..N-1 in order, and
// any remaining tracks are cleared. returns nil if the file is not a usable SMF.
+ (nullable NSDictionary*)fullStateByImporting:(NSData*)midiFile
                                 intoFullState:(NSDictionary*)fullState;

@end

NS_ASSUME_NONNULL_END
