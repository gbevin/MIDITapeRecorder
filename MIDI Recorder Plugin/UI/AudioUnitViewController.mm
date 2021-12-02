//
//  AudioUnitViewController.m
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "AudioUnitViewController.h"

#include "Constants.h"
#include "HostTime.h"

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

@property (weak, nonatomic) IBOutlet UIButton* recordButton1;
@property (weak, nonatomic) IBOutlet UIButton* recordButton2;
@property (weak, nonatomic) IBOutlet UIButton* recordButton3;
@property (weak, nonatomic) IBOutlet UIButton* recordButton4;

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
    
    BOOL _autoPlayFromRecord;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _state = nil;
        _audioUnit = nil;
        _timer = nil;
        
        _midiQueueProcessor = [MidiQueueProcessor new];
        for (int t = 0; t < MIDI_TRACKS; ++t) {
            [_midiQueueProcessor recorder:t].delegate = self;
        }
        
        _autoPlayFromRecord = NO;
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
    [_audioUnit setVC:self];
    
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
    _state->transportStartMachSeconds = HOST_TIME.currentMachTimeInSeconds();

    [self setRecord:NO];
    _state->scheduledRewind = true;
    [_tracks setContentOffset:CGPointMake(0, 0) animated:NO];
}

- (IBAction)playPressed:(id)sender {
    _autoPlayFromRecord = NO;
    [self setPlay:!_playButton.selected];
}

- (void)setPlay:(BOOL)state {
    _playButton.selected = state;

    if (_playButton.selected) {
        _state->transportStartMachSeconds = HOST_TIME.currentMachTimeInSeconds();
        
        if (_recordButton.selected) {
            [self startRecord];
        }
        else {
            _state->scheduledPlay = true;
        }
    }
    else {
        if (_recordButton.selected) {
            [self setRecord:NO];
            _state->scheduledRewind = true;
        }
        _state->scheduledStop = true;
    }
}

- (IBAction)recordPressed:(id)sender {
    BOOL selected = !_recordButton.selected;
    
    if (selected) {
        _autoPlayFromRecord = NO;
        
        if (_playButton.selected) {
            [self startRecord];
        }
        else {
            _state->transportStartMachSeconds = 0.0;
        }
    }
    else {
        if (_autoPlayFromRecord) {
            _playButton.selected = NO;
            _state->scheduledStopAndRewind = true;
        }
    }
    
    [self setRecord:selected];
}

- (void)setRecord:(BOOL)state {
    _recordButton.selected = state;
    
    [self updateRecordEnableState];
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

- (void)readSettingsFromDict:(NSDictionary*)dict {
    id routing = [dict objectForKey:@"Routing"];
    id record1 = [dict objectForKey:@"Record1"];
    id record2 = [dict objectForKey:@"Record2"];
    id record3 = [dict objectForKey:@"Record3"];
    id record4 = [dict objectForKey:@"Record4"];
    id mute1 = [dict objectForKey:@"Mute1"];
    id mute2 = [dict objectForKey:@"Mute2"];
    id mute3 = [dict objectForKey:@"Mute3"];
    id mute4 = [dict objectForKey:@"Mute4"];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (routing) {
            self->_routingButton.selected = [routing boolValue];
        }
        if (record1) {
            self->_recordButton1.selected = [record1 boolValue];
        }
        if (record2) {
            self->_recordButton2.selected = [record2 boolValue];
        }
        if (record3) {
            self->_recordButton3.selected = [record3 boolValue];
        }
        if (record4) {
            self->_recordButton4.selected = [record4 boolValue];
        }

        if (mute1) {
            self->_muteButton1.selected = [mute1 boolValue];
        }
        if (mute2) {
            self->_muteButton2.selected = [mute2 boolValue];
        }
        if (mute3) {
            self->_muteButton3.selected = [mute3 boolValue];
        }
        if (mute4) {
            self->_muteButton4.selected = [mute4 boolValue];
        }

        [self updateRecordEnableState];
    });
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

- (NSDictionary*)currentSettingsToDict {
    return @{
        @"Routing" : @(_routingButton.selected),
        @"Record1" : @(_recordButton1.selected),
        @"Record2" : @(_recordButton2.selected),
        @"Record3" : @(_recordButton3.selected),
        @"Record4" : @(_recordButton4.selected),
        @"Mute1" : @(_muteButton1.selected),
        @"Mute2" : @(_muteButton2.selected),
        @"Mute3" : @(_muteButton3.selected),
        @"Mute4" : @(_muteButton4.selected)
    };
}

- (NSDictionary*)currentRecordingsToDict {
    NSMutableDictionary* result = [NSMutableDictionary new];
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        [result setObject:[[_midiQueueProcessor recorder:t] recordedAsDict] forKey:[NSString stringWithFormat:@"Recorder%d", t]];
    }
    return result;
}

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
        _state->track[t].recordEnabled = record_button[t].selected;
        [_midiQueueProcessor recorder:t].record = (_recordButton.selected && _state->track[t].recordEnabled);
    }
}

- (void)updateMuteState {
    UIButton* mute_button[MIDI_TRACKS] = { _muteButton1, _muteButton2, _muteButton3, _muteButton4 };

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        _state->track[t].muteEnabled = mute_button[t].selected;
    }
}

#pragma mark - Rendering

- (void)checkActivityIndicators {
    ActivityIndicatorView* inputs[MIDI_TRACKS] = { _midiActivityInput1, _midiActivityInput2, _midiActivityInput3, _midiActivityInput4 };
    ActivityIndicatorView* outputs[MIDI_TRACKS] = { _midiActivityOutput1, _midiActivityOutput2, _midiActivityOutput3, _midiActivityOutput4 };

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_state->track[t].activityInput == 1.f) {
            _state->track[t].activityInput = 0.f;
            inputs[t].showActivity = YES;
        }
        else {
            inputs[t].showActivity = NO;
        }
        
        if (_state->track[t].activityOutput == 1.f) {
            _state->track[t].activityOutput = 0.f;
            outputs[t].showActivity = YES;
        }
        else {
            outputs[t].showActivity = NO;
        }
    }
}

- (void)handleScheduledActions {
    int32_t one = true;
    if (_state->scheduledUIStopAndRewind.compare_exchange_strong(one, false)) {
        [self setPlay:NO];
        _state->scheduledRewind = true;
    }
}

- (void)renderPreviews {
    // update the previews and the timeline
    double max_duration = 0.0;
    
    MidiTrackView* midi_track[MIDI_TRACKS] = { _midiTrack1, _midiTrack2, _midiTrack3, _midiTrack4 };
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        midi_track[t].preview = [_midiQueueProcessor recorder:t].preview;
        
        max_duration = MAX(max_duration, [_midiQueueProcessor recorder:t].duration);
        
        if (_recordButton.selected) {
            [midi_track[t] setNeedsDisplay];
        }
    }
    _timelineWidth.constant = max_duration * PIXELS_PER_SECOND;
}

- (void)renderPlayhead {
    BOOL has_recorder_duration = NO;
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if ([_midiQueueProcessor recorder:t].duration != 0.0) {
            has_recorder_duration = YES;
            break;
        }
    }

    // playhead positioning
    _playheadLeading.constant = _state->playDurationSeconds * PIXELS_PER_SECOND;
    
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

    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_playButton.selected) {
            midi_count[t].text = [NSString stringWithFormat:@"%llu", _state->track[t].playCounter.load()];
        }
        else {
            midi_count[t].text = [NSString stringWithFormat:@"%llu", _state->track[t].recordedLength.load()];
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

- (void)startRecord {
    for (int t = 0; t < MIDI_TRACKS; ++t) {
        if (_state->track[t].recordEnabled) {
            _state->scheduledBeginRecording[t] = true;
        }
    }
    if (!self.playButton.selected) {
        _autoPlayFromRecord = YES;
        self.playButton.selected = YES;
    }
    _state->scheduledPlay = true;
}

- (void)finishRecording:(int)ordinal data:(const RecordedMidiMessage*)data count:(uint32_t)count {
    _state->scheduledEndRecording[ordinal] = true;
    
    MidiTrackState& state = _state->track[ordinal];
    state.recordedMessages = data;
    state.recordedLength = count;
}

- (void)invalidateRecording:(int)ordinal {
    MidiTrackState& state = _state->track[ordinal];
    state.recordedMessages = nullptr;
    state.recordedLength = 0;
}

@end
