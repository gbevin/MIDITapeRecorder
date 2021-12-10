//
//  SettingsViewController.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

#import "AudioUnitViewController.h"

@interface SettingsViewController : UIViewController

@property(weak, nonatomic) AudioUnitViewController* mainViewController;

@end
