//
//  MenuButton.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/2/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MenuButton.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation MenuButton {
    CGColor* _gray0Color;
    CGColor* _activityOffColor;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _gray0Color = [UIColor colorNamed:@"Gray0"].CGColor;
        _activityOffColor = [UIColor colorNamed:@"ActivityOff"].CGColor;
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    CGContextClearRect(context, self.bounds);

    if (self.highlighted) {
        CGContextSetFillColorWithColor(context, _gray0Color);
    }
    else {
        CGContextSetFillColorWithColor(context, _activityOffColor);
    }
    CGFloat y_center = self.bounds.size.height / 2 - 1;
    CGContextFillRect(context, CGRectMake(5, y_center - 9, self.bounds.size.width - 10, 2));
    CGContextFillRect(context, CGRectMake(5, y_center, self.bounds.size.width - 10, 2));
    CGContextFillRect(context, CGRectMake(5, y_center + 9, self.bounds.size.width - 10, 2));

    CGContextRestoreGState(context);
}

@end
