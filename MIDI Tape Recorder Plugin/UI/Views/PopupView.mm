//
//  PopupView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/28/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "PopupView.h"

#import <CoreGraphics/CoreGraphics.h>

#include "GraphicsHelper.h"

@implementation PopupView {
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
    const CGFloat outline_corner_radius = 8.0f;

    _popupLayer.path = createRoundedCornerPath(CGRectInset(self.bounds, outline_stroke_width, outline_stroke_width),
                                               outline_corner_radius);
    _popupLayer.opacity = 1.0;
    _popupLayer.lineWidth = outline_stroke_width;
    _popupLayer.fillColor = [UIColor colorNamed:@"Gray5"].CGColor;
    _popupLayer.strokeColor = UIColor.blackColor.CGColor;

    _popupLayer.shadowColor = UIColor.blackColor.CGColor;
    _popupLayer.shadowOffset = CGSizeMake(0.0, 0.0);
    _popupLayer.shadowOpacity = 0.7;
    _popupLayer.shadowRadius = 4.0;
    
    [self.layer insertSublayer:_popupLayer atIndex:0];
}

@end
