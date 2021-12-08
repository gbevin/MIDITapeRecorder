//
//  ActivityIndicatorView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ActivityIndicatorView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation ActivityIndicatorView {
    CGColor* _activityOnColor;
    CGColor* _activityOffColor;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _activityOnColor = [UIColor colorNamed:@"ActivityOn"].CGColor;
        _activityOffColor = [UIColor colorNamed:@"ActivityOff"].CGColor;
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)setShowActivity:(BOOL)showActivity {
    _showActivity = showActivity;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    CGContextClearRect(context, self.bounds);

    if (self.showActivity) {
        CGContextSetFillColorWithColor(context, _activityOnColor);
    }
    else {
        CGContextSetFillColorWithColor(context, _activityOffColor);
    }

    CGContextFillEllipseInRect(context, self.bounds);

    CGContextRestoreGState(context);
}

@end
