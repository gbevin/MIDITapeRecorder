//
//  RangeOverlayView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "RangeOverlayView.h"

@implementation RangeOverlayView

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _grabHeight = 0.0;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    if (point.y > _grabHeight) {
        return NO;
    }

    return [super pointInside:point withEvent:event];
}

@end
