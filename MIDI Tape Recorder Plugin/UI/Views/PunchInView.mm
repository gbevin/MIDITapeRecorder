//
//  PunchInView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/17/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "PunchInView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation PunchInView {
    CAShapeLayer* _punchInLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _punchInLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    
    if (_punchInLayer) {
        [_punchInLayer removeFromSuperlayer];
    }
    _punchInLayer = [CAShapeLayer layer];
    _punchInLayer.contentsScale = [UIScreen mainScreen].scale;
    
    UIBezierPath* path = [UIBezierPath bezierPath];
    CGFloat x = self.frame.size.width / 2.0;
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x, self.frame.size.height)];
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x + 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x + 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x, 8.0)];
    [path addLineToPoint:CGPointMake(x, 0.0)];

    _punchInLayer.path = path.CGPath;
    _punchInLayer.opacity = 1.0;
    _punchInLayer.lineWidth = 1.0;
    _punchInLayer.fillColor = [UIColor colorNamed:@"Red"].CGColor;
    _punchInLayer.strokeColor = [UIColor colorNamed:@"Red"].CGColor;

    [self.layer addSublayer:_punchInLayer];
}

@end
