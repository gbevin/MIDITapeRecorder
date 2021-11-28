//
//  AudioUnitViewController.m
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import "AudioUnitViewController.hpp"

#import "ActivityIndicator.hpp"
#import "MidiRecorderAudioUnit.hpp"

@interface AudioUnitViewController ()

@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityInput1;
@property (weak, nonatomic) IBOutlet ActivityIndicator* midiActivityOutput1;
@property (weak, nonatomic) IBOutlet UIButton* rewindButton;
@property (weak, nonatomic) IBOutlet UIButton* playButton;
@property (weak, nonatomic) IBOutlet UIButton* recordButton;

@end

@implementation AudioUnitViewController {
    MidiRecorderAudioUnit* _audioUnit;
    CADisplayLink* _timer;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _audioUnit = nil;
        _timer= nil;
    }
    
    return self;
}

- (IBAction)rewindPressed:(id)sender {
}

- (IBAction)playPressed:(id)sender {
    self.playButton.selected = !self.playButton.selected;
}

- (IBAction)recordPressed:(id)sender {
    self.recordButton.selected = !self.recordButton.selected;
    self.playButton.selected = NO;
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

- (void)renderloop {
    if (_audioUnit) {
        if (_audioUnit.kernelAdapter.guiState->midiActivityInput[0] == 1.f) {
            _audioUnit.kernelAdapter.guiState->midiActivityInput[0] = 0.f;
            _midiActivityInput1.showActivity = YES;
        }
        else {
            _midiActivityInput1.showActivity = NO;
        }
        
        if (_audioUnit.kernelAdapter.guiState->midiActivityOutput[0] == 1.f) {
            _audioUnit.kernelAdapter.guiState->midiActivityOutput[0] = 0.f;
            _midiActivityOutput1.showActivity = YES;
        }
        else {
            _midiActivityOutput1.showActivity = NO;
        }
    }
}

- (AUAudioUnit*)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc error:(NSError **)error {
    _audioUnit = [[MidiRecorderAudioUnit alloc] initWithComponentDescription:desc error:error];
    
    return _audioUnit;
}

@end
