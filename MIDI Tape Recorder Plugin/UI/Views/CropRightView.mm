//
//  CropRightView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/8/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "CropRightView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation CropRightView {
    CAShapeLayer* _cropRightLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _cropRightLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    
    if (_cropRightLayer) {
        [_cropRightLayer removeFromSuperlayer];
    }
    _cropRightLayer = [CAShapeLayer layer];
    _cropRightLayer.contentsScale = [UIScreen mainScreen].scale;
    
    UIBezierPath* path = [UIBezierPath bezierPath];
    CGFloat x = self.frame.size.width / 2.0;
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x, self.frame.size.height)];
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x - 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x - 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x, 8.0)];
    [path addLineToPoint:CGPointMake(x, 0.0)];

    _cropRightLayer.path = path.CGPath;
    _cropRightLayer.opacity = 1.0;
    _cropRightLayer.lineWidth = 1.0;
    _cropRightLayer.fillColor = [UIColor colorNamed:@"Gray0"].CGColor;
    _cropRightLayer.strokeColor = [UIColor colorNamed:@"Gray0"].CGColor;

    [self.layer addSublayer:_cropRightLayer];
}

@end
