//
//  WelcomeViewController.h
//  MIDI Tape Recorder
//
//  first-launch welcome screen that points the user at the MIDI settings and
//  explains how to start recording.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WelcomeViewController : UIViewController

// invoked (after this screen is dismissed) when the user chooses to open the
// MIDI settings directly from the welcome screen.
@property (nonatomic, copy, nullable) void (^onOpenSettings)(void);

@end

NS_ASSUME_NONNULL_END
