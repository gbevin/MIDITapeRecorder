//
//  MidiTrack.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY-SA 4.0
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
        
        NSData* preview = self.preview;
        if (preview != nil && x < preview.length) {
            uint8_t activity = ((uint8_t*)preview.bytes)[x];
            if (activity != 0) {
                CGContextSetStrokeColorWithColor(context, [UIColor systemTealColor].CGColor);
                CGContextMoveToPoint(context, x, self.frame.size.height);
                float v = MIN(((float)activity / MAX_PREVIEW_EVENTS), 1.f);
                v = pow(v, 1.0/2.0);
                CGContextAddLineToPoint(context, x, self.frame.size.height - v * self.frame.size.height);
                CGContextStrokePath(context);
            }
        }
    }
    
    CGContextRestoreGState(context);
}

@end
