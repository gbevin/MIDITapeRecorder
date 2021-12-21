//
//  ToolTipButton.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/21/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

#import "RecorderToolTipDelegate.h"

@interface ToolTipButton : UIButton

@property id<RecorderToolTipDelegate> toolTipDelegate;
@property NSString* toolTipTextSelected;
@property NSString* toolTipTextUnselected;
@property NSString* toolTipTextHighlighted;

@end
