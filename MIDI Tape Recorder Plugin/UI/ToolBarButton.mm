//
//  ToolBarButton.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/2/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ToolBarButton.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation ToolBarButton

- (void)setSelected:(BOOL)selected {
    super.selected = selected;
    
    [self updateButtonStyle];
}

- (void)setHighlighted:(BOOL)highlighted {
    super.highlighted = highlighted;
    
    [self updateButtonStyle];
}

- (void)updateButtonStyle {
    if (self.selected || self.highlighted) {
        self.backgroundColor = self.currentTitleColor;
        self.tintColor = UIColor.blackColor;
    }
    else {
        self.backgroundColor = UIColor.clearColor;
        self.tintColor = self.currentTitleColor;
    }
    
    self.layer.cornerRadius = 5;
}

@end
