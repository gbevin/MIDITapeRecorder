//
//  RecorderToolTipDelegate.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/11/21.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

@protocol RecorderToolTipDelegate <NSObject>

- (void)displayTooltip:(NSString*)tooltip;

@end
