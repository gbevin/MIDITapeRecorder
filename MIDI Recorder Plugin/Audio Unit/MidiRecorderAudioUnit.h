//
//  MidiRecorderAudioUnit.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import <AudioToolbox/AudioToolbox.h>

#import "DSPKernelAdapter.h"

// Define parameter addresses.
extern const AudioUnitParameterID myParam1;

@interface MidiRecorderAudioUnit : AUAudioUnit

@property (nonatomic, readonly) DSPKernelAdapter* kernelAdapter;

- (void)setupAudioBuses;
- (void)setupParameterTree;
- (void)setupParameterCallbacks;
@end
