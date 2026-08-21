//
//  AudioEngineHost.m
//  MIDI Tape Recorder
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "AudioEngineHost.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/CoreAudioKit.h>

#include "MidiRecorderParamIds.h"

// MIDI Tape Recorder ships three component variants sharing the same kernel.
// we host the instrument variant ('aumu'/'miri') because an instrument node
// attaches cleanly to AVAudioEngine (no audio input chain required) while still
// processing MIDI in and out through the kernel.
// 'aumu'
static const OSType kComponentType = kAudioUnitType_MusicDevice;
static const OSType kComponentSubType = 'miri';
static const OSType kComponentManufacturer = 'Uwyn';

static NSString* const kBackgroundAudioEnabledKey = @"backgroundAudio.enabled";

@implementation AudioEngineHost {
    AVAudioEngine* _engine;
    AVAudioUnit* _avAudioUnit;
    AUAudioUnit* _audioUnit;
    AUScheduleMIDIEventBlock _scheduleBlock;
    // heap-allocated so the render-thread musical context block can read the
    // current tempo without capturing self. atomic because it's written from
    // the main thread and the CoreMIDI clock path while the render thread
    // reads it every buffer.
    _Atomic double* _tempoPtr;
    BOOL _backgroundAudioEnabled;
    // YES while we've deliberately paused the engine for the background (so the
    // foreground handler knows to resume).
    BOOL _suspendedForBackground;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // default to keeping audio alive in the background unless the user opted out.
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        _backgroundAudioEnabled = ([defaults objectForKey:kBackgroundAudioEnabledKey] == nil)
                                      ? YES
                                      : [defaults boolForKey:kBackgroundAudioEnabledKey];

        [self configureAudioSession];
        _engine = [[AVAudioEngine alloc] init];
        _tempoPtr = malloc(sizeof(_Atomic double));
        *_tempoPtr = 120.0;

#if !TARGET_OS_MACCATALYST
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(handleEnterBackground)
                       name:UIApplicationDidEnterBackgroundNotification object:nil];
        [center addObserver:self selector:@selector(handleEnterForeground)
                       name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
    }
    return self;
}

- (BOOL)backgroundAudioEnabled {
    return _backgroundAudioEnabled;
}

- (void)setBackgroundAudioEnabled:(BOOL)enabled {
    _backgroundAudioEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBackgroundAudioEnabledKey];
}

#if !TARGET_OS_MACCATALYST
// when background audio is disabled, release the engine and audio session on
// backgrounding so iOS suspends the app instead of keeping it awake. (When it's
// enabled we do nothing, letting the Playback session keep rendering.)
- (void)handleEnterBackground {
    if (_backgroundAudioEnabled || !_engine.isRunning) {
        return;
    }
    [_engine pause];
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setActive:NO
           withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                 error:nil];
    _suspendedForBackground = YES;
}

// resume whatever we paused on the way into the background.
- (void)handleEnterForeground {
    if (!_suspendedForBackground) {
        return;
    }
    _suspendedForBackground = NO;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    NSError* error = nil;
    if (![_engine startAndReturnError:&error]) {
        NSLog(@"MIDI Tape Recorder: failed to resume audio engine: %@", error);
    }
}
#endif

// on iOS/iPadOS a Playback audio session, combined with the "audio" background
// mode, keeps the engine's render block (and therefore MIDI processing) running
// when the app is backgrounded or the screen is locked. MixWithOthers so we don't
// interrupt the synths the recorder is driving. (Mac apps keep running anyway.)
- (void)configureAudioSession {
#if !TARGET_OS_MACCATALYST
    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* error = nil;
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeDefault
                 options:AVAudioSessionCategoryOptionMixWithOthers
                   error:&error];
    [session setActive:YES error:&error];
#endif
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_engine.isRunning) {
        [_engine stop];
    }
    free(_tempoPtr);
}

- (double)tempo {
    return *_tempoPtr;
}

- (void)setTempo:(double)tempo {
    if (tempo < 1.0) {
        tempo = 1.0;
    }
    *_tempoPtr = tempo;
}

- (BOOL)isRunning {
    return _engine.isRunning && _scheduleBlock != nil;
}

- (NSDictionary<NSString*, id>*)fullState {
    return _audioUnit.fullState;
}

- (void)setFullState:(NSDictionary<NSString*, id>*)fullState {
    if (_audioUnit != nil && fullState != nil) {
        _audioUnit.fullState = fullState;
    }
}

- (void)clearAllTracks {
    [self triggerParameterWithIdentifier:MTRParamIdClearAll];
}

- (void)toggleParameterWithIdentifier:(NSString*)identifier {
    // the value provider returns the live kernel state across the boundary, so we
    // can reliably flip it.
    AUParameter* parameter = [_audioUnit.parameterTree valueForKey:identifier];
    parameter.value = (parameter.value >= 0.5f) ? 0.0f : 1.0f;
}

- (void)triggerParameterWithIdentifier:(NSString*)identifier {
    // momentary trigger; the plugin resets it after handling.
    AUParameter* parameter = [_audioUnit.parameterTree valueForKey:identifier];
    parameter.value = 1.0f;
}

- (BOOL)parameterIsOn:(NSString*)identifier {
    AUParameter* parameter = [_audioUnit.parameterTree valueForKey:identifier];
    return parameter != nil && parameter.value >= 0.5f;
}

- (void)setParameterWithIdentifier:(NSString*)identifier value:(float)value {
    AUParameter* parameter = [_audioUnit.parameterTree valueForKey:identifier];
    parameter.value = value;
}

- (void)instantiateWithCompletion:(void (^)(NSError* _Nullable))completion {
    AudioComponentDescription desc = {0};
    desc.componentType = kComponentType;
    desc.componentSubType = kComponentSubType;
    desc.componentManufacturer = kComponentManufacturer;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    // Standard out-of-process hosting (in-process loading is a macOS/AppKit-only
    // option, unavailable on iOS and Mac Catalyst). The view controller returned
    // by requestViewControllerWithCompletionHandler is still backed by this same
    // audio unit instance. Hosting an out-of-process audio unit on iOS requires
    // the app's inter-app-audio entitlement; without it instantiation is refused
    // with -3000 (invalidComponentID).
    AudioComponentInstantiationOptions options = 0;

    __weak AudioEngineHost* weakSelf = self;
    [AVAudioUnit instantiateWithComponentDescription:desc
                                             options:options
                                   completionHandler:^(AVAudioUnit* _Nullable avAudioUnit, NSError* _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            AudioEngineHost* strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            if (error != nil || avAudioUnit == nil) {
                NSLog(@"MIDI Tape Recorder: audio unit instantiation failed: %@", error);
                completion(error ?: [NSError errorWithDomain:@"AudioEngineHost"
                                                        code:-1
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to instantiate audio unit"}]);
                return;
            }
            [strongSelf finishInstantiation:avAudioUnit completion:completion];
        });
    }];
}

- (void)finishInstantiation:(AVAudioUnit*)avAudioUnit completion:(void (^)(NSError* _Nullable))completion {
    _avAudioUnit = avAudioUnit;
    _audioUnit = avAudioUnit.AUAudioUnit;

    // provide an internal musical context (tempo) before render resources are
    // allocated, so the kernel picks it up. the block reads the live tempo and
    // a free-running beat position derived from the render timestamp.
    _Atomic double* tempoPtr = _tempoPtr;
    _audioUnit.musicalContextBlock = ^BOOL(double* _Nullable currentTempo,
                                           double* _Nullable timeSignatureNumerator,
                                           NSInteger* _Nullable timeSignatureDenominator,
                                           double* _Nullable currentBeatPosition,
                                           NSInteger* _Nullable sampleOffsetToNextBeat,
                                           double* _Nullable currentMeasureDownbeatPosition) {
        if (currentTempo) {
            *currentTempo = *tempoPtr;
        }
        if (timeSignatureNumerator) {
            *timeSignatureNumerator = 4;
        }
        if (timeSignatureDenominator) {
            *timeSignatureDenominator = 4;
        }
        if (currentBeatPosition) {
            *currentBeatPosition = 0.0;
        }
        if (sampleOffsetToNextBeat) {
            *sampleOffsetToNextBeat = 0;
        }
        if (currentMeasureDownbeatPosition) {
            *currentMeasureDownbeatPosition = 0.0;
        }
        return YES;
    };

    // receive MIDI emitted by the recorder on its four output cables.
    __weak AudioEngineHost* weakSelf = self;
    _audioUnit.MIDIOutputEventBlock = ^OSStatus(AUEventSampleTime eventSampleTime,
                                                uint8_t cable,
                                                NSInteger length,
                                                const uint8_t* midiBytes) {
        AudioEngineHost* strongSelf = weakSelf;
        id<AudioEngineHostDelegate> delegate = strongSelf.delegate;
        if (delegate) {
            [delegate audioEngineHost:strongSelf outputMIDIOnCable:cable length:length data:midiBytes];
        }
        return noErr;
    };

    NSError* error = nil;
    [_engine attachNode:_avAudioUnit];
    [_engine connect:_avAudioUnit to:_engine.mainMixerNode format:nil];
    // the hosted unit only produces silence; keep the output muted.
    _engine.mainMixerNode.outputVolume = 0.0;

    [_engine prepare];
    if (![_engine startAndReturnError:&error]) {
        NSLog(@"MIDI Tape Recorder: audio engine start failed: %@", error);
        completion(error);
        return;
    }

    // available only once render resources are allocated (after engine start).
    _scheduleBlock = _audioUnit.scheduleMIDIEventBlock;

    [_audioUnit requestViewControllerWithCompletionHandler:^(UIViewController* _Nullable viewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            AudioEngineHost* strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            strongSelf->_pluginViewController = viewController;
            if (viewController == nil) {
                completion([NSError errorWithDomain:@"AudioEngineHost"
                                               code:-2
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to load plugin view controller"}]);
            }
            else {
                completion(nil);
            }
        });
    }];
}

- (void)scheduleMIDIOnCable:(uint8_t)cable length:(NSInteger)length data:(const uint8_t*)data {
    AUScheduleMIDIEventBlock block = _scheduleBlock;
    if (block == nil || length <= 0) {
        return;
    }
    block(AUEventSampleTimeImmediate, cable, length, data);
}

@end
