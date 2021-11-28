//
//  AudioUnitViewController.m
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import "AudioUnitViewController.hpp"

#import "MidiRecorderAudioUnit.hpp"

@interface AudioUnitViewController ()

@property (weak, nonatomic) IBOutlet UIView* midiActivity1;

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
    if (_audioUnit &&
        _audioUnit.kernelAdapter.guiState->midiActivity[0] == 1.f) {
        _audioUnit.kernelAdapter.guiState->midiActivity[0] = 0.f;
        
        _midiActivity1.backgroundColor = [UIColor greenColor];
    }
    else {
        _midiActivity1.backgroundColor = [UIColor darkGrayColor];
    }
}

- (AUAudioUnit*)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc error:(NSError **)error {
    _audioUnit = [[MidiRecorderAudioUnit alloc] initWithComponentDescription:desc error:error];
    
    return _audioUnit;
}

@end
