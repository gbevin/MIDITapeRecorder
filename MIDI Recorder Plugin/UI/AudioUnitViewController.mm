//
//  AudioUnitViewController.m
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import "AudioUnitViewController.h"


#import "ActivityIndicator.h"
#import "Constants.h"
#import "MidiQueueProcessor.h"
#import "MidiRecorderAudioUnit.h"
#import "MidiTrack.h"

@interface AudioUnitViewController ()

@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityInput1;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityInput2;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityInput3;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityInput4;

@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityOutput1;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityOutput2;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityOutput3;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityOutput4;

@property (weak, nonatomic) IBOutlet UILabel* midiCount1;
@property (weak, nonatomic) IBOutlet UILabel* midiCount2;
@property (weak, nonatomic) IBOutlet UILabel* midiCount3;
@property (weak, nonatomic) IBOutlet UILabel* midiCount4;

@property (weak, nonatomic) IBOutlet UIButton* routingButton;

@property (weak, nonatomic) IBOutlet UIButton* rewindButton;
@property (weak, nonatomic) IBOutlet UIButton* playButton;
@property (weak, nonatomic) IBOutlet UIButton* recordButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint* timelineWidth;

@property (weak, nonatomic) IBOutlet UIButton* recordEnableButton1;
@property (weak, nonatomic) IBOutlet UIButton* recordEnableButton2;
@property (weak, nonatomic) IBOutlet UIButton* recordEnableButton3;
@property (weak, nonatomic) IBOutlet UIButton* recordEnableButton4;

@property (weak, nonatomic) IBOutlet UIButton* muteButton1;
@property (weak, nonatomic) IBOutlet UIButton* muteButton2;
@property (weak, nonatomic) IBOutlet UIButton* muteButton3;
@property (weak, nonatomic) IBOutlet UIButton* muteButton4;

@property (weak, nonatomic) IBOutlet MidiTrack* midiTrack1;
@property (weak, nonatomic) IBOutlet MidiTrack* midiTrack2;
@property (weak, nonatomic) IBOutlet MidiTrack* midiTrack3;
@property (weak, nonatomic) IBOutlet MidiTrack* midiTrack4;

@end

@implementation AudioUnitViewController {
    MidiRecorderAudioUnit* _audioUnit;
    AudioUnitGUIState* _guiState;
    CADisplayLink* _timer;

    MidiQueueProcessor* _midiQueueProcessor;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _guiState = nil;
        _audioUnit = nil;
        _timer = nil;
        
        _midiQueueProcessor = [MidiQueueProcessor new];
        _midiQueueProcessor.delegate = self;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _timer = [[UIScreen mainScreen] displayLinkWithTarget:self
                                                 selector:@selector(renderloop)];
    _timer.preferredFramesPerSecond = 30;
    _timer.paused = NO;
    [_timer addToRunLoop:[NSRunLoop mainRunLoop]
                 forMode:NSDefaultRunLoopMode];

    if (!_audioUnit) {
        return;
    }
    
    // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
}

- (AUAudioUnit*)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc error:(NSError **)error {
    _audioUnit = [[MidiRecorderAudioUnit alloc] initWithComponentDescription:desc error:error];
    _guiState = _audioUnit.kernelAdapter.guiState;
    
    return _audioUnit;
}

#pragma mark - IBActions

- (IBAction)routingPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
}

- (IBAction)rewindPressed:(id)sender {
    _recordButton.selected = NO;
    
    _midiQueueProcessor.record = NO;
    
    [_audioUnit.kernelAdapter rewind];
}

- (IBAction)playPressed:(id)sender {
    [self setPlay:!_playButton.selected];
}

- (void)setPlay:(BOOL)state {
    _playButton.selected = state;
    _recordButton.selected = NO;
    
    _midiQueueProcessor.play = _playButton.selected;
}

- (IBAction)recordPressed:(id)sender {
    _guiState->scheduledStop = false;
    
    _recordButton.selected = !_recordButton.selected;
    _playButton.selected = NO;
    
    _midiQueueProcessor.record = _recordButton.selected;
}

- (IBAction)recordEnablePressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [self updateRecordEnableState];
}

- (IBAction)mutePressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [self updateMuteState];
}

#pragma mark - State

- (void)updateRecordEnableState {
    
}

- (void)updateMuteState {
    
}

#pragma mark - Rendering

- (void)checkActivityIndicators {
    ActivityIndicator* inputs[4] = { _midiActivityInput1, _midiActivityInput2, _midiActivityInput3, _midiActivityInput4 };
    ActivityIndicator* outputs[4] = { _midiActivityOutput1, _midiActivityOutput2, _midiActivityOutput3, _midiActivityOutput4 };

    for (int i = 0; i < 4; ++i) {
        if (_guiState->midiActivityInput[i] == 1.f) {
            _guiState->midiActivityInput[i] = 0.f;
            inputs[i].showActivity = YES;
        }
        else {
            inputs[i].showActivity = NO;
        }
        
        if (_guiState->midiActivityOutput[i] == 1.f) {
            _guiState->midiActivityOutput[i] = 0.f;
            outputs[i].showActivity = YES;
        }
        else {
            outputs[i].showActivity = NO;
        }
    }
}

- (void)renderloop {
    if (_audioUnit) {
        [_midiQueueProcessor ping];
        
        [self checkActivityIndicators];
        [_midiQueueProcessor processMidiQueue:&_guiState->midiBuffer];
        
        int32_t one = true;
        if (_guiState->scheduledStop.compare_exchange_strong(one, false)) {
            [self setPlay:NO];
        }
        
        _timelineWidth.constant = _midiQueueProcessor.recordedTime * PIXELS_PER_SECOND;
        
        if (_playButton.selected == YES) {
            _midiCount1.text = [NSString stringWithFormat:@"%llu", _guiState->playCounter1.load()];
        }
        else {
            _midiCount1.text = [NSString stringWithFormat:@"%d", _midiQueueProcessor.recordedCount];
        }
    }
}

#pragma mark - MidiQueueProcessorDelegate methods

- (void)invalidateRecorded {
    if (_audioUnit) {
        [_audioUnit.kernelAdapter stop];

        _guiState->recordedBytes1 = nullptr;
        _guiState->recordedLength1 = 0;
    }
}

- (void)playRecorded:(const void*)buffer length:(uint64_t)length {
    _guiState->recordedBytes1 = (const QueuedMidiMessage*)buffer;
    _guiState->recordedLength1 = length;
    
    [_audioUnit.kernelAdapter play];
}

- (void)stopRecorded {
    [_audioUnit.kernelAdapter stop];
}

@end
