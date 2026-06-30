//
//  SettingsViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "SettingsViewController.h"

#import <objc/runtime.h>

// Key under which each label's tap gesture stashes the button it should toggle.
static const void* const kLabelButtonKey = &kLabelButtonKey;

@interface SettingsViewController ()

@property (weak, nonatomic) IBOutlet UIButton* displayMpeConfigDetailsButton;
@property (weak, nonatomic) IBOutlet UILabel* displayMpeConfigDetailsLabel;
@property (weak, nonatomic) IBOutlet UIButton* showToolTipsButton;
@property (weak, nonatomic) IBOutlet UILabel* showToolTipsLabel;
@property (weak, nonatomic) IBOutlet UIButton* sendMpeConfigOnPlayButton;
@property (weak, nonatomic) IBOutlet UILabel* sendMpeConfigOnPlayLabel;
@property (weak, nonatomic) IBOutlet UIButton* followHostTransportButton;
@property (weak, nonatomic) IBOutlet UILabel* followHostTransportLabel;
@property (weak, nonatomic) IBOutlet UIButton* waitForNextHostBeatToPlayButton;
@property (weak, nonatomic) IBOutlet UILabel* waitForNextHostBeatToPlayLabel;
@property (weak, nonatomic) IBOutlet UIButton* autoTrimRecordingsButton;
@property (weak, nonatomic) IBOutlet UILabel* autoTrimRecordingsLabel;
@property (weak, nonatomic) IBOutlet UIButton* autoRewindAfterRecordingButton;
@property (weak, nonatomic) IBOutlet UILabel* autoRewindAfterRecordingLabel;
@property (weak, nonatomic) IBOutlet UIButton* loopRecordButton;
@property (weak, nonatomic) IBOutlet UILabel* loopRecordLabel;

@end

@implementation SettingsViewController

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Let each setting's label toggle its control too, so tapping the text works
    // like tapping the small button next to it.
    [self linkLabel:_displayMpeConfigDetailsLabel toButton:_displayMpeConfigDetailsButton];
    [self linkLabel:_showToolTipsLabel toButton:_showToolTipsButton];
    [self linkLabel:_sendMpeConfigOnPlayLabel toButton:_sendMpeConfigOnPlayButton];
    [self linkLabel:_followHostTransportLabel toButton:_followHostTransportButton];
    [self linkLabel:_waitForNextHostBeatToPlayLabel toButton:_waitForNextHostBeatToPlayButton];
    [self linkLabel:_autoTrimRecordingsLabel toButton:_autoTrimRecordingsButton];
    [self linkLabel:_autoRewindAfterRecordingLabel toButton:_autoRewindAfterRecordingButton];
    [self linkLabel:_loopRecordLabel toButton:_loopRecordButton];
}

// Forwards taps on a setting's label to its button, so pressing the text runs the
// same IBAction as pressing the button.
- (void)linkLabel:(UILabel*)label toButton:(UIButton*)button {
    if (label == nil || button == nil) {
        return;
    }
    label.userInteractionEnabled = YES;
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped:)];
    objc_setAssociatedObject(tap, kLabelButtonKey, button, OBJC_ASSOCIATION_ASSIGN);
    [label addGestureRecognizer:tap];
}

- (void)labelTapped:(UITapGestureRecognizer*)recognizer {
    UIButton* button = objc_getAssociatedObject(recognizer, kLabelButtonKey);
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
}

#pragma mark IBActions

- (IBAction)displayMpeConfigDetailsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->displayMpeConfigDetails.test_and_set();
    else                 _mainViewController.state->displayMpeConfigDetails.clear();
    _mainViewController.state->processedUIMpeConfigChange.clear();
}

- (IBAction)showToolTipsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->showToolTips.test_and_set();
    else                 _mainViewController.state->showToolTips.clear();
}

- (IBAction)sendMpeConfigOnPlayPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->sendMpeConfigOnPlay.test_and_set();
    else                 _mainViewController.state->sendMpeConfigOnPlay.clear();
}

- (IBAction)followHostTransportPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->followHostTransport.test_and_set();
    else                 _mainViewController.state->followHostTransport.clear();
}

- (IBAction)waitForNextHostBeatToPlayPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->waitForNextHostBeatToPlay.test_and_set();
    else                 _mainViewController.state->waitForNextHostBeatToPlay.clear();
}

- (IBAction)autoTrimRecordingsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->autoTrimRecordings.test_and_set();
    else                 _mainViewController.state->autoTrimRecordings.clear();
}

- (IBAction)autoRewindAfterRecordingPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->autoRewindAfterRecording.test_and_set();
    else                 _mainViewController.state->autoRewindAfterRecording.clear();
}

- (IBAction)loopRecordPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.selected) _mainViewController.state->loopRecord.test_and_set();
    else                 _mainViewController.state->loopRecord.clear();
}

- (IBAction)closeSettingsView:(id)sender {
    [_mainViewController closeSettingsView];
}

#pragma mark Sync

- (void)sync {
    _displayMpeConfigDetailsButton.selected = _mainViewController.state->displayMpeConfigDetails.test();
    _showToolTipsButton.selected = _mainViewController.state->showToolTips.test();
    _sendMpeConfigOnPlayButton.selected = _mainViewController.state->sendMpeConfigOnPlay.test();
    _followHostTransportButton.selected = _mainViewController.state->followHostTransport.test();
    _waitForNextHostBeatToPlayButton.selected = _mainViewController.state->waitForNextHostBeatToPlay.test();
    _autoTrimRecordingsButton.selected = _mainViewController.state->autoTrimRecordings.test();
    _autoRewindAfterRecordingButton.selected = _mainViewController.state->autoRewindAfterRecording.test();
    _loopRecordButton.selected = _mainViewController.state->loopRecord.test();

    // Hide the transport-dependent settings when there is no host transport
    // (e.g. when hosted by the standalone app). These rows are the last in their
    // column, so hiding them leaves no gap.
    BOOL hideHostTransport = !_mainViewController.hostProvidesTransport;
    _followHostTransportButton.hidden = hideHostTransport;
    _followHostTransportLabel.hidden = hideHostTransport;
    _waitForNextHostBeatToPlayButton.hidden = hideHostTransport;
    _waitForNextHostBeatToPlayLabel.hidden = hideHostTransport;
}

@end
