//
//  MidiSettingsViewController.h
//  MIDI Tape Recorder
//
//  host settings: per-track MIDI input, per-cable MIDI output, tempo and the
//  published virtual endpoints.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

#import "AudioEngineHost.h"
#import "MidiPortManager.h"

NS_ASSUME_NONNULL_BEGIN

// NSUserDefaults key for the persisted host tempo (BPM).
extern NSString* const kHostTempoKey;

@interface MidiSettingsViewController : UIViewController

- (instancetype)initWithPortManager:(MidiPortManager*)portManager host:(AudioEngineHost*)host;

// invoked (after this screen dismisses itself) to re-show the welcome screen.
@property (nonatomic, copy, nullable) void (^onShowWelcome)(void);

@end

NS_ASSUME_NONNULL_END
