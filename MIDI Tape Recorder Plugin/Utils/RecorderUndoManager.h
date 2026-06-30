//
//  RecorderUndoManager.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/17/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

@interface RecorderUndoManager : NSUndoManager

- (void)withUndoGroup:(void (^)())block;

@end
