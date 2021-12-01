//
//  MidiTrack.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//

#import "MidiTrack.h"

#import <CoreGraphics/CoreGraphics.h>

#import "Constants.h"

@implementation MidiTrack

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.backgroundColor = UIColor.systemGray4Color;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);

    for (int x = 0; x < self.frame.size.width; ++x) {
        CGContextSetStrokeColorWithColor(context, [UIColor darkGrayColor].CGColor);
        if (x % PIXELS_PER_SECOND == 0) {
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
        CGContextStrokePath(context);
    }
    
    CGContextRestoreGState(context);
}

@end
