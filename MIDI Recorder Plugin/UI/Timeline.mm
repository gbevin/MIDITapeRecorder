//
//  Timeline.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
//

#import "Timeline.h"

#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

#import "Constants.h"

@implementation Timeline

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);

    for (int x = 0; x < self.frame.size.width; ++x) {
        if (x % PIXELS_PER_SECOND == 0) {
            CGContextSetStrokeColorWithColor(context, [UIColor lightGrayColor].CGColor);
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
            CGContextStrokePath(context);

            CGRect textRect = CGRectMake(x + 4, 1, PIXELS_PER_SECOND - 8, self.frame.size.height - 2);
            [[NSString stringWithFormat:@"%d", int(x / PIXELS_PER_SECOND) + 1] drawInRect:textRect
                                                                           withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:9],
                                                                                            NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
        }
        else if (x % (PIXELS_PER_SECOND / 4) == 0) {
            CGContextSetStrokeColorWithColor(context, [UIColor lightGrayColor].CGColor);
            CGContextMoveToPoint(context, x, 2.0 * self.frame.size.height / 3.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
            CGContextStrokePath(context);
        }
    }
    
    CGContextRestoreGState(context);
}

@end
