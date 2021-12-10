//
//  SettingsViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "SettingsViewController.h"

@interface SettingsViewController ()

@property (weak, nonatomic) IBOutlet UIButton* sendMpeConfigOnPlayButton;
@property (weak, nonatomic) IBOutlet UIButton* displayMpeConfigDetailsButton;
@property (weak, nonatomic) IBOutlet UIButton* autoTrimRecordingsButton;

@end

@implementation SettingsViewController

#pragma mark IBActions

- (IBAction)sendMpeConfigOnPlayPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    _mainViewController.state->sendMpeConfigOnPlay = sender.selected;
}

- (IBAction)displayMpeConfigDetailsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    _mainViewController.state->displayMpeConfigDetails = sender.selected;
    _mainViewController.state->scheduledUIMpeConfigChange = true;
}

- (IBAction)autoTrimRecordingsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    _mainViewController.state->autoTrimRecordings = sender.selected;
}

- (IBAction)closeSettingsView:(id)sender {
    [_mainViewController closeSettingsView];
}

#pragma mark Sync

- (void)sync {
    _sendMpeConfigOnPlayButton.selected = _mainViewController.state->sendMpeConfigOnPlay;
    _displayMpeConfigDetailsButton.selected = _mainViewController.state->displayMpeConfigDetails;
    _autoTrimRecordingsButton.selected = _mainViewController.state->autoTrimRecordings;
}

@end
