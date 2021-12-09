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

@interface TimelineBeatEntry : NSObject;
@property CAShapeLayer* beatLayer;
@property CATextLayer* textLayer;
@end

@implementation TimelineBeatEntry;
@end

@implementation TimelineView {
    NSMutableDictionary<NSNumber*, TimelineBeatEntry*>* _beatLayers;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _beatLayers = [NSMutableDictionary new];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self updateBeatLayers];
    self.layer.masksToBounds = YES;
}

- (void)updateBeatLayers {
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);
    CGFloat x_end = MIN(self.frame.size.width, x_offset + _tracks.frame.size.width) - 1.0;
    
    // remove all the existing layers that shouldn't be displayed anynore
    
    int begin_beat = floor(x_offset / PIXELS_PER_BEAT);
    int end_beat = floor(x_end / PIXELS_PER_BEAT);
    for(NSNumber* beat in _beatLayers.allKeys) {
        if (beat.intValue < begin_beat || beat.intValue > end_beat) {
            TimelineBeatEntry* entry = [_beatLayers objectForKey:beat];
            [entry.beatLayer removeFromSuperlayer];
            [entry.textLayer removeFromSuperlayer];
            
            [_beatLayers removeObjectForKey:beat];
        }
    }
    
    // add new layers that don't exist yet and cache them
    
    UIFont* font = [UIFont systemFontOfSize:9];
    CFStringRef font_name = (__bridge CFStringRef)font.fontName;
    CGFontRef font_ref = CGFontCreateWithFontName(font_name);

    for (int beat = begin_beat; beat <= end_beat; ++beat) {
        TimelineBeatEntry* entry = [_beatLayers objectForKey:@(beat)];
        if (entry == nil) {
            int x = beat * PIXELS_PER_BEAT;
            
            // draw vertical beat bars
            UIBezierPath* beat_path = [UIBezierPath bezierPath];
            [beat_path moveToPoint:CGPointMake(x, 0.0)];
            [beat_path addLineToPoint:CGPointMake(x, self.frame.size.height)];
            
            CAShapeLayer* beat_layer = [CAShapeLayer layer];
            beat_layer.contentsScale = [UIScreen mainScreen].scale;
            beat_layer.path = beat_path.CGPath;
            beat_layer.opacity = 1.0;
            beat_layer.strokeColor = [UIColor colorNamed:@"Gray0"].CGColor;

            [self.layer addSublayer:beat_layer];
            
            // draw the beat numbers
            CATextLayer* text_layer = [CATextLayer new];
            text_layer.contentsScale = [UIScreen mainScreen].scale;
            text_layer.bounds = CGRectMake(0.0, 0.0, PIXELS_PER_BEAT - 8, self.frame.size.height - 2);
            text_layer.position = CGPointMake(x + 16, 10);
            text_layer.string = [NSString stringWithFormat:@"%d", int(x / PIXELS_PER_BEAT) + 1];
            text_layer.foregroundColor = [UIColor lightGrayColor].CGColor;
            text_layer.font = font_ref;
            text_layer.fontSize = font.pointSize;
            
            [self.layer addSublayer:text_layer];
            
            // remember the layers
            entry = [TimelineBeatEntry new];
            entry.beatLayer = beat_layer;
            entry.textLayer = text_layer;
            [_beatLayers setObject:entry forKey:@(beat)];
        }
    }
    
    CGFontRelease(font_ref);
}

@end
