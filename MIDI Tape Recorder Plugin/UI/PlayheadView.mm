//
//  PlayheadView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/8/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "PlayheadView.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation PlayheadView {
    CAShapeLayer* _playheadLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _playheadLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_playheadLayer) {
        [_playheadLayer removeFromSuperlayer];
    }
    _playheadLayer = [CAShapeLayer layer];
    _playheadLayer.contentsScale = [UIScreen mainScreen].scale;
    
    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(self.frame.size.width / 2.0, 0.0)];
    [path addLineToPoint:CGPointMake(self.frame.size.width / 2.0, self.frame.size.height)];

    _playheadLayer.path = path.CGPath;
    _playheadLayer.opacity = 1.0;
    _playheadLayer.lineWidth = 1.0;
    _playheadLayer.strokeColor = UIColor.whiteColor.CGColor;

    [self.layer addSublayer:_playheadLayer];
}

@end
