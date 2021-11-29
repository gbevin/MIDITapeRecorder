//
//  AudioUnitViewController.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import "AudioUnitViewController.hpp"

#import "ActivityIndicator.hpp"
#import "MidiQueueProcessor.hpp"
#import "MidiRecorderAudioUnit.hpp"

@interface AudioUnitViewController ()

@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityInput1;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityOutput1;
@property (weak, nonatomic) IBOutlet UILabel* midiCount1;

@property (weak, nonatomic) IBOutlet UIButton* rewindButton;
@property (weak, nonatomic) IBOutlet UIButton* playButton;
@property (weak, nonatomic) IBOutlet UIButton* recordButton;

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

#pragma mark - Rendering

- (void)checkActivityIndicators {
    if (_guiState->midiActivityInput[0] == 1.f) {
        _guiState->midiActivityInput[0] = 0.f;
        _midiActivityInput1.showActivity = YES;
    }
    else {
        _midiActivityInput1.showActivity = NO;
    }
    
    if (_guiState->midiActivityOutput[0] == 1.f) {
        _guiState->midiActivityOutput[0] = 0.f;
        _midiActivityOutput1.showActivity = YES;
    }
    else {
        _midiActivityOutput1.showActivity = NO;
    }
}

- (void)renderloop {
    if (_audioUnit) {
        [self checkActivityIndicators];
        [_midiQueueProcessor processMidiQueue:&_guiState->midiBuffer];
        
        int32_t one = true;
        if (_guiState->scheduledStop.compare_exchange_strong(one, false)) {
            [self setPlay:NO];
        }
        
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
