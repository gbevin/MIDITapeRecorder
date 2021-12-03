//
//  MenuPopupView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MenuPopupView.h"

#import <CoreGraphics/CoreGraphics.h>

#include "GraphicsHelper.h"

@implementation MenuPopupView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    self.layer.shadowOpacity = 0.7;
    self.layer.shadowRadius = 4.0;
};

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    const CGFloat outline_stroke_width = 1.0f;
    const CGFloat outline_corner_radius = 8.0f;

    CGContextAddPath(context, createRoundedCornerPath(CGRectInset(self.bounds, outline_stroke_width, outline_stroke_width),
                                                      outline_corner_radius));

    CGContextSetFillColorWithColor(context, UIColor.systemGray5Color.CGColor);
    CGContextSetStrokeColorWithColor(context, UIColor.blackColor.CGColor);
    CGContextSetLineWidth(context, outline_stroke_width);
    CGContextDrawPath(context, kCGPathFillStroke);
    
    CGContextRestoreGState(context);
}

@end
