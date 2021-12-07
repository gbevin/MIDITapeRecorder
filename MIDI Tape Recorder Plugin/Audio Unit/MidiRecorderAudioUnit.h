//
//  MidiRecorderAudioUnit.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <AudioToolbox/AudioToolbox.h>

#import "DSPKernelAdapter.h"

@class AudioUnitViewController;

@interface MidiRecorderAudioUnit : AUAudioUnit

@property (nonatomic, readonly) DSPKernelAdapter* kernelAdapter;

- (void)setVC:(AudioUnitViewController*)vc;

- (void)setupAudioBuses;
- (void)setupParameterTree;
- (void)setupParameterCallbacks;
@end
