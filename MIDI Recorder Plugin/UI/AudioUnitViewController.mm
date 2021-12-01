//
//  AudioUnitViewController.m
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "AudioUnitViewController.h"

#include "Constants.h"

#import "ActivityIndicatorView.h"
#import "MidiQueueProcessor.h"
#import "MidiRecorder.h"
#import "MidiRecorderAudioUnit.h"
#import "MidiTrackView.h"
#import "TimelineView.h"

@interface AudioUnitViewController ()

@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput1;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput2;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput3;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityInput4;

@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput1;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput2;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput3;
@property (weak, nonatomic) IBOutlet ActivityIndicatorView* midiActivityOutput4;

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

@property (weak, nonatomic) IBOutlet UIScrollView* tracks;

@property (weak, nonatomic) IBOutlet TimelineView* timeline;

@property (weak, nonatomic) IBOutlet UIView* playhead;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint* playheadLeading;

@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack1;
@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack2;
@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack3;
@property (weak, nonatomic) IBOutlet MidiTrackView* midiTrack4;

@end

@implementation AudioUnitViewController {
    MidiRecorderAudioUnit* _audioUnit;
    MidiRecorderState* _state;
    CADisplayLink* _timer;

    MidiQueueProcessor* _midiQueueProcessor;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _state = nil;
        _audioUnit = nil;
        _timer = nil;
        
        _midiQueueProcessor = [MidiQueueProcessor new];
        for (int i = 0; i < MIDI_TRACKS; ++i) {
            [_midiQueueProcessor recorder:i].delegate = self;
        }
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
    _state = _audioUnit.kernelAdapter.state;
    [_midiQueueProcessor setState:_state];
    
    return _audioUnit;
}

#pragma mark - IBActions

- (IBAction)routingPressed:(UIButton*)sender {
    sender.selected = !sender.selected;
    
    [self updateRoutingState];
}

- (IBAction)rewindPressed:(id)sender {
    _recordButton.selected = NO;
    
    for (int i = 0; i < MIDI_TRACKS; ++i) {
        [_midiQueueProcessor recorder:i].record = NO;
    }
    
    [_audioUnit.kernelAdapter rewind];
    [_tracks setContentOffset:CGPointMake(0, 0) animated:NO];
}

- (IBAction)playPressed:(id)sender {
    [self setPlay:!_playButton.selected];
    
    if (_playButton.selected) {
        [_audioUnit.kernelAdapter play];
    }
    else {
        [_audioUnit.kernelAdapter stop];
    }
}

- (void)setPlay:(BOOL)state {
    _playButton.selected = state;
    _recordButton.selected = NO;
}

- (IBAction)recordPressed:(id)sender {
    _state->scheduledStop = false;
    
    _recordButton.selected = !_recordButton.selected;
    _playButton.selected = NO;
    
    for (int i = 0; i < MIDI_TRACKS; ++i) {
        [_midiQueueProcessor recorder:i].record = (_recordButton.selected && _state->track[i].record);
    }
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

- (void)updateRoutingState {
    for (int i = 0; i < MIDI_TRACKS; ++i) {
        if (_routingButton.selected) {
            _state->track[i].sourceCable = i;
        }
        else {
            _state->track[i].sourceCable = 0;
        }
    }
}

- (void)updateRecordEnableState {
    UIButton* record_enabled_button[MIDI_TRACKS] = { _recordEnableButton1, _recordEnableButton2, _recordEnableButton3, _recordEnableButton4 };

    for (int i = 0; i < MIDI_TRACKS; ++i) {
        _state->track[i].record = record_enabled_button[i].selected;
    }
}

- (void)updateMuteState {
    UIButton* mute_button[MIDI_TRACKS] = { _muteButton1, _muteButton2, _muteButton3, _muteButton4 };

    for (int i = 0; i < MIDI_TRACKS; ++i) {
        _state->track[i].mute = mute_button[i].selected;
    }
}

#pragma mark - Rendering

- (void)checkActivityIndicators {
    ActivityIndicatorView* inputs[MIDI_TRACKS] = { _midiActivityInput1, _midiActivityInput2, _midiActivityInput3, _midiActivityInput4 };
    ActivityIndicatorView* outputs[MIDI_TRACKS] = { _midiActivityOutput1, _midiActivityOutput2, _midiActivityOutput3, _midiActivityOutput4 };

    for (int i = 0; i < MIDI_TRACKS; ++i) {
        if (_state->track[i].activityInput == 1.f) {
            _state->track[i].activityInput = 0.f;
            inputs[i].showActivity = YES;
        }
        else {
            inputs[i].showActivity = NO;
        }
        
        if (_state->track[i].activityOutput == 1.f) {
            _state->track[i].activityOutput = 0.f;
            outputs[i].showActivity = YES;
        }
        else {
            outputs[i].showActivity = NO;
        }
    }
}

- (void)handleScheduledActions {
    int32_t one = true;
    if (_state->scheduledStop.compare_exchange_strong(one, false)) {
        [self setPlay:NO];
    }
}

- (void)renderPreviews {
    // update the previews and the timeline
    double max_duration = 0.0;
    
    MidiTrackView* midi_track[MIDI_TRACKS] = { _midiTrack1, _midiTrack2, _midiTrack3, _midiTrack4 };
    for (int i = 0; i < MIDI_TRACKS; ++i) {
        midi_track[i].preview = [_midiQueueProcessor recorder:i].preview;
        
        max_duration = MAX(max_duration, [_midiQueueProcessor recorder:i].duration);
        
        if (_recordButton.selected) {
            [midi_track[i] setNeedsDisplay];
        }
    }
    _timelineWidth.constant = max_duration * PIXELS_PER_SECOND;
}

- (void)renderPlayhead {
    BOOL has_recorder_duration = NO;
    for (int i = 0; i < MIDI_TRACKS; ++i) {
        if ([_midiQueueProcessor recorder:i].duration != 0.0) {
            has_recorder_duration = YES;
            break;
        }
    }

    // playhead positioning
    _playheadLeading.constant = _state->playDuration * PIXELS_PER_SECOND;
    
    // scroll view location
    _playhead.hidden = !has_recorder_duration;
    if (!_playhead.hidden && (_playButton.selected || _recordButton.selected)) {
        CGFloat content_offset;
        if (_playhead.frame.origin.x < _tracks.frame.size.width / 2.0) {
            content_offset = 0.0;
        }
        else {
            content_offset = MAX(MIN(_playhead.frame.origin.x - _tracks.frame.size.width / 2.0,
                                 _tracks.contentSize.width - _tracks.bounds.size.width + _tracks.contentInset.left), 0.0);
        }
        [_tracks setContentOffset:CGPointMake(content_offset, 0) animated:NO];
    }
}

- (void)renderStatistics {
    // statistics counts at the bottom
    UILabel* midi_count[MIDI_TRACKS] = { _midiCount1, _midiCount2, _midiCount3, _midiCount4 };

    for (int i = 0; i < MIDI_TRACKS; ++i) {
        if (_playButton.selected) {
            midi_count[i].text = [NSString stringWithFormat:@"%llu", _state->track[i].playCounter.load()];
        }
        else {
            midi_count[i].text = [NSString stringWithFormat:@"%llu", _state->track[i].recordedLength.load()];
        }
    }
}

- (void)renderloop {
    if (_audioUnit) {
        [_midiQueueProcessor ping];
        
        [self checkActivityIndicators];
        
        [_midiQueueProcessor processMidiQueue:&_state->midiBuffer];

        [self handleScheduledActions];
        
        [self renderPreviews];
        [self renderPlayhead];
        [self renderStatistics];
    }
}

#pragma mark - MidiRecorderDelegate methods

- (void)startRecord:(int)ordinal {
    _state->track[ordinal].recording = YES;
    
    [_audioUnit.kernelAdapter play];
}

- (void)finishRecording:(int)ordinal data:(const QueuedMidiMessage*)data count:(uint32_t)count {
    _state->track[ordinal].recording = NO;
    _state->track[ordinal].recordedMessages = data;
    _state->track[ordinal].recordedLength = count;
    
    [_audioUnit.kernelAdapter stop];
}

- (void)invalidateRecording:(int)ordinal {
    _state->track[ordinal].recordedMessages = nullptr;
    _state->track[ordinal].recordedLength = 0;
}

@end
