//
//  PunchOutView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/17/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "PunchOutView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation PunchOutView {
    CAShapeLayer* _punchOutLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _punchOutLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    
    if (_punchOutLayer) {
        [_punchOutLayer removeFromSuperlayer];
    }
    _punchOutLayer = [CAShapeLayer layer];
    _punchOutLayer.contentsScale = [UIScreen mainScreen].scale;
    
    UIBezierPath* path = [UIBezierPath bezierPath];
    CGFloat x = self.frame.size.width / 2.0;
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x, self.frame.size.height)];
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x - 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x - 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x, 8.0)];
    [path addLineToPoint:CGPointMake(x, 0.0)];

    _punchOutLayer.path = path.CGPath;
    _punchOutLayer.opacity = 1.0;
    _punchOutLayer.lineWidth = 1.0;
    _punchOutLayer.fillColor = [UIColor colorNamed:@"Red"].CGColor;
    _punchOutLayer.strokeColor = [UIColor colorNamed:@"Red"].CGColor;

    [self.layer addSublayer:_punchOutLayer];
}

@end
