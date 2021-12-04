//
//  MidiTrackView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiTrackView.h"

#import <CoreGraphics/CoreGraphics.h>

#include "Constants.h"

@implementation MidiTrackView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);

    CGContextSetFillColorWithColor(context, [UIColor colorNamed:@"Gray4"].CGColor);
    CGContextFillRect(context, self.bounds);

    CGColor* gray2_color = [UIColor colorNamed:@"Gray2"].CGColor;
    CGColor* teal_color = [UIColor colorNamed:@"Teal"].CGColor;
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        CGContextSetStrokeColorWithColor(context, gray2_color);
        if (x % PIXELS_PER_SECOND == 0) {
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
        CGContextStrokePath(context);
        
        NSData* preview = self.preview;
        if (preview != nil && x < preview.length) {
            uint8_t activity = ((uint8_t*)preview.bytes)[x];
            if (activity != 0) {
                CGContextSetStrokeColorWithColor(context, teal_color);
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
