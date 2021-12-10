//
//  SettingsViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "SettingsViewController.h"

@implementation SettingsViewController

#pragma mark IBActions

- (IBAction)closeSettingsView:(id)sender {
    [_mainViewController closeSettingsView];
}

@end
