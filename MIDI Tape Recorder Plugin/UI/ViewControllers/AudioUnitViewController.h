//
//  AudioUnitViewController.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <CoreAudioKit/CoreAudioKit.h>

#include "MidiRecorderState.h"
#import "MidiTrackRecorderDelegate.h"

@interface AudioUnitViewController : AUViewController <AUAudioUnitFactory, MidiTrackRecorderDelegate, UIDocumentPickerDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate>

- (void)readFullStateFromDict:(NSDictionary*)dict;
- (void)currentFullStateToDict:(NSMutableDictionary*)dict;

- (MidiRecorderState*)state;

- (void)closeAboutView;
- (void)closeDonateView;
- (void)closeSettingsView;

@end
