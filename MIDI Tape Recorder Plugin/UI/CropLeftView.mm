//
//  CropLeftView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/8/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "CropLeftView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation CropLeftView {
    CAShapeLayer* _cropLeftLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _cropLeftLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.backgroundColor = UIColor.clearColor.CGColor;
    
    if (_cropLeftLayer) {
        [_cropLeftLayer removeFromSuperlayer];
    }
    _cropLeftLayer = [CAShapeLayer layer];
    _cropLeftLayer.contentsScale = [UIScreen mainScreen].scale;
    
    UIBezierPath* path = [UIBezierPath bezierPath];
    CGFloat x = self.frame.size.width / 2.0;
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x, self.frame.size.height)];
    [path moveToPoint:CGPointMake(x, 0.0)];
    [path addLineToPoint:CGPointMake(x + 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x + 8.0, 0.0)];
    [path addLineToPoint:CGPointMake(x, 8.0)];
    [path addLineToPoint:CGPointMake(x, 0.0)];

    _cropLeftLayer.path = path.CGPath;
    _cropLeftLayer.opacity = 1.0;
    _cropLeftLayer.lineWidth = 1.0;
    _cropLeftLayer.fillColor = [UIColor colorNamed:@"Gray0"].CGColor;
    _cropLeftLayer.strokeColor = [UIColor colorNamed:@"Gray0"].CGColor;

    [self.layer addSublayer:_cropLeftLayer];
}

@end
