//
//  PlayheadView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/8/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "PlayheadView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation PlayheadView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    CGContextMoveToPoint(context, self.frame.size.width / 2.0, 0.0);
    CGContextAddLineToPoint(context, self.frame.size.width / 2.0, self.frame.size.height);

    CGContextSetStrokeColorWithColor(context, UIColor.whiteColor.CGColor);
    CGContextSetLineWidth(context, 1.0);
    CGContextStrokePath(context);
    
    CGContextRestoreGState(context);
}

@end
