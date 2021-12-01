//
//  Timeline.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//

#import "Timeline.h"

#import <CoreGraphics/CoreGraphics.h>

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
        CGContextSetStrokeColorWithColor(context, [UIColor lightGrayColor].CGColor);
        if (x % PIXELS_PER_SECOND == 0) {
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
        else if (x % (PIXELS_PER_SECOND / 4) == 0) {
            CGContextMoveToPoint(context, x, self.frame.size.height / 2.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
        CGContextStrokePath(context);
    }
    
    CGContextRestoreGState(context);
}

@end
