//
//  TimelineView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "TimelineView.h"

#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

#include "Constants.h"

@implementation TimelineView {
    CGColor* _gray0Color;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _gray0Color = [UIColor colorNamed:@"Gray0"].CGColor;
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

    CGContextSetStrokeColorWithColor(context, _gray0Color);
    
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);
    
    // draw vertical beat bars
    
    CGContextBeginPath(context);

    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
    }
    
    CGContextStrokePath(context);

    // draw the beat numbers
    
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            CGRect textRect = CGRectMake(x + 4, 1, PIXELS_PER_BEAT - 8, self.frame.size.height - 2);
            [[NSString stringWithFormat:@"%d", int(x / PIXELS_PER_BEAT) + 1] drawInRect:textRect
                                                                         withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:9],
                                                                                          NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
        }
    }

    CGContextRestoreGState(context);
}

@end
