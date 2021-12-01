//
//  AudioUnitViewController.h
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import <CoreAudioKit/CoreAudioKit.h>

#import "MidiQueueProcessorDelegate.h"

@interface AudioUnitViewController : AUViewController <AUAudioUnitFactory, MidiQueueProcessorDelegate>

@end
