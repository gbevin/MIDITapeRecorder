//
//  MidiRecorderAudioUnit.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <AudioToolbox/AudioToolbox.h>

#import "DSPKernelAdapter.h"

// Define parameter addresses.
extern const AudioUnitParameterID myParam1;

@class AudioUnitViewController;

@interface MidiRecorderAudioUnit : AUAudioUnit

@property (nonatomic, readonly) DSPKernelAdapter* kernelAdapter;

- (void)setVC:(AudioUnitViewController*)vc;

- (void)setupAudioBuses;
- (void)setupParameterTree;
- (void)setupParameterCallbacks;
@end
