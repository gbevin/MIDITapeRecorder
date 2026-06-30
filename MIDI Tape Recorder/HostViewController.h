//
//  HostViewController.h
//  MIDI Tape Recorder
//
//  root view controller of the standalone app. hosts the MIDI Tape Recorder
//  AUv3 (UI + audio) and provides access to the MIDI/transport settings.
//
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

@interface HostViewController : UIViewController

// opens a .mtrec session handed to the app from the outside (Finder/Files
// "Open in…", or a double-click). if the AU isn't running yet (cold launch via
// a file), the open is deferred until instantiation completes. `inPlace` is the
// document picker / open-URL flag: YES means we received the user's actual file
// (so it becomes the current document), NO means a throwaway copy (loaded as a
// named-but-unsaved session, then discarded).
- (void)openSessionURL:(NSURL*)url inPlace:(BOOL)inPlace;

@end
