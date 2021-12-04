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

@implementation TimelineView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);

    CGColor* gray0_color = [UIColor colorNamed:@"Gray0"].CGColor;
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_SECOND == 0) {
            CGContextSetStrokeColorWithColor(context, gray0_color);
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
            CGContextStrokePath(context);

            CGRect textRect = CGRectMake(x + 4, 1, PIXELS_PER_SECOND - 8, self.frame.size.height - 2);
            [[NSString stringWithFormat:@"%d", int(x / PIXELS_PER_SECOND) + 1] drawInRect:textRect
                                                                           withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:9],
                                                                                            NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
        }
        else if (x % (PIXELS_PER_SECOND / 4) == 0) {
            CGContextSetStrokeColorWithColor(context, gray0_color);
            CGContextMoveToPoint(context, x, 2.0 * self.frame.size.height / 3.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
            CGContextStrokePath(context);
        }
    }
    
    CGContextRestoreGState(context);
}

@end
