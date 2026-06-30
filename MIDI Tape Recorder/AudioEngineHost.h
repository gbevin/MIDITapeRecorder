//
//  AudioEngineHost.h
//  MIDI Tape Recorder
//
//  hosts the MIDI Tape Recorder AUv3 in-process inside an AVAudioEngine so that
//  its render block runs and processes MIDI, and exposes its view controller.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class AudioEngineHost;

@protocol AudioEngineHostDelegate <NSObject>
// called from the audio render thread when the hosted unit emits a MIDI event on
// one of its output cables (0-3). implementations must be real-time safe.
- (void)audioEngineHost:(AudioEngineHost*)host
       outputMIDIOnCable:(uint8_t)cable
                  length:(NSInteger)length
                    data:(const uint8_t*)data;
@end

@interface AudioEngineHost : NSObject

@property (nonatomic, weak, nullable) id<AudioEngineHostDelegate> delegate;

// the plugin's own view controller, available after instantiation succeeds.
@property (nonatomic, readonly, nullable) UIViewController* pluginViewController;

// tempo in BPM reported to the hosted unit through its musical context block.
@property (nonatomic) double tempo;

// whether recording/playback keeps running while the app is in the background
// (iOS/iPadOS). when NO, the engine and audio session are released on
// backgrounding so iOS can suspend the app and save power; they resume on
// returning to the foreground. persisted across launches. defaults to YES.
// no effect on Mac Catalyst (the app keeps running regardless).
@property (nonatomic) BOOL backgroundAudioEnabled;

// whether the engine is running and ready to schedule/receive MIDI.
@property (nonatomic, readonly, getter=isRunning) BOOL running;

// the hosted unit's full state (recorded tracks + settings), used for host-level
// import/export of all tracks. nil until the unit is instantiated.
@property (nonatomic, copy, nullable) NSDictionary<NSString*, id>* fullState;

// clears all recorded tracks by firing the unit's clearAll trigger parameter.
- (void)clearAllTracks;

// flips an on/off (boolean) parameter to its opposite live value.
- (void)toggleParameterWithIdentifier:(NSString*)identifier;

// fires a momentary trigger parameter (sets it to 1; the plugin resets it).
- (void)triggerParameterWithIdentifier:(NSString*)identifier;

// sets a parameter to a specific value.
- (void)setParameterWithIdentifier:(NSString*)identifier value:(float)value;

// whether a boolean parameter is currently on (value >= 0.5).
- (BOOL)parameterIsOn:(NSString*)identifier;

// instantiates the registered AUv3 in-process, starts the engine and requests
// the plugin view controller. the completion is called on the main thread.
- (void)instantiateWithCompletion:(void (^)(NSError* _Nullable error))completion;

// schedules a live MIDI event to be processed by the hosted unit on the given
// cable (which selects the recorder track 0-3). safe to call from any thread.
- (void)scheduleMIDIOnCable:(uint8_t)cable length:(NSInteger)length data:(const uint8_t*)data;

@end

NS_ASSUME_NONNULL_END
