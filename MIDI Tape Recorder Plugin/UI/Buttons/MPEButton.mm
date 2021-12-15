//
//  MPEButton.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/9/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MPEButton.h"

#import <CoreGraphics/CoreGraphics.h>

@implementation MPEButton {
    CAShapeLayer* _popupLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _popupLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_popupLayer) {
        [_popupLayer removeFromSuperlayer];
    }
    _popupLayer = [CAShapeLayer layer];
    _popupLayer.contentsScale = [UIScreen mainScreen].scale;
    
    const CGFloat outline_stroke_width = 1.0f;
    const CGFloat corner_radius = 8.0f;

    // create a mutable path
    CGMutablePathRef path = CGPathCreateMutable();

    CGRect rect = self.bounds;
    
    CGPoint top_left = CGPointMake(rect.origin.x - outline_stroke_width, rect.origin.y - outline_stroke_width);
    CGPoint top_right = CGPointMake(rect.origin.x + rect.size.width, rect.origin.y - outline_stroke_width);
    CGPoint bottom_right = CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    CGPoint bottom_left = CGPointMake(rect.origin.x - outline_stroke_width, rect.origin.y + rect.size.height);
    CGPathMoveToPoint(path, nil, top_left.x, top_left.y);
    CGPathAddLineToPoint(path, nil, top_right.x, top_right.y);
    CGPathAddLineToPoint(path, nil, bottom_right.x, bottom_right.y - corner_radius);
    CGPathAddQuadCurveToPoint(path, nil, bottom_right.x, bottom_right.y, bottom_right.x - corner_radius, bottom_right.y);
    CGPathAddLineToPoint(path, nil, bottom_left.x, bottom_left.y);
    CGPathAddLineToPoint(path, nil, top_left.x, top_left.y);
    
    _popupLayer.path = path;
    _popupLayer.opacity = outline_stroke_width;
    _popupLayer.lineWidth = 1.0;
    _popupLayer.fillColor = [UIColor colorNamed:@"Gray5"].CGColor;
    _popupLayer.strokeColor = UIColor.blackColor.CGColor;

    _popupLayer.shadowColor = UIColor.blackColor.CGColor;
    _popupLayer.shadowOffset = CGSizeMake(2.0, 2.0);
    _popupLayer.shadowOpacity = 0.3;
    _popupLayer.shadowRadius = 2.0;
    
    [self.layer insertSublayer:_popupLayer atIndex:0];
}

@end
