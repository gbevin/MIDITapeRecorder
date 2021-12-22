//
//  AudioUnitViewController.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "AudioUnitViewController.h"

#import <StoreKit/StoreKit.h>

#include "Constants.h"

#import "ActivityIndicatorView.h"
#import "AboutViewController.h"
#import "CropLeftView.h"
#import "CropRightView.h"
#import "DonateViewController.h"
#import "MidiQueueProcessor.h"
#import "MidiTrackRecorder.h"
#import "MidiRecorderAudioUnit.h"
#import "MidiTrackView.h"
#import "MPEButton.h"
#import "Preferences.h"
#import "PopupView.h"
#import "PunchInView.h"
#import "PunchOutView.h"
#import "RecorderUndoManager.h"
#import "SettingsViewController.h"
#import "TimelineView.h"
#import "ToolBarButton.h"
#import "TrackButton.h"

@interface AudioUnitViewController ()

@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput1;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput2;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput3;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput4;

@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput1;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput2;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput3;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput4;

@property (weak, nonatomic) IBOutlet UIView* toolbar;

@property (weak, nonatomic) IBOutlet UIView* toolTipView;
@property (weak, nonatomic) IBOutlet UILabel* toolTipLabel;

@property (weak, nonatomic) IBOutlet ToolTipButton* routingButton;

@property (weak, nonatomic) IBOutlet ToolBarButton* rewindButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* playButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* recordButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* repeatButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* gridButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* chaseButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* punchInOutButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* undoButton;
@property (weak, nonatomic) IBOutlet ToolBarButton* redoButton;
@property (weak, nonatomic) IBOutlet UIButton* settingsButton;
@property (weak, nonatomic) IBOutlet UIButton* aboutButton;
@property (weak, nonatomic) IBOutlet UIButton* donateButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint* chaseTrailing;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* undoLeading;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* timelineWidth;

@property (weak, nonatomic) IBOutlet TrackButton* recordButton1;
@property (weak, nonatomic) IBOutlet TrackButton* recordButton2;
@property (weak, nonatomic) IBOutlet TrackButton* recordButton3;
@property (weak, nonatomic) IBOutlet TrackButton* recordButton4;

@property (weak, nonatomic) IBOutlet TrackButton* monitorButton1;
@property (weak, nonatomic) IBOutlet TrackButton* monitorButton2;
@property (weak, nonatomic) IBOutlet TrackButton* monitorButton3;
@property (weak, nonatomic) IBOutlet TrackButton* monitorButton4;

@property (weak, nonatomic) IBOutlet MPEButton* mpeButton1;
@property (weak, nonatomic) IBOutlet MPEButton* mpeButton2;
@property (weak, nonatomic) IBOutlet MPEButton* mpeButton3;
@property (weak, nonatomic) IBOutlet MPEButton* mpeButton4;

@property (weak, nonatomic) IBOutlet TrackButton* muteButton1;
@property (weak, nonatomic) IBOutlet TrackButton* muteButton2;
@property (weak, nonatomic) IBOutlet TrackButton* muteButton3;
@property (weak, nonatomic) IBOutlet TrackButton* muteButton4;

@property (weak, nonatomic) IBOutlet UIButton* menuButtonAll;
@property (weak, nonatomic) IBOutlet UIButton* menuButton1;
@property (weak, nonatomic) IBOutlet UIButton* menuButton2;
@property (weak, nonatomic) IBOutlet UIButton* menuButton3;
@property (weak, nonatomic) IBOutlet UIButton* menuButton4;

@property (weak, nonatomic) IBOutlet PopupView* menuPopupAll;
@property (weak, nonatomic) IBOutlet PopupView* menuPopup1;
@property (weak, nonatomic) IBOutlet PopupView* menuPopup2;
@property (weak, nonatomic) IBOutlet PopupView* menuPopup3;
@property (weak, nonatomic) IBOutlet PopupView* menuPopup4;

@property (weak, nonatomic) IBOutlet UIButton* closeMenuButton1;
@property (weak, nonatomic) IBOutlet UIButton* closeMenuButton2;
@property (weak, nonatomic) IBOutlet UIButton* closeMenuButton3;
@property (weak, nonatomic) IBOutlet UIButton* closeMenuButton4;

@property (weak, nonatomic) IBOutlet ToolBarButton* clearButtonAll;
@property (weak, nonatomic) IBOutlet ToolBarButton* clearButton1;
@property (weak, nonatomic) IBOutlet ToolBarButton* clearButton2;
@property (weak, nonatomic) IBOutlet ToolBarButton* clearButton3;
@property (weak, nonatomic) IBOutlet ToolBarButton* clearButton4;

@property (weak, nonatomic) IBOutlet ToolBarButton* exportButtonAll;
@property (weak, nonatomic) IBOutlet ToolBarButton* exportButton1;
@property (weak, nonatomic) IBOutlet ToolBarButton* exportButton2;
@property (weak, nonatomic) IBOutlet ToolBarButton* exportButton3;
@property (weak, nonatomic) IBOutlet ToolBarButton* exportButton4;

@property (weak, nonatomic) IBOutlet ToolBarButton* importButtonAll;
@property (weak, nonatomic) IBOutlet ToolBarButton* importButton1;
@property (weak, nonatomic) IBOutlet ToolBarButton* importButton2;
@property (weak, nonatomic) IBOutlet ToolBarButton* importButton3;
@property (weak, nonatomic) IBOutlet ToolBarButton* importButton4;

@property (weak, nonatomic) IBOutlet UIScrollView* tracks;

@property (weak, nonatomic) IBOutlet TimelineView* timeline;
@property (weak, nonatomic) IBOutlet UITapGestureRecognizer* timelineTapGesture;

@property (weak, nonatomic) IBOutlet UIView* playhead;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* playheadLeading;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* playheadPanGesture;

@property (weak, nonatomic) IBOutlet UIView* cropOverlayLeft;
@property (weak, nonatomic) IBOutlet CropLeftView* cropLeft;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* cropLeftLeading;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* cropLeftPanGesture;

@property (weak, nonatomic) IBOutlet UIView* cropOverlayCenter;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* cropOverlayPanGesture;

@property (weak, nonatomic) IBOutlet UIView* cropOverlayRight;
@property (weak, nonatomic) IBOutlet CropRightView* cropRight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* cropRightLeading;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* cropRightPanGesture;

@property (weak, nonatomic) IBOutlet PunchInView* punchIn;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* punchInLeading;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* punchInPanGesture;

@property (weak, nonatomic) IBOutlet UIView* punchOverlay;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* punchOverlayPanGesture;

@property (weak, nonatomic) IBOutlet PunchOutView* punchOut;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* punchOutLeading;
@property (weak, nonatomic) IBOutlet UIPanGestureRecognizer* punchOutPanGesture;

@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack1;
@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack2;
@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack3;
@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack4;

@property (weak, nonatomic) IBOutlet UIView* settingsView;
@property (weak, nonatomic) IBOutlet UIView* aboutView;
@property (weak, nonatomic) IBOutlet UIView* donateView;

@property (weak, nonatomic) IBOutlet SettingsViewController* settingsViewController;
@property (weak, nonatomic) IBOutlet AboutViewController* aboutViewController;
@property (weak, nonatomic) IBOutlet DonateViewController* donateViewController;

@end

@interface ImportMidiDocumentPickerViewController : UIDocumentPickerViewController

- (instancetype)initWithDocumentTypes:(NSArray<NSString*>*)allowedUTIs inMode:(UIDocumentPickerMode)mode;
@property int track;
@end

@implementation ImportMidiDocumentPickerViewController
- (instancetype)initWithDocumentTypes:(NSArray<NSString*>*)allowedUTIs inMode:(UIDocumentPickerMode)mode {
    return [super initWithDocumentTypes:allowedUTIs inMode:mode];
}
@end

@implementation AudioUnitViewController {
    MidiRecorderAudioUnit* _audioUnit;
    MidiRecorderState* _state;
    CADisplayLink* _timer;
    BOOL _renderReady;
    
    RecorderUndoManager* _mainUndoManager;

    BOOL _restoringState;

    MidiQueueProcessor* _midiQueueProcessor;
    
    BOOL _autoPlayFromRecord;
    
    UIView* _activePannedMarker;
    CGPoint _autoPan;
    double _overlayPanStart;
    double _overlayPanStartFirstPosition;
    
    NSDate* _lastForegroundMoment;
    
    NSTimer* _toolTipTimer;
}

#pragma mark - Init

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _state = nil;
        _audioUnit = nil;
        _timer = nil;
        _renderReady = NO;
        
        _mainUndoManager = [RecorderUndoManager new];
        _mainUndoManager.levelsOfUndo = 10;
        _mainUndoManager.groupsByEvent = NO;
        
        _restoringState = NO;
        
        _midiQueueProcessor = [MidiQueueProcessor new];
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            [_midiQueueProcessor recorder:t].delegate = self;
        }
        
        _autoPlayFromRecord = NO;
        _activePannedMarker = nil;
        _autoPan = CGPointZero;
        _overlayPanStart = -1.0;
        _overlayPanStartFirstPosition = -1.0;
        
        _lastForegroundMoment = [NSDate date];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self autoShowDonateButton];

    _tracks.delegate = self;
    
    _timeline.tracks = _tracks;
    
    _chaseButton.selected = YES;
    
    _menuPopupAll.hidden = YES;
    MidiTrackView* midi_track[MIDI_TRACKS] = { _midiTrack1, _midiTrack2, _midiTrack3, _midiTrack4 };
    MPEButton* mpe_button[MIDI_TRACKS] = { _mpeButton1, _mpeButton2, _mpeButton3, _mpeButton4 };
    UIView* menu_popup[MIDI_TRACKS] = { _menuPopup1, _menuPopup2, _menuPopup3, _menuPopup4 };
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        midi_track[t].tracks = _tracks;
        midi_track[t].previewProvider = [_midiQueueProcessor recorder:t];
        menu_popup[t].hidden = YES;
        mpe_button[t].hidden = YES;
    }
    
    _timer = [[UIScreen mainScreen] displayLinkWithTarget:self
                                                 selector:@selector(renderloop)];
    _timer.preferredFramesPerSecond = 30;
    _timer.paused = NO;
    [_timer addToRunLoop:[NSRunLoop mainRunLoop]
                 forMode:NSDefaultRunLoopMode];

    _lastForegroundMoment = [NSDate date];
    
    [self undoManagerUpdated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(undoManagerUpdated)
                                                 name:NSUndoManagerCheckpointNotification
                                               object:_mainUndoManager];
    
    // setup tooltips
    _routingButton.toolTipDelegate = self;
    _routingButton.toolTipTextSelected = @"Seperate Input\nFor Each Track";
    _routingButton.toolTipTextUnselected = @"First Input To\nAll 4 Tracks";

    _rewindButton.toolTipDelegate = self;
    _rewindButton.toolTipTextHighlighted = @"Rewind";

    _recordButton.toolTipDelegate = self;
    _recordButton.toolTipTextSelected = @"Record\nArmed";
    _recordButton.toolTipTextUnselected = @"Record\nDisarmed";
    
    _playButton.toolTipDelegate = self;
    _playButton.toolTipTextSelected = @"Playing\nStarted";
    _playButton.toolTipTextUnselected = @"Playing\nStopped";
    
    _repeatButton.toolTipDelegate = self;
    _repeatButton.toolTipTextSelected = @"Repeat\nEnabled";
    _repeatButton.toolTipTextUnselected = @"Repeat\nDisabled";

    _gridButton.toolTipDelegate = self;
    _gridButton.toolTipTextSelected = @"Snap To Beat\nEnabled";
    _gridButton.toolTipTextUnselected = @"Snap To Beat\nDisabled";

    _chaseButton.toolTipDelegate = self;
    _chaseButton.toolTipTextSelected = @"Auto Scroll\nEnabled";
    _chaseButton.toolTipTextUnselected = @"Auto Scroll\nDisabled";

    _punchInOutButton.toolTipDelegate = self;
    _punchInOutButton.toolTipTextSelected = @"Punch In/Out\nEnabled";
    _punchInOutButton.toolTipTextUnselected = @"Punch In/Out\nDisabled";
    
    _undoButton.toolTipDelegate = self;
    _undoButton.toolTipTextHighlighted = @"Undo";
    
    _redoButton.toolTipDelegate = self;
    _redoButton.toolTipTextHighlighted = @"Redo";
    
    _recordButton1.toolTipDelegate = self;
    _recordButton1.toolTipTextSelected = @"Record\nEnabled";
    _recordButton1.toolTipTextUnselected = @"Record\nDisabled";
    _recordButton2.toolTipDelegate = self;
    _recordButton2.toolTipTextSelected = @"Record\nEnabled";
    _recordButton2.toolTipTextUnselected = @"Record\nDisabled";
    _recordButton3.toolTipDelegate = self;
    _recordButton3.toolTipTextSelected = @"Record\nEnabled";
    _recordButton3.toolTipTextUnselected = @"Record\nDisabled";
    _recordButton4.toolTipDelegate = self;
    _recordButton4.toolTipTextSelected = @"Record\nEnabled";
    _recordButton4.toolTipTextUnselected = @"Record\nDisabled";
    
    _monitorButton1.toolTipDelegate = self;
    _monitorButton1.toolTipTextSelected = @"Input Monitor\nEnabled";
    _monitorButton1.toolTipTextUnselected = @"Input Monitor\nDisabled";
    _monitorButton2.toolTipDelegate = self;
    _monitorButton2.toolTipTextSelected = @"Input Monitor\nEnabled";
    _monitorButton2.toolTipTextUnselected = @"Input Monitor\nDisabled";
    _monitorButton3.toolTipDelegate = self;
    _monitorButton3.toolTipTextSelected = @"Input Monitor\nEnabled";
    _monitorButton3.toolTipTextUnselected = @"Input Monitor\nDisabled";
    _monitorButton4.toolTipDelegate = self;
    _monitorButton4.toolTipTextSelected = @"Input Monitor\nEnabled";
    _monitorButton4.toolTipTextUnselected = @"Input Monitor\nDisabled";
    
    _muteButton1.toolTipDelegate = self;
    _muteButton1.toolTipTextSelected = @"Mute\nEnabled";
    _muteButton1.toolTipTextUnselected = @"Mute\nDisabled";
    _muteButton2.toolTipDelegate = self;
    _muteButton2.toolTipTextSelected = @"Mute\nEnabled";
    _muteButton2.toolTipTextUnselected = @"Mute\nDisabled";
    _muteButton3.toolTipDelegate = self;
    _muteButton3.toolTipTextSelected = @"Mute\nEnabled";
    _muteButton3.toolTipTextUnselected = @"Mute\nDisabled";
    _muteButton4.toolTipDelegate = self;
    _muteButton4.toolTipTextSelected = @"Mute\nEnabled";
    _muteButton4.toolTipTextUnselected = @"Mute\nDisabled";
    
    _importButtonAll.toolTipDelegate = self;
    _importButtonAll.toolTipTextHighlighted = @"Import\nAll Tracks";
    _importButton1.toolTipDelegate = self;
    _importButton1.toolTipTextHighlighted = @"Import\nOne Track";
    _importButton2.toolTipDelegate = self;
    _importButton2.toolTipTextHighlighted = @"Import\nOne Track";
    _importButton3.toolTipDelegate = self;
    _importButton3.toolTipTextHighlighted = @"Import\nOne Track";
    _importButton4.toolTipDelegate = self;
    _importButton4.toolTipTextHighlighted = @"Import\nOne Track";
    
    _exportButtonAll.toolTipDelegate = self;
    _exportButtonAll.toolTipTextHighlighted = @"Export\nAll Tracks";
    _exportButton1.toolTipDelegate = self;
    _exportButton1.toolTipTextHighlighted = @"Export\nOne Track";
    _exportButton2.toolTipDelegate = self;
    _exportButton2.toolTipTextHighlighted = @"Export\nOne Track";
    _exportButton3.toolTipDelegate = self;
    _exportButton3.toolTipTextHighlighted = @"Export\nOne Track";
    _exportButton4.toolTipDelegate = self;
    _exportButton4.toolTipTextHighlighted = @"Export\nOne Track";
    
    _clearButtonAll.toolTipDelegate = self;
    _clearButtonAll.toolTipTextSelected = @"Confirm\nClear All";
    _clearButton1.toolTipDelegate = self;
    _clearButton1.toolTipTextSelected = @"Confirm\nClear Track";
    _clearButton2.toolTipDelegate = self;
    _clearButton2.toolTipTextSelected = @"Confirm\nClear Track";
    _clearButton3.toolTipDelegate = self;
    _clearButton3.toolTipTextSelected = @"Confirm\nClear Track";
    _clearButton4.toolTipDelegate = self;
    _clearButton4.toolTipTextSelected = @"Confirm\nClear Track";
    
    _mpeButton1.toolTipDelegate = self;
    _mpeButton1.toolTipTextHighlighted = @"MCM\nSent";
    _mpeButton2.toolTipDelegate = self;
    _mpeButton2.toolTipTextHighlighted = @"MCM\nSent";
    _mpeButton3.toolTipDelegate = self;
    _mpeButton3.toolTipTextHighlighted = @"MCM\nSent";
    _mpeButton4.toolTipDelegate = self;
    _mpeButton4.toolTipTextHighlighted = @"MCM\nSent";
}

#pragma mark - Donate Call To Action

- (void)calculateTotalForegroundTime {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    NSTimeInterval total = [prefs doubleForKey:PREF_TOTAL_FOREGROUND_TIME];
    if (_lastForegroundMoment) {
        NSTimeInterval interval = [_lastForegroundMoment timeIntervalSinceNow];
        total -= interval;
        [prefs setDouble:total forKey:PREF_TOTAL_FOREGROUND_TIME];
    }
    _lastForegroundMoment = [NSDate date];
}

- (void)checkDonateCondition {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    if (![prefs objectForKey:PREF_DONATE_VIEW_SHOWN]) {
        [self calculateTotalForegroundTime];
        if ([prefs doubleForKey:PREF_TOTAL_FOREGROUND_TIME] > (60 * 30) /* 30 minutes */) {
            [prefs setBool:YES forKey:PREF_DONATE_CONDITION_MET];
        }
    }
}

- (void)autoShowDonateButton {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    if (![prefs objectForKey:PREF_DONATE_VIEW_SHOWN] && [prefs boolForKey:PREF_DONATE_CONDITION_MET]) {
        _donateButton.hidden = NO;
    }
}

#pragma mark - Create AudioUnit

- (AUAudioUnit*)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc error:(NSError **)error {
    _audioUnit = [[MidiRecorderAudioUnit alloc] initWithComponentDescription:desc error:error];
    [_audioUnit setVC:self];
    
    _state = _audioUnit.kernelAdapter.state;
    [_midiQueueProcessor setState:_state];
    
    AudioUnitViewController* __weak weak_self = self;
    // sync the settings UI with the default settings
    dispatch_async(dispatch_get_main_queue(), ^{
        AudioUnitViewController* s = weak_self;
        if (!s) return;
        [s->_settingsViewController sync];
    });

    // get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
    AUParameterObserverToken token = [_audioUnit.parameterTree tokenByAddingParameterObserver:^(AUParameterAddress address, AUValue value) {
        dispatch_async(dispatch_get_main_queue(), ^{
            AudioUnitViewController* s = weak_self;
            if (!s) return;
            switch (address) {
                case ID_RECORD_1:
                case ID_RECORD_2:
                case ID_RECORD_3:
                case ID_RECORD_4: {
                    UIButton* record_button[MIDI_TRACKS] = { s->_recordButton1, s->_recordButton2, s->_recordButton3, s->_recordButton4 };
                    for (int t = 0; t < MIDI_TRACKS; ++t) {
                        record_button[t].selected = s->_state->track[t].recordEnabled.test();
                    }

                    [s->_mainUndoManager withUndoGroup:^{
                        [s applyRecordEnableState];
                    }];
                    break;
                }
                case ID_MONITOR_1:
                case ID_MONITOR_2:
                case ID_MONITOR_3:
                case ID_MONITOR_4: {
                    UIButton* monitor_button[MIDI_TRACKS] = { s->_monitorButton1, s->_monitorButton2, s->_monitorButton3, s->_monitorButton4 };
                    for (int t = 0; t < MIDI_TRACKS; ++t) {
                        monitor_button[t].selected = s->_state->track[t].monitorEnabled.test();
                    }
                    break;
                }
                case ID_MUTE_1:
                case ID_MUTE_2:
                case ID_MUTE_3:
                case ID_MUTE_4: {
                    UIButton* mute_button[MIDI_TRACKS] = { s->_muteButton1, s->_muteButton2, s->_muteButton3, s->_muteButton4 };
                    for (int t = 0; t < MIDI_TRACKS; ++t) {
                        mute_button[t].selected = s->_state->track[t].muteEnabled.test();
                    }
                    break;
                }
                case ID_REWIND: {
                    if (s->_state->rewindTrigger.test()) {
                        [self rewindChange];
                    }
                    break;
                }
                case ID_PLAY: {
                    [s playChange:s->_state->playActive.test()];
                    break;
                }
                case ID_RECORD: {
                    [s recordChange:s->_state->recordArmed.test()];
                    break;
                }
                case ID_REPEAT: {
                    [s repeatChange:s->_state->repeatEnabled.test()];
                    break;
                }
                case ID_GRID: {
                    s.gridButton.selected = s->_state->grid.test();
                    break;
                }
                case ID_CHASE: {
                    s.chaseButton.selected = s->_state->chase.test();
                    break;
                }
                case ID_PUNCH_INOUT: {
                    s.punchInOutButton.selected = s->_state->punchInOut.test();
                    break;
                }
            }
        });
    }];

    [_audioUnit setupParameterCallbacks:token];

    return _audioUnit;
}

#pragma mark - IBActions

#pragma mark IBAction - Routing

- (IBAction)routingPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [self updateRoutingState];
}

#pragma mark IBAction - Rewind

- (IBAction)rewindPressed:(UIButton*)sender {
    [self rewindChange];
}

- (void)rewindChange {
    [self setRecordState:NO];
    [self updateRewindState];
    _state->processedRewind.clear();
    [_tracks setContentOffset:CGPointMake(0, 0) animated:NO];
}

#pragma mark IBAction - Play

- (IBAction)playPressed:(UIButton*)sender {
    [self playChange:!_playButton.selected];
}

- (void)playChange:(BOOL)selected {
    _autoPlayFromRecord = NO;
    [self setPlayState:selected];
}

- (void)setPlayState:(BOOL)state {
    _playButton.selected = state;
    [self updatePlayState];

    if (_playButton.selected) {
        if (_state->recordArmed.test()) {
            [self startRecord];
        }
        else {
            if (![self handleFullyEmpty]) {
                _state->processedPlay.clear();
            }
        }
    }
    else {
        if (_state->recordArmed.test()) {
            [self setRecordState:NO];
            _state->processedRewind.clear();
        }
        _state->processedStop.clear();
        
        [self checkDonateCondition];
        [self autoShowDonateButton];
    }
}

#pragma mark IBAction - Record

- (IBAction)recordPressed:(UIButton*)sender {
    [self recordChange:!_recordButton.selected];
}

- (void)recordChange:(BOOL)selected {
    if (selected) {
        _autoPlayFromRecord = NO;
        
        if (_state->playActive.test()) {
            [self startRecord];
        }
        else {
            _state->transportStartSampleSeconds = 0.0;
            _state->processedRecordArmed.clear();
        }
    }
    else {
        if (_autoPlayFromRecord && !_state->repeatEnabled.test()) {
            [self setPlayState:NO];
            _state->processedStopAndRewind.clear();
        }
    }
    
    [self setRecordState:selected];
}

- (void)setRecordState:(BOOL)state {
    [_mainUndoManager withUndoGroup:^{
        self->_recordButton.selected = state;
        
        [self updateRecordState];
        [self updateRecordEnableState];
        
        if (!state) {
            AudioUnitViewController* __weak weak_self = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                AudioUnitViewController* s = weak_self;
                if (!s) return;
                [s renderPreviews];
            });
        };
    }];
}

#pragma mark IBAction - Repeat

- (IBAction)repeatPressed:(UIButton*)sender {
    [self repeatChange:!_repeatButton.selected];
}

- (void)repeatChange:(BOOL)selected {
    _repeatButton.selected = selected;
    [self updateRepeatState];
    
    if (selected) {
        if (_state->recordArmed.test()) {
            [self setRecordState:NO];
        }
    }
}

#pragma mark IBAction - Grid

- (IBAction)gridPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    [self updateGridState];
}

#pragma mark IBAction - Chase

- (IBAction)chasePressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    [self updateChaseState];
}

#pragma mark IBAction - Punch In Out

- (IBAction)punchInOutPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    [self updatePunchInOutState];
}

#pragma mark IBAction - Import All

- (IBAction)importAllPressed:(UIButton*)sender {
    [self hideMenuPopups];

    ImportMidiDocumentPickerViewController* import_midi = [[ImportMidiDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.midi-audio"] inMode:UIDocumentPickerModeImport];
    import_midi.track = -1;
    import_midi.title = @"Import all tracks";
    [import_midi setDelegate:self];
    [self presentViewController:import_midi animated:NO completion:nil];
}

#pragma mark IBAction - Export All

- (IBAction)exportAllPressed:(UIButton*)sender {
    [self hideMenuPopups];

    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* file_url = [[fm temporaryDirectory] URLByAppendingPathComponent:@"tracks.midi"];
    NSData* recorded = [_midiQueueProcessor recordedTracksAsMidiFile];
    [recorded writeToURL:file_url atomically:YES];
    
    UIDocumentPickerViewController* export_midi = [[UIDocumentPickerViewController alloc] initWithURL:file_url inMode:UIDocumentPickerModeExportToService];
    export_midi.title = @"Export all tracks";
    [export_midi setDelegate:self];
    [self presentViewController:export_midi animated:NO completion:nil];
}

#pragma mark IBAction - Clear All

- (void)clearAllMarkerPositions {
    _state->playPositionBeats = 0.0;
    _state->startPositionSet.clear();
    _state->startPositionBeats = 0.0;
    _state->stopPositionSet.clear();
    _state->stopPositionBeats = 0.0;
    _state->punchInPositionSet.clear();
    _state->punchInPositionBeats = 0.0;
    _state->punchOutPositionSet.clear();
    _state->punchOutPositionBeats = 0.0;
}

- (IBAction)clearAllPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (!sender.selected) {
        [self hideMenuPopups];

        [_mainUndoManager withUndoGroup:^{
            [self withMidiTrackViews:^(int t, MidiTrackView* view) {
                [self registerRecordedForUndo:t];
                [[self->_midiQueueProcessor recorder:t] clear];
                [view rebuild];
                [view setNeedsLayout];
            }];
            
            [self registerSettingsForUndo];
        }];
        
        [self clearAllMarkerPositions];
        [self handleFullyEmpty];
    }
}

- (BOOL)handleFullyEmpty {
    if (![self hasRecordedDuration] && _state->stopPositionBeats.load() == 0.0) {
        // since the recorder is fully empty, reset all markers
        [self clearAllMarkerPositions];
        
        // schedule stopping and rewinding the transport
        [self setPlayState:NO];
        _state->processedRewind.clear();
        
        return YES;
    }
    
    return NO;
}

#pragma mark IBAction - Settings

- (IBAction)settingsPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    _settingsView.alpha = 0.0;
    _settingsView.hidden = !sender.selected;
    
    if (_aboutView.hidden && _donateView.hidden) {
        if (sender.selected) {
            [UIView animateWithDuration:0.2
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^() {
                                 self->_settingsView.alpha = 1.0;
                             }
                             completion:^(BOOL finished) {}];
        }
    }
    else {
        _settingsView.alpha = 1.0;
        [self closeAboutView:nil];
        [self closeDonateView:nil];
    }
}

- (void)closeSettingsView {
    [self closeSettingsView:nil];
}

- (IBAction)closeSettingsView:(id)sender {
    _settingsButton.selected = NO;
    _settingsView.hidden = YES;
}

#pragma mark IBAction - About

- (IBAction)aboutPressed:(UIButton*)sender {
    
    sender.selected = !sender.selected;
    
    _aboutView.alpha = 0.0;
    _aboutView.hidden = !sender.selected;
    
    if (_settingsView.hidden && _donateView.hidden) {
        if (sender.selected) {
            [UIView animateWithDuration:0.2
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^() {
                                 self->_aboutView.alpha = 1.0;
                             }
                             completion:^(BOOL finished) {}];
        }
    }
    else {
        self->_aboutView.alpha = 1.0;
        
        [self closeSettingsView:nil];
        [self closeDonateView:nil];
    }
}
- (void)closeAboutView {
    [self closeAboutView:nil];
}

- (IBAction)closeAboutView:(id)sender {
    _aboutButton.selected = NO;
    _aboutView.hidden = YES;
}

#pragma mark IBAction - Donate

- (IBAction)donatePressed:(UIButton*)sender {
    _donateView.alpha = 0.0;
    _donateView.hidden = NO;
    
    if (_settingsView.hidden && _aboutView.hidden) {
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^() {
                             self->_donateView.alpha = 1.0;
                         }
                         completion:^(BOOL finished) {}];
    }
    else {
        self->_donateView.alpha = 1.0;
        
        [self closeSettingsView:nil];
        [self closeAboutView:nil];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:@(YES) forKey:PREF_DONATE_VIEW_SHOWN];
    _donateButton.hidden = YES;
}

- (void)closeDonateView {
    [self closeDonateView:nil];
}

- (IBAction)closeDonateView:(id)sender {
    _donateButton.selected = NO;
    _donateView.hidden = YES;
}

#pragma mark IBAction - Monitor Enable

- (IBAction)monitorPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [self updateMonitorState];
}

#pragma mark IBAction - Record Enable

- (IBAction)recordEnablePressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [_mainUndoManager withUndoGroup:^{
        [self updateRecordEnableState];
    }];
}

#pragma mark IBAction - MPE

- (IBAction)mpePressed:(UIButton*)sender {
    NSUInteger index = [@[_mpeButton1, _mpeButton2, _mpeButton3, _mpeButton4] indexOfObject:sender];
    if (index == NSNotFound) {
        return;
    }

    _state->processedSendMCM[index].clear();
}

#pragma mark IBAction - Mute

- (IBAction)mutePressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [self updateMuteState];
}

#pragma mark IBAction - Menu

- (IBAction)menuPressed:(UIButton*)sender {
    [self hideMenuPopups];

    UIView* menu_popup_view = nil;
    
    if (sender == _menuButtonAll)       menu_popup_view = _menuPopupAll;
    else if (sender == _menuButton1)    menu_popup_view = _menuPopup1;
    else if (sender == _menuButton2)    menu_popup_view = _menuPopup2;
    else if (sender == _menuButton3)    menu_popup_view = _menuPopup3;
    else if (sender == _menuButton4)    menu_popup_view = _menuPopup4;
    
    if (menu_popup_view != nil) {
        menu_popup_view.alpha = 0.0;
        for (UIButton* b in menu_popup_view.subviews) {
            if ([b isKindOfClass:UIButton.class]) {
                b.selected = NO;
                b.alpha = 0.0;
            }
        }
        
        menu_popup_view.hidden = NO;
        
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^() {
                             menu_popup_view.alpha = 1.0;
                             for (UIView* v in menu_popup_view.subviews) {
                                 if ([v isKindOfClass:UIButton.class]) {
                                     v.alpha = 1.0;
                                 }
                             }
                         }
                         completion:^(BOOL finished) {}];
    }
}

- (void)hideMenuPopups {
    _menuPopupAll.hidden = YES;
    
    UIView* menu_popup[MIDI_TRACKS] = { _menuPopup1, _menuPopup2, _menuPopup3, _menuPopup4 };
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        menu_popup[t].hidden = YES;
    }
}

- (IBAction)closeMenuPressed:(UIButton*)sender {
    [self hideMenuPopups];
}

#pragma mark IBAction - Import

- (IBAction)importPressed:(UIButton*)sender {
    [self hideMenuPopups];

    NSUInteger index = [@[_importButton1, _importButton2, _importButton3, _importButton4] indexOfObject:sender];
    if (index == NSNotFound) {
        return;
    }
    
    ImportMidiDocumentPickerViewController* import_midi = [[ImportMidiDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.midi-audio"] inMode:UIDocumentPickerModeImport];
    import_midi.track = (int)index;
    import_midi.title = [NSString stringWithFormat:@"Import track %d", (int)index+1];
    [import_midi setDelegate:self];
    [self presentViewController:import_midi animated:NO completion:nil];
}

#pragma mark IBAction - Export

- (IBAction)exportPressed:(UIButton*)sender {
    [self hideMenuPopups];

    NSUInteger index = [@[_exportButton1, _exportButton2, _exportButton3, _exportButton4] indexOfObject:sender];
    if (index == NSNotFound) {
        return;
    }

    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* file_url = [[fm temporaryDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"track%d.midi", (int)index+1]];
    NSData* recorded = [_midiQueueProcessor recordedTrackAsMidiFile:(int)index];
    [recorded writeToURL:file_url atomically:YES];
    
    UIDocumentPickerViewController* export_midi = [[UIDocumentPickerViewController alloc] initWithURL:file_url inMode:UIDocumentPickerModeExportToService];
    export_midi.title = [NSString stringWithFormat:@"Export track %d", (int)index+1];
    [export_midi setDelegate:self];
    [self presentViewController:export_midi animated:NO completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        if (urls.count == 0) {
            return;
        }
        
        NSURL* url = urls[0];
        NSData* contents = [NSData dataWithContentsOfURL:url];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

        [_mainUndoManager withUndoGroup:^{
            int track = ((ImportMidiDocumentPickerViewController*)controller).track;
            [self->_midiQueueProcessor midiFileToRecordedTrack:contents ordinal:track];
        }];

        [self withMidiTrackViews:^(int t, MidiTrackView* view) {
            [view rebuild];
            [view setNeedsLayout];
        }];
        
        [self renderPreviews];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
}

#pragma mark IBAction - Clear

- (IBAction)clearPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (!sender.selected) {
        [self hideMenuPopups];

        NSUInteger index = [@[_clearButton1, _clearButton2, _clearButton3, _clearButton4] indexOfObject:sender];
        if (index == NSNotFound) {
            return;
        }
        
        int t = (int)index;
        [_mainUndoManager withUndoGroup:^{
            [self registerRecordedForUndo:t];
            [[self->_midiQueueProcessor recorder:t] clear];
        }];
        
        [self withMidiTrack:t view:^(MidiTrackView *view) {
            [view rebuild];
            [view setNeedsLayout];
        }];
        
        [self handleFullyEmpty];
    }
}

#pragma mark IBAction - Undo / Redo

- (IBAction)undoPressed:(UIButton*)sender {
    _restoringState = YES;
    [_mainUndoManager undo];
    _restoringState = NO;
}

- (IBAction)redoPressed:(UIButton*)sender {
    _restoringState = YES;
    [_mainUndoManager redo];
    _restoringState = NO;
}

#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch {
    // only pan the overlay area on the timeline area
    if (gestureRecognizer == _punchOverlayPanGesture) {
        if ([touch locationInView:_tracks].y > _timeline.frame.size.height) {
            return NO;
        }
    }
    if (gestureRecognizer == _cropOverlayPanGesture) {
        if ([touch locationInView:_tracks].y > _timeline.frame.size.height) {
            return NO;
        }
    }

    // only use the timeline tap gesture on the timeline area
    if (gestureRecognizer == _timelineTapGesture) {
        if ([touch locationInView:_tracks].y > _timeline.frame.size.height) {
            return NO;
        }
    }

    return YES;
}

#pragma mark IBAction - Gestures

- (IBAction)timelineTapGesture:(UITapGestureRecognizer*)gesture {
    [self setPlayDurationForGesture:gesture];
}

- (IBAction)cropLeftDoubleTapGesture:(UITapGestureRecognizer*)sender {
    _state->startPositionSet.clear();
    _state->startPositionBeats = 0.0;
}

- (IBAction)cropRightDoubleTapGesture:(UITapGestureRecognizer*)sender {
    _state->stopPositionSet.clear();
    _state->stopPositionBeats = [self maxRecordedDuration];
    _state->startPositionBeats = MIN(_state->startPositionBeats.load(), _state->stopPositionBeats.load() - 1.0);
}

- (IBAction)punchInDoubleTapGesture:(UITapGestureRecognizer*)sender {
    _state->punchInPositionSet.clear();
    _state->punchInPositionBeats = 0.0;
}

- (IBAction)punchOutDoubleTapGesture:(UITapGestureRecognizer*)sender {
    _state->punchOutPositionSet.clear();
    _state->punchOutPositionBeats = _state->maxDuration.load();
}

- (double)calculateBeatPositionForGesture:(UIGestureRecognizer*)gesture {
    return MIN(MAX([gesture locationInView:_tracks].x / PIXELS_PER_BEAT, 0.0), _timelineWidth.constant / PIXELS_PER_BEAT);
}

- (void)setPlayDurationForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        _state->playPositionBeats = [self calculateBeatPositionForGesture:gesture];
    }
}

- (void)setCropLeftForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        _state->startPositionSet.test_and_set();
        _state->startPositionBeats = MIN([self calculateBeatPositionForGesture:gesture], _state->stopPositionBeats.load() - 1.0);
    }
}

- (void)setCropRightForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        _state->stopPositionSet.test_and_set();
        _state->stopPositionBeats = MAX([gesture locationInView:_tracks].x / PIXELS_PER_BEAT, _state->startPositionBeats.load() + 1.0);
    }
}

- (void)setCropOverlayForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        double position = [self calculateBeatPositionForGesture:gesture];
        double delta = 0.0;
        if (_overlayPanStart == -1.0) {
            _overlayPanStart = position;
            _overlayPanStartFirstPosition = _state->startPositionBeats.load();
        }
        else {
            delta = position - _overlayPanStart;
        }
        double crop_start = _state->startPositionBeats;
        double crop_stop = _state->stopPositionBeats;
        double crop_range = crop_stop - crop_start;
        _state->startPositionSet.test_and_set();
        _state->stopPositionSet.test_and_set();
        _state->startPositionBeats = MIN(MAX(_overlayPanStartFirstPosition + delta, 0.0), _timelineWidth.constant / PIXELS_PER_BEAT - crop_range);
        _state->stopPositionBeats = _state->startPositionBeats + crop_range;
        _state->startPositionBeats = MIN(_state->startPositionBeats.load(), _state->stopPositionBeats.load() - 1.0);
        _state->stopPositionBeats = MAX(_state->stopPositionBeats.load(), _state->startPositionBeats.load() + 1.0);
    }
}

- (void)setPunchInForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        _state->punchInPositionSet.test_and_set();
        _state->punchInPositionBeats = MIN([self calculateBeatPositionForGesture:gesture], _state->punchOutPositionBeats.load() - 1.0);
    }
}

- (void)setPunchOutForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        _state->punchOutPositionSet.test_and_set();
        _state->punchOutPositionBeats = MAX([self calculateBeatPositionForGesture:gesture], _state->punchInPositionBeats.load() + 1.0);
    }
}

- (void)setPunchOverlayForGesture:(UIGestureRecognizer*)gesture {
    if (gesture.numberOfTouches == 1) {
        double position = [self calculateBeatPositionForGesture:gesture];
        double delta = 0.0;
        if (_overlayPanStart == -1.0) {
            _overlayPanStart = position;
            _overlayPanStartFirstPosition = _state->punchInPositionBeats.load();
        }
        else {
            delta = position - _overlayPanStart;
        }
        double punch_in = _state->punchInPositionBeats;
        double punch_out = _state->punchOutPositionBeats;
        double punch_range = punch_out - punch_in;
        _state->punchInPositionSet.test_and_set();
        _state->punchOutPositionSet.test_and_set();
        _state->punchInPositionBeats = MIN(MAX(_overlayPanStartFirstPosition + delta, 0.0), _timelineWidth.constant / PIXELS_PER_BEAT - punch_range);
        _state->punchOutPositionBeats = _state->punchInPositionBeats + punch_range;
        _state->punchInPositionBeats = MIN(_state->punchInPositionBeats.load(), _state->punchOutPositionBeats.load() - 1.0);
        _state->punchOutPositionBeats = MAX(_state->punchOutPositionBeats.load(), _state->punchInPositionBeats.load() + 1.0);
    }
}

- (IBAction)markerPanGesture:(UIPanGestureRecognizer*)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            [self resetAutomaticPanning];
        }
        
        _activePannedMarker = gesture.view;
        if (_activePannedMarker == _playhead) {
            [self setPlayDurationForGesture:gesture];
        }
        else if (_activePannedMarker == _cropLeft) {
            [self setCropLeftForGesture:gesture];
        }
        else if (_activePannedMarker == _cropRight) {
            [self setCropRightForGesture:gesture];
        }
        else if (_activePannedMarker == _cropOverlayCenter) {
            [self setCropOverlayForGesture:gesture];
        }
        else if (_activePannedMarker == _punchIn) {
            [self setPunchInForGesture:gesture];
        }
        else if (_activePannedMarker == _punchOut) {
            [self setPunchOutForGesture:gesture];
        }
        else if (_activePannedMarker == _punchOverlay) {
            [self setPunchOverlayForGesture:gesture];
        }

        const CGPoint pos = [gesture locationInView:_tracks.superview];
        const CGRect frame = _tracks.frame;
        const CGFloat pan_margin = 5.0;
        const CGFloat pan_scale = 2.0;
        
        CGFloat left_boundary = frame.origin.x - 10.0 + pan_margin;
        CGFloat right_boundary = frame.origin.x + frame.size.width - 10.0 - pan_margin;
        CGFloat pan_x = 0.0;
        if (pos.x < left_boundary) {
            pan_x = (pos.x - left_boundary) / pan_scale;
        }
        else if (pos.x > right_boundary) {
            pan_x = (pos.x - right_boundary) / pan_scale;
        }
        if (ABS(pan_x) < 1.0) {
            CGFloat sign = (pan_x < 0.0) ? -1.0 : 1.0;
            pan_x = sign * pow(ABS(pan_x), 1.0/4.0);
        }
        
        _autoPan = CGPointMake(pan_x, 0);
    }
    else {
        // when grid is active, round the marker to the nearest beat boundary
        if (_state->grid.test()) {
            if (_activePannedMarker == _playhead) {
                _state->playPositionBeats = round(_state->playPositionBeats.load());
            }
            else if (_activePannedMarker == _cropLeft) {
                _state->startPositionBeats = round(_state->startPositionBeats.load());
            }
            else if (_activePannedMarker == _cropRight) {
                _state->stopPositionBeats = round(_state->stopPositionBeats.load());
            }
            else if (_activePannedMarker == _cropOverlayCenter) {
                _state->startPositionBeats = round(_state->startPositionBeats.load());
                _state->stopPositionBeats = round(_state->stopPositionBeats.load());
            }
            else if (_activePannedMarker == _punchIn) {
                _state->punchInPositionBeats = round(_state->punchInPositionBeats.load());
            }
            else if (_activePannedMarker == _punchOut) {
                _state->punchOutPositionBeats = round(_state->punchOutPositionBeats.load());
            }
            else if (_activePannedMarker == _punchOverlay) {
                _state->punchInPositionBeats = round(_state->punchInPositionBeats.load());
                _state->punchOutPositionBeats = round(_state->punchOutPositionBeats.load());
            }
        }
        
        // reset the state of the punch overlay panning
        if (_activePannedMarker == _punchOverlay ||
            _activePannedMarker == _cropOverlayCenter) {
            _overlayPanStart = -1.0;
            _overlayPanStartFirstPosition = -1.0;
        }

        [self resetAutomaticPanning];
        _activePannedMarker = nil;
    }
}

#pragma mark - State

- (void)readFullStateFromDict:(NSDictionary*)dict {
    AudioUnitViewController* __weak weak_self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        AudioUnitViewController* s = weak_self;
        if (!s) return;

        @synchronized(s) {
            s->_restoringState = YES;
            
            [s->_mainUndoManager withUndoGroup:^{
                [s readRecordingsFromDict:dict];
                
                [s registerSettingsForUndo];
                [s readSettingsFromDict:dict];
            }];
            
            s->_restoringState = NO;
            
            [self handleFullyEmpty];
        }
    });
}

- (void)readSettingsFromDict:(NSDictionary*)dict {
    id start_position_set = [dict objectForKey:@"StartPositionSet"];
    id stop_position_set = [dict objectForKey:@"StopPositionSet"];
    id start_position_beats = [dict objectForKey:@"StartPositionBeats"];
    id stop_position_beats = [dict objectForKey:@"StopPositionBeats"];
    id play_position_beats = [dict objectForKey:@"PlayPositionBeats"];
    id punchin_position_set = [dict objectForKey:@"PunchInPositionSet"];
    id punchout_position_set = [dict objectForKey:@"PunchOutPositionSet"];
    id punchin_position_beats = [dict objectForKey:@"PunchInPositionBeats"];
    id punchout_position_beats = [dict objectForKey:@"PunchOutPositionBeats"];

    id routing = [dict objectForKey:@"Routing"];
    
    id record = [dict objectForKey:@"Record"];
    id repeat = [dict objectForKey:@"Repeat"];
    id grid = [dict objectForKey:@"Grid"];
    id chase = [dict objectForKey:@"Chase"];
    id punch_inout = [dict objectForKey:@"PunchInOut"];

    id record1 = [dict objectForKey:@"Record1"];
    id record2 = [dict objectForKey:@"Record2"];
    id record3 = [dict objectForKey:@"Record3"];
    id record4 = [dict objectForKey:@"Record4"];
    id monitor1 = [dict objectForKey:@"Monitor1"];
    id monitor2 = [dict objectForKey:@"Monitor2"];
    id monitor3 = [dict objectForKey:@"Monitor3"];
    id monitor4 = [dict objectForKey:@"Monitor4"];
    id mute1 = [dict objectForKey:@"Mute1"];
    id mute2 = [dict objectForKey:@"Mute2"];
    id mute3 = [dict objectForKey:@"Mute3"];
    id mute4 = [dict objectForKey:@"Mute4"];
    
    id send_mpe = [dict objectForKey:@"SendMpeConfigOnPlay"];
    id mpe_details = [dict objectForKey:@"DisplayMpeConfigDetails"];
    id auto_trim = [dict objectForKey:@"AutoTrimRecordings"];
    id show_tool_tips = [dict objectForKey:@"ShowToolTips"];

    if (start_position_set) {
        if ([start_position_set boolValue]) _state->startPositionSet.test_and_set();
        else                                _state->startPositionSet.clear();
    }
    if (stop_position_set) {
        if ([stop_position_set boolValue]) _state->stopPositionSet.test_and_set();
        else                               _state->stopPositionSet.clear();
    }
    if (start_position_beats) {
        _state->startPositionBeats = [start_position_beats doubleValue];
    }
    if (stop_position_beats) {
        _state->stopPositionBeats = [stop_position_beats doubleValue];
    }
    if (play_position_beats) {
        _state->playPositionBeats = [play_position_beats doubleValue];
    }
    if (punchin_position_set) {
        if ([punchin_position_set boolValue]) _state->punchInPositionSet.test_and_set();
        else                                  _state->punchInPositionSet.clear();
    }
    if (punchout_position_set) {
        if ([punchout_position_set boolValue]) _state->punchOutPositionSet.test_and_set();
        else                                   _state->punchOutPositionSet.clear();
    }
    if (punchin_position_beats) {
        _state->punchInPositionBeats = [punchin_position_beats doubleValue];
    }
    if (punchout_position_beats) {
        _state->punchOutPositionBeats = [punchout_position_beats doubleValue];
    }

    if (routing) {
        _routingButton.selected = [routing boolValue];
    }

    if (record) {
        _recordButton.selected = [record boolValue];
    }
    if (repeat) {
        _repeatButton.selected = [repeat boolValue];
    }
    if (grid) {
        _gridButton.selected = [grid boolValue];
    }
    if (chase) {
        _chaseButton.selected = [chase boolValue];
    }
    if (punch_inout) {
        _punchInOutButton.selected = [punch_inout boolValue];
    }

    if (record1) {
        _recordButton1.selected = [record1 boolValue];
    }
    if (record2) {
        _recordButton2.selected = [record2 boolValue];
    }
    if (record3) {
        _recordButton3.selected = [record3 boolValue];
    }
    if (record4) {
        _recordButton4.selected = [record4 boolValue];
    }

    if (monitor1) {
        _monitorButton1.selected = [monitor1 boolValue];
    }
    if (monitor2) {
        _monitorButton2.selected = [monitor2 boolValue];
    }
    if (monitor3) {
        _monitorButton3.selected = [monitor3 boolValue];
    }
    if (monitor4) {
        _monitorButton4.selected = [monitor4 boolValue];
    }

    if (mute1) {
        _muteButton1.selected = [mute1 boolValue];
    }
    if (mute2) {
        _muteButton2.selected = [mute2 boolValue];
    }
    if (mute3) {
        _muteButton3.selected = [mute3 boolValue];
    }
    if (mute4) {
        _muteButton4.selected = [mute4 boolValue];
    }
    
    if (send_mpe) {
        if ([send_mpe boolValue]) _state->sendMpeConfigOnPlay.test_and_set();
        else                      _state->sendMpeConfigOnPlay.clear();
    }
    if (mpe_details) {
        if ([mpe_details boolValue]) _state->displayMpeConfigDetails.test_and_set();
        else                         _state->displayMpeConfigDetails.clear();
    }
    if (auto_trim) {
        if ([auto_trim boolValue]) _state->autoTrimRecordings.test_and_set();
        else                       _state->autoTrimRecordings.clear();
    }
    if (show_tool_tips) {
        if ([show_tool_tips boolValue]) _state->showToolTips.test_and_set();
        else                            _state->showToolTips.clear();
    }

    [self updateRoutingState];
    [self updateRecordState];
    [self updateRepeatState];
    [self updateGridState];
    [self updateChaseState];
    [self updatePunchInOutState];
    [self updateMonitorState];
    [self updateRecordEnableState];
    [self updateMuteState];
    
    [_settingsViewController sync];
}

- (void)readRecordingsFromDict:(NSDictionary*)dict {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        NSString* key = [NSString stringWithFormat:@"Recorder%d", t];
        id recorded = [dict objectForKey:key];
        if (recorded) {
            [[_midiQueueProcessor recorder:t] dictToRecorded:recorded];
        }
    }
}

- (void)currentFullStateToDict:(NSMutableDictionary*)dict {
    [dict addEntriesFromDictionary:[self currentSettingsToDict]];
    [dict addEntriesFromDictionary:[self currentRecordingsToDict]];
}

- (NSDictionary*)currentSettingsToDict {
    return @{
        @"StartPositionSet" : @(_state->startPositionSet.test()),
        @"StopPositionSet" : @(_state->stopPositionSet.test()),
        @"StartPositionBeats" : @(_state->startPositionBeats.load()),
        @"StopPositionBeats" : @(_state->stopPositionBeats.load()),
        @"PlayPositionBeats" : @(_state->playPositionBeats.load()),
        @"PunchInPositionSet" : @(_state->punchInPositionSet.test()),
        @"PunchOutPositionSet" : @(_state->punchOutPositionSet.test()),
        @"PunchInPositionBeats" : @(_state->punchInPositionBeats.load()),
        @"PunchOutPositionBeats" : @(_state->punchOutPositionBeats.load()),
        @"Routing" : @(_routingButton.selected),
        @"Record" : @(_recordButton.selected),
        @"Repeat" : @(_repeatButton.selected),
        @"Grid" : @(_gridButton.selected),
        @"Chase" : @(_chaseButton.selected),
        @"PunchInOut" : @(_punchInOutButton.selected),
        @"Record1" : @(_recordButton1.selected),
        @"Record2" : @(_recordButton2.selected),
        @"Record3" : @(_recordButton3.selected),
        @"Record4" : @(_recordButton4.selected),
        @"Monitor1" : @(_monitorButton1.selected),
        @"Monitor2" : @(_monitorButton2.selected),
        @"Monitor3" : @(_monitorButton3.selected),
        @"Monitor4" : @(_monitorButton4.selected),
        @"Mute1" : @(_muteButton1.selected),
        @"Mute2" : @(_muteButton2.selected),
        @"Mute3" : @(_muteButton3.selected),
        @"Mute4" : @(_muteButton4.selected),
        @"SendMpeConfigOnPlay" : @(_state->sendMpeConfigOnPlay.test()),
        @"DisplayMpeConfigDetails" : @(_state->displayMpeConfigDetails.test()),
        @"AutoTrimRecordings" : @(_state->autoTrimRecordings.test()),
        @"ShowToolTips" : @(_state->showToolTips.test())
    };
}

- (NSDictionary*)currentRecordingsToDict {
    NSMutableDictionary* result = [NSMutableDictionary new];
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        [result setObject:[[_midiQueueProcessor recorder:t] recordedAsDict] forKey:[NSString stringWithFormat:@"Recorder%d", t]];
    }
    return result;
}

- (MidiRecorderState*)state {
    return _state;
}

#pragma mark Update State

- (void)updateRoutingState {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_routingButton.selected) {
            _state->track[t].sourceCable = t;
        }
        else {
            _state->track[t].sourceCable = 0;
        }
    }
}

- (void)updateRecordEnableState {
    UIButton* record_button[MIDI_TRACKS] = { _recordButton1, _recordButton2, _recordButton3, _recordButton4 };

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_state->track[t].recordEnabled.test() != record_button[t].selected) {
            _state->hostParamChange(ID_RECORD_1 + t, record_button[t].selected);
        }
    }
    
    [self applyRecordEnableState];
}

- (void)applyRecordEnableState {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        [_midiQueueProcessor recorder:t].record = (_recordButton.selected && _state->track[t].recordEnabled.test());
    }
}

- (void)updateMonitorState {
    UIButton* monitor_button[MIDI_TRACKS] = { _monitorButton1, _monitorButton2, _monitorButton3, _monitorButton4 };

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_state->track[t].monitorEnabled.test() != monitor_button[t].selected) {
            _state->hostParamChange(ID_MONITOR_1 + t, monitor_button[t].selected);
        }
    }
}

- (void)updateMuteState {
    UIButton* mute_button[MIDI_TRACKS] = { _muteButton1, _muteButton2, _muteButton3, _muteButton4 };

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_state->track[t].muteEnabled.test() != mute_button[t].selected) {
            _state->hostParamChange(ID_MUTE_1 + t, mute_button[t].selected);
        }
    }
}

- (void)updatePlayState {
    if (_state->playActive.test() != _playButton.selected) {
        _state->hostParamChange(ID_PLAY, _playButton.selected);
    }
}

- (void)updateRecordState {
    if (_state->recordArmed.test() != _recordButton.selected) {
        _state->hostParamChange(ID_RECORD, _recordButton.selected);
    }
}

- (void)updateRepeatState {
    if (_repeatButton.selected) _state->processedActivateRepeat.clear();
    else                        _state->processedDeactivateRepeat.clear();
    
    if (_state->repeatEnabled.test() != _repeatButton.selected) {
        _state->hostParamChange(ID_REPEAT, _repeatButton.selected);
    }
}

- (void)updateRewindState {
    _rewindButton.selected = NO;
    _state->hostParamChange(ID_REWIND, _rewindButton.selected);
}

- (void)updateGridState {
    if (_state->grid.test() != _gridButton.selected) {
        _state->hostParamChange(ID_GRID, _gridButton.selected);
    }
}

- (void)updateChaseState {
    if (_state->chase.test() != _chaseButton.selected) {
        _state->hostParamChange(ID_CHASE, _chaseButton.selected);
    }
}

- (void)updatePunchInOutState {
    if (_state->punchInOut.test() != _punchInOutButton.selected) {
        _state->hostParamChange(ID_PUNCH_INOUT, _punchInOutButton.selected);
    }
}

#pragma mark - Rendering

- (void)viewDidLayoutSubviews {
    // dynamically adapt the undo/redo section of the toolbar based
    // on the available width
    if (self.view.bounds.size.width >= 768) {
        _redoButton.hidden = NO;
        _chaseTrailing.constant = -2.0 - 3.0 * (4.0 + _redoButton.bounds.size.width) / 4.0;
        _undoLeading.constant = 4.0 + (4.0 + _redoButton.bounds.size.width) / 2.0;
    }
    else if (self.view.bounds.size.width >= 686) {
        _redoButton.hidden = NO;
        _chaseTrailing.constant = -2.0 - (4.0 + _redoButton.bounds.size.width) / 2.0;
        _undoLeading.constant = 4.0;
    }
    else {
        _redoButton.hidden = YES;
        _chaseTrailing.constant = -2.0;
        _undoLeading.constant = 4.0;
    }

    [_timeline setNeedsLayout];

    [self withMidiTrackViews:^(int t, MidiTrackView* view) {
        [view rebuild];
        [view setNeedsLayout];
    }];
}

- (void)checkActivityIndicators {
    ActivityIndicatorView* inputs[MIDI_TRACKS] = { _midiActivityInput1, _midiActivityInput2, _midiActivityInput3, _midiActivityInput4 };
    ActivityIndicatorView* outputs[MIDI_TRACKS] = { _midiActivityOutput1, _midiActivityOutput2, _midiActivityOutput3, _midiActivityOutput4 };

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        inputs[t].showActivity = !_state->track[t].processedActivityInput.test_and_set();
        outputs[t].showActivity = !_state->track[t].processedActivityOutput.test_and_set();
    }
}

- (void)handleScheduledActions {
    // rewind UI
    if (!_state->processedUIRewind.test_and_set()) {
        [self positionViewLocation];
    }

    // stop and rewind UI
    if (!_state->processedUIStopAndRewind.test_and_set()) {
        [self setPlayState:NO];
        _state->processedRewind.clear();
    }

    // play UI
    if (!_state->processedUIPlay.test_and_set()) {
        [self setPlayState:YES];
    }

    // stop UI
    if (!_state->processedUIStop.test_and_set()) {
        [self setPlayState:NO];
    }

    // end recording UI
    if (!_state->processedUIEndRecord.test_and_set()) {
        [self setRecordState:NO];
    }
    
    // rebuild track UI
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (!_state->processedUIRebuildPreview[t].test_and_set()) {
            [self withMidiTrack:t view:^(MidiTrackView *view) {
                [view rebuild];
                [view setNeedsLayout];
            }];
        }
    }
}

- (void)renderPreviews {
    // update the previews and the timeline
    __block double max_duration = _state->stopPositionBeats;
    
    [self withMidiTrackViews:^(int t, MidiTrackView* view) {
        max_duration = MAX(max_duration, [self->_midiQueueProcessor recorder:t].activeDuration);
        
        if (self->_recordButton.selected) {
            [view setNeedsLayout];
        }
    }];
    
    _state->maxDuration = max_duration;
    _timelineWidth.constant = _state->maxDuration * PIXELS_PER_BEAT;
}

- (double)maxRecordedDuration {
    __block double max_duration = 0.0;
    
    [self withMidiTrackViews:^(int t, MidiTrackView* view) {
        max_duration = MAX(max_duration, [self->_midiQueueProcessor recorder:t].activeDuration);
    }];

    return max_duration;
}

- (BOOL)hasRecordedDuration {
    BOOL has_recorder_duration = NO;
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if ([_midiQueueProcessor recorder:t].activeDuration != 0.0) {
            has_recorder_duration = YES;
            break;
        }
    }
    
    return has_recorder_duration;
}

- (void)positionViewLocation {
    if (!_playhead.hidden && _state->chase.test() && !_activePannedMarker) {
        CGFloat play_position = _state->playPositionBeats * PIXELS_PER_BEAT;
        CGFloat content_offset;
        if (play_position < _tracks.frame.size.width / 2.0) {
            content_offset = 0.0;
        }
        else {
            content_offset = MAX(MIN(play_position - _tracks.frame.size.width / 2.0,
                                 _tracks.contentSize.width - _tracks.bounds.size.width + _tracks.contentInset.left), 0.0);
        }
        [_tracks setContentOffset:CGPointMake(content_offset, 0) animated:NO];
    }
}

- (void)renderPlayhead {
    // playhead position
    _state->playPositionBeats = MIN(_state->playPositionBeats.load(), _state->maxDuration.load());
    _playheadLeading.constant = _state->playPositionBeats * PIXELS_PER_BEAT;
    _playhead.hidden = _state->stopPositionBeats.load() == 0.0;

    // scroll view location
    if (_playButton.selected || _recordButton.selected) {
        [self positionViewLocation];
    }
    
    // start position crop marker
    _state->startPositionBeats = MIN(_state->startPositionBeats.load(), _state->maxDuration.load());
    _cropOverlayLeft.hidden = _playhead.hidden;
    _cropLeft.hidden = _playhead.hidden;
    if (!_cropLeft.hidden) {
        if (!_state->startPositionSet.test() && !_activePannedMarker) {
            _state->startPositionBeats = 0.0;
        }
        _cropLeftLeading.constant = _state->startPositionBeats * PIXELS_PER_BEAT;
    }

    // stop position crop marker
    if (!_state->stopPositionSet.test() && !_activePannedMarker) {
        _state->stopPositionBeats = _state->maxDuration.load();
    }
    _cropRightLeading.constant = _state->stopPositionBeats * PIXELS_PER_BEAT;
    
    // crop center overlay
    _cropOverlayCenter.hidden = _playhead.hidden;

    // punch in marker
    _state->punchInPositionBeats = MIN(_state->punchInPositionBeats.load(), _state->maxDuration.load());
    _punchIn.hidden = _playhead.hidden || !_punchInOutButton.selected;
    if (!_punchIn.hidden) {
        if (!_state->punchInPositionSet.test() && !_activePannedMarker) {
            _state->punchInPositionBeats = 0.0;
        }
        _punchInLeading.constant = _state->punchInPositionBeats * PIXELS_PER_BEAT;
    }

    // punch out marker
    _state->punchOutPositionBeats = MIN(_state->punchOutPositionBeats.load(), _state->maxDuration.load());
    _punchOut.hidden = _playhead.hidden || !_punchInOutButton.selected;
    if (!_punchOut.hidden) {
        if (!_state->punchOutPositionSet.test() && !_activePannedMarker) {
            _state->punchOutPositionBeats = _state->maxDuration.load();
        }
        _punchOutLeading.constant = _state->punchOutPositionBeats * PIXELS_PER_BEAT;
    }
    
    // punch overlay
    _punchOverlay.hidden = _punchIn.hidden || _punchOut.hidden;
}

- (void)renderMpeIndicators {
    bool refresh_mpe_buttons = !_state->processedUIMpeConfigChange.test_and_set();

    MPEButton* mpe_button[MIDI_TRACKS] = { _mpeButton1, _mpeButton2, _mpeButton3, _mpeButton4 };
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        MPEState& state = _state->track[t].mpeState;
        BOOL button_hidden = (state.enabled == false);
        if (button_hidden != mpe_button[t].hidden || refresh_mpe_buttons) {
            mpe_button[t].hidden = button_hidden;
            NSString* mpe_label = @"";
            if (state.enabled) {
                mpe_label = @"MPE";
                if (_state->displayMpeConfigDetails.test()) {
                    if (state.zone1Active) {
                        mpe_label = [mpe_label stringByAppendingFormat:@" L:%d", state.zone1Members.load()];
                    }
                    if (state.zone2Active) {
                        mpe_label = [mpe_label stringByAppendingFormat:@" U:%d", state.zone2Members.load()];
                    }
                }
            }
            
            [mpe_button[t] setTitle:mpe_label forState:UIControlStateNormal];
        }
    }
}

- (void)applyAutoPan {
    if (_autoPan.x != 0.0f) {
        CGFloat offset_x = _tracks.contentOffset.x + _autoPan.x;
        offset_x = MAX(MIN(offset_x, _tracks.contentSize.width - _tracks.bounds.size.width + _tracks.contentInset.left), 0.0);
        [_tracks setContentOffset:CGPointMake(offset_x, 0) animated:NO];

        if (_activePannedMarker == _playhead) {
            [self setPlayDurationForGesture:_playheadPanGesture];
        }
        else if (_activePannedMarker == _cropLeft) {
            [self setCropLeftForGesture:_cropLeftPanGesture];
        }
        else if (_activePannedMarker == _cropRight) {
            [self setCropRightForGesture:_cropRightPanGesture];
        }
    }
}

- (void)resetAutomaticPanning {
    _autoPan = CGPointZero;
}

- (void)renderloop {
    if (_audioUnit) {
        _renderReady = YES;
        
        [self checkActivityIndicators];

        [_midiQueueProcessor processMidiQueue:&_state->midiBuffer];

        @synchronized(self) {
            if (!_restoringState) {
                [self renderPreviews];
                [self renderMpeIndicators];
                [self renderPlayhead];

                [self handleScheduledActions];
            }
        }
        
        [self applyAutoPan];
    }
}

#pragma mark - MidiTrackRecorderDelegate

- (void)startRecord {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_state->track[t].recordEnabled.test()) {
            _state->processedBeginRecording[t].clear();
        }
    }
    if (!self.playButton.selected) {
        // we don't go through setPlayState since that would
        // call back into this method
        _autoPlayFromRecord = YES;
        self.playButton.selected = YES;
        [self updatePlayState];
    }
    _state->processedPlay.clear();
}

- (void)finishRecording:(int)ordinal {
    [self registerRecordedForUndo:ordinal];
    
    _state->processedEndRecording[ordinal].clear();
}

- (void)finishImport:(int)ordinal {
    [self registerRecordedForUndo:ordinal];
    
    MidiTrackState& track_state = _state->track[ordinal];
    track_state.recordedData = std::move(track_state.pendingRecordedData);
    track_state.recordedPreview = std::move(track_state.pendingRecordedPreview);
    
    [self withMidiTrack:ordinal view:^(MidiTrackView *view) {
        [view rebuild];
    }];

    _state->processedImport[ordinal].clear();
}

- (void)invalidateRecording:(int)ordinal {
    _state->processedNotesOff[ordinal].clear();
    _state->processedInvalidate[ordinal].clear();
}

#pragma mark RecorderToolTipDelegate

- (void)displayTooltip:(NSString*)tooltip {
    if (_restoringState || !_state->showToolTips.test()) {
        return;
    }
    
    if (_toolTipTimer) {
        [_toolTipTimer invalidate];
        _toolTipTimer = nil;
    }
    _toolTipTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                     target:self
                                                   selector:@selector(hideToolTip:)
                                                   userInfo:nil
                                                    repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:_toolTipTimer forMode:NSRunLoopCommonModes];
    
    _toolTipLabel.text = tooltip;
    
    if (_toolTipView.hidden) {
        UIView* view = _toolTipView;
        view.alpha = 0.0;
        view.hidden = NO;
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^() {
                             view.alpha = 1.0;
                         }
                         completion:^(BOOL finished) {}];
    }
}

- (void)hideToolTip:(NSTimer*)timer {
    [timer invalidate];
    timer = nil;
    
    UIView* view = _toolTipView;
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^() {
                         view.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         view.hidden = YES;
                     }];
}

#pragma mark - Undo / redo

- (void)undoManagerUpdated {
    _undoButton.enabled = _mainUndoManager.canUndo;
    _redoButton.enabled = _mainUndoManager.canRedo;
}

- (void)restoreSettings:(NSDictionary*)data {
    [self readSettingsFromDict:data];
}

- (void)registerSettingsForUndo {
    if (!_renderReady) {
        return;
    }
    
    [[_mainUndoManager prepareWithInvocationTarget:self] restoreSettings:[self currentSettingsToDict]];
}

- (void)restoreRecorded:(int)ordinal withData:(NSDictionary*)data {
    [[_midiQueueProcessor recorder:ordinal] dictToRecorded:data];
    [self withMidiTrack:ordinal view:^(MidiTrackView* view) {
        [view rebuild];
    }];
}

- (void)registerRecordedForUndo:(int)ordinal {
    if (!_renderReady) {
        return;
    }
    
    MidiTrackRecorder* recorder = [_midiQueueProcessor recorder:ordinal];
    [[_mainUndoManager prepareWithInvocationTarget:self] restoreRecorded:ordinal
                                                                withData:[recorder recordedAsDict]];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView*)scrollView {
    scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, 0);
    [_timeline setNeedsLayout];
    
    [self withMidiTrackViews:^(int ordinal, MidiTrackView* view) {
        [view setNeedsLayout];
    }];
}

#pragma mark - Collection processors

- (void)withMidiTrackViews:(void (^)(int t, MidiTrackView* view))block {
    MidiTrackView* midi_track[MIDI_TRACKS] = { _midiTrack1, _midiTrack2, _midiTrack3, _midiTrack4 };
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        block(t, midi_track[t]);
    }
}

- (void)withMidiTrack:(int)t view:(void (^)(MidiTrackView* view))block {
    if (t < 0 || t >= MIDI_TRACKS) {
        return;
    }
    
    MidiTrackView* midi_track[MIDI_TRACKS] = { _midiTrack1, _midiTrack2, _midiTrack3, _midiTrack4 };
    block(midi_track[t]);
}

#pragma mark Segues

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:AboutViewController.class]) {
        _aboutViewController = segue.destinationViewController;
        _aboutViewController.mainViewController = self;
    }
    else if ([segue.destinationViewController isKindOfClass:DonateViewController.class]) {
        _donateViewController = segue.destinationViewController;
        _donateViewController.mainViewController = self;
    }
    else if ([segue.destinationViewController isKindOfClass:SettingsViewController.class]) {
        _settingsViewController = segue.destinationViewController;
        _settingsViewController.mainViewController = self;
    }
}

@end
