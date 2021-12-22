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
    UIVisualEffectView* _blur;
    CAShapeLayer* _popupLayer;
    UIView* _outline;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _popupLayer = nil;
        _outline = nil;

        self.backgroundColor = UIColor.clearColor;

        _outline = [UIView new];
        _outline.translatesAutoresizingMaskIntoConstraints = NO;
        _outline.clipsToBounds = NO;
        
        [self insertSubview:_outline atIndex:0];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_outline
                             attribute:NSLayoutAttributeTop
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeTop
                             multiplier:1.0
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_outline
                             attribute:NSLayoutAttributeLeading
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeLeading
                             multiplier:1.0
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_outline
                             attribute:NSLayoutAttributeHeight
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeHeight
                             multiplier:1.0
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_outline
                             attribute:NSLayoutAttributeWidth
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeWidth
                             multiplier:1.0
                             constant:0]];
        
        _blur = [UIVisualEffectView new];
        if (@available(iOS 13.0, *)) {
            _blur.alpha = 0.97;
            _blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        }
        else {
            _blur.alpha = 0.95;
            _blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        }
        _blur.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self insertSubview:_blur atIndex:0];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_blur
                             attribute:NSLayoutAttributeTop
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeTop
                             multiplier:1.0
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_blur
                             attribute:NSLayoutAttributeLeading
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeLeading
                             multiplier:1.0
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_blur
                             attribute:NSLayoutAttributeHeight
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeHeight
                             multiplier:1.0
                             constant:0]];
        
        [self addConstraint:[NSLayoutConstraint
                             constraintWithItem:_blur
                             attribute:NSLayoutAttributeWidth
                             relatedBy:NSLayoutRelationEqual
                             toItem:self
                             attribute:NSLayoutAttributeWidth
                             multiplier:1.0
                             constant:0]];
        
        _blur.layer.cornerRadius = 8.0;
        _blur.clipsToBounds = YES;
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
    
    const CGFloat outline_corner_radius = 8.0;

    _popupLayer.path = createRoundedCornerPath(self.bounds, outline_corner_radius);
    _popupLayer.opacity = 1.0;
    _popupLayer.lineWidth = 1.0;
    _popupLayer.strokeColor = UIColor.blackColor.CGColor;
    _popupLayer.fillColor = nil;

    _popupLayer.shadowColor = UIColor.blackColor.CGColor;
    _popupLayer.shadowOffset = CGSizeMake(0.0, 0.0);
    _popupLayer.shadowOpacity = 1.0;
    _popupLayer.shadowRadius = 4.0;
    
    [_outline.layer insertSublayer:_popupLayer atIndex:0];
}

@end
