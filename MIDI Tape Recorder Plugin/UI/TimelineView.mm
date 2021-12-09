//
//  TimelineView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "TimelineView.h"

#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

#include "Constants.h"

@implementation TimelineView {
    CAShapeLayer* _beatsLayer;
    CALayer* _textsLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _beatsLayer = nil;
        _textsLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self updateBeatsLayer];
    [self updateTextsLayer];
    self.layer.masksToBounds = YES;
}

- (void)updateBeatsLayer {
    if (_beatsLayer) {
        [_beatsLayer removeFromSuperlayer];
    }
    _beatsLayer = [CAShapeLayer layer];
    _beatsLayer.contentsScale = [UIScreen mainScreen].scale;
    
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);
    
    // draw vertical beat bars

    UIBezierPath* path = [UIBezierPath bezierPath];
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            [path moveToPoint:CGPointMake(x, 0.0)];
            [path addLineToPoint:CGPointMake(x, self.frame.size.height)];
        }
    }
    
    _beatsLayer.path = path.CGPath;
    _beatsLayer.opacity = 1.0;
    _beatsLayer.strokeColor = [UIColor colorNamed:@"Gray0"].CGColor;

    [self.layer addSublayer:_beatsLayer];
}

- (void)updateTextsLayer {
    if (_textsLayer) {
        [_textsLayer removeFromSuperlayer];
    }
    _textsLayer = [CALayer layer];
    _textsLayer.contentsScale = [UIScreen mainScreen].scale;
    
    UIFont* font = [UIFont systemFontOfSize:9];
    CFStringRef fontName = (__bridge CFStringRef)font.fontName;
    CGFontRef fontRef = CGFontCreateWithFontName(fontName);

    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);

    // draw the beat numbers

    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            CATextLayer* layer_text = [CATextLayer new];
            layer_text.contentsScale = [UIScreen mainScreen].scale;
            layer_text.bounds = CGRectMake(0.0, 0.0, PIXELS_PER_BEAT - 8, self.frame.size.height - 2);
            layer_text.position = CGPointMake(x + 16, 10);
            layer_text.string = [NSString stringWithFormat:@"%d", int(x / PIXELS_PER_BEAT) + 1];
            layer_text.foregroundColor = [UIColor lightGrayColor].CGColor;
            layer_text.font = fontRef;
            layer_text.fontSize = font.pointSize;
            
            [_textsLayer addSublayer:layer_text];
        }
    }
    
    CGFontRelease(fontRef);

    [self.layer addSublayer:_textsLayer];
}

@end
