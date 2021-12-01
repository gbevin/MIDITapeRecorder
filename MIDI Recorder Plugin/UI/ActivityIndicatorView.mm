//
//  ActivityIndicatorView.mm
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ActivityIndicatorView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation ActivityIndicatorView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)setShowActivity:(BOOL)showActivity {
    _showActivity = showActivity;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);

    if (self.showActivity) {
        CGContextSetFillColorWithColor(context, [UIColor colorNamed:@"ActivityOn"].CGColor);
    }
    else {
        CGContextSetFillColorWithColor(context, [UIColor colorNamed:@"ActivityOff"].CGColor);
    }

    CGContextFillEllipseInRect(context, self.bounds);

    CGContextRestoreGState(context);
}

@end
