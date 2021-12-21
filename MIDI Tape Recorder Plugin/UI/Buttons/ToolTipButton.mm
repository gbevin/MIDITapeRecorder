//
//  ToolTipButton.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/2/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ToolTipButton.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation ToolTipButton

- (void)setSelected:(BOOL)selected {
    BOOL changed = self.selected != selected;

    super.selected = selected;

    if (changed && _toolTipDelegate) {
        if (_toolTipTextSelected && self.selected) {
            [_toolTipDelegate displayTooltip:_toolTipTextSelected];
        }
        else if (_toolTipTextUnselected && !self.selected) {
            [_toolTipDelegate displayTooltip:_toolTipTextUnselected];
        }
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    BOOL changed = self.highlighted != highlighted;

    super.highlighted = highlighted;
    
    if (changed && _toolTipDelegate) {
        if (_toolTipTextHighlighted && self.highlighted) {
            [_toolTipDelegate displayTooltip:_toolTipTextHighlighted];
        }
    }
}

@end
