//
//  ToolBarButton.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/2/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ToolBarButton.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation ToolBarButton {
    NSTimer* _unselectTimer;
}

- (void)setSelected:(BOOL)selected {
    if (_unselectTimer) {
        [_unselectTimer invalidate];
        _unselectTimer = nil;
    }
    
    super.selected = selected;
    
    [self updateButtonStyle];
    
    if (_timedUnselect && selected) {
        _unselectTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                          target:self
                                                        selector:@selector(timedUnselect:)
                                                        userInfo:nil
                                                         repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:_unselectTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)timedUnselect:(NSTimer*)timer {
    [timer invalidate];
    timer = nil;
    
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^() {
                         self.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         self.alpha = 1.0;
                         super.selected = NO;
                         
                         [self updateButtonStyle];
                     }];
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
