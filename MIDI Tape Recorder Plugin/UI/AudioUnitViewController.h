//
//  AudioUnitViewController.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <CoreAudioKit/CoreAudioKit.h>

#import "MidiRecorderDelegate.h"

@interface AudioUnitViewController : AUViewController <AUAudioUnitFactory, MidiRecorderDelegate, UIScrollViewDelegate>

- (void)readSettingsFromDict:(NSDictionary*)data;
- (void)readRecordingsFromDict:(NSDictionary*)data;
- (NSDictionary*)currentSettingsToDict;
- (NSDictionary*)currentRecordingsToDict;

@end
