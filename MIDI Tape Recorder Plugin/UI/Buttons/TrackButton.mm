//
//  TrackButton.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/20/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "TrackButton.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation TrackButton

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return self;
}

- (void)setSelected:(BOOL)selected {
    super.selected = selected;
    
    [self updateButtonStyle];
}

- (void)setHighlighted:(BOOL)highlighted {
    super.highlighted = highlighted;
    
    [self updateButtonStyle];
}

- (void)setEnabled:(BOOL)enabled {
    super.enabled = enabled;
    
    [self updateButtonStyle];
}

- (void)updateButtonStyle {
    if (self.selected || self.highlighted) {
        self.tintColor = self.currentTitleColor;
    }
    else {
        self.tintColor = [UIColor colorNamed:@"ActivityOff"];
    }
}

@end
