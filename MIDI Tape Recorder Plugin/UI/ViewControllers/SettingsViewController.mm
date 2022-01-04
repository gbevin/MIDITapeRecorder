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
@property (weak, nonatomic) IBOutlet UIButton* showToolTipsButton;
@property (weak, nonatomic) IBOutlet UIButton* followHostTransportButton;

@end

@implementation SettingsViewController

#pragma mark IBActions

- (IBAction)sendMpeConfigOnPlayPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->sendMpeConfigOnPlay.test_and_set();
    else                 _mainViewController.state->sendMpeConfigOnPlay.clear();
}

- (IBAction)displayMpeConfigDetailsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->displayMpeConfigDetails.test_and_set();
    else                 _mainViewController.state->displayMpeConfigDetails.clear();
    _mainViewController.state->processedUIMpeConfigChange.clear();
}

- (IBAction)autoTrimRecordingsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->autoTrimRecordings.test_and_set();
    else                 _mainViewController.state->autoTrimRecordings.clear();
}

- (IBAction)showToolTipsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->showToolTips.test_and_set();
    else                 _mainViewController.state->showToolTips.clear();
}

- (IBAction)followHostTransportPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->followHostTransport.test_and_set();
    else                 _mainViewController.state->followHostTransport.clear();
}

- (IBAction)closeSettingsView:(id)sender {
    [_mainViewController closeSettingsView];
}

#pragma mark Sync

- (void)sync {
    _sendMpeConfigOnPlayButton.selected = _mainViewController.state->sendMpeConfigOnPlay.test();
    _displayMpeConfigDetailsButton.selected = _mainViewController.state->displayMpeConfigDetails.test();
    _autoTrimRecordingsButton.selected = _mainViewController.state->autoTrimRecordings.test();
    _showToolTipsButton.selected = _mainViewController.state->showToolTips.test();
    _followHostTransportButton.selected = _mainViewController.state->followHostTransport.test();
}

@end
