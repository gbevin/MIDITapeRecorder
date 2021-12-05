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

    CGColor* gray2_color = [UIColor colorNamed:@"Gray2"].CGColor;
    CGColor* gray4_color = [UIColor colorNamed:@"Gray4"].CGColor;
    CGColor* teal_color = [UIColor colorNamed:@"Teal"].CGColor;
    
    // fill the background
    
    CGContextSetFillColorWithColor(context, gray4_color);
    CGContextFillRect(context, self.bounds);

    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);

    // draw the vertical second bars
    
    CGContextBeginPath(context);
    CGContextSetStrokeColorWithColor(context, gray2_color);
    
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
    }
    
    CGContextStrokePath(context);
    
    // draw the data preview
    
    CGContextBeginPath(context);
    CGContextSetStrokeColorWithColor(context, teal_color);

    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        NSData* preview = self.preview;
        if (preview != nil && x < preview.length) {
            uint8_t activity = ((uint8_t*)preview.bytes)[x];
            if (activity != 0) {
                CGContextMoveToPoint(context, x, self.frame.size.height);
                
                // normalize the preview event count
                float v = MIN(((float)activity / MAX_PREVIEW_EVENTS), 1.f);
                // increase the weight of the lower events counts so that they show up more easily
                v = pow(v, 1.0/2.0);
                
                CGContextAddLineToPoint(context, x, self.frame.size.height - v * self.frame.size.height);
            }
        }
    }
    
    CGContextStrokePath(context);

    CGContextRestoreGState(context);
}

@end
