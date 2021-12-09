//
//  MidiTrackView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/30/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiTrackView.h"

#import <CoreGraphics/CoreGraphics.h>

#include "Constants.h"

@implementation MidiTrackView {
    CAShapeLayer* _beatsLayer;
    CAShapeLayer* _previewNotesLayer;
    CAShapeLayer* _previewEventsLayer;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _beatsLayer = nil;
        _previewNotesLayer = nil;
        _previewEventsLayer = nil;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.backgroundColor = [UIColor colorNamed:@"Gray4"].CGColor;

    [self updateBeatsLayer];
    [self updateNotesLayer];
    [self updateEventsLayer];
}

- (void)updateBeatsLayer {
    if (_beatsLayer) {
        [_beatsLayer removeFromSuperlayer];
    }
    _beatsLayer = [CAShapeLayer layer];
    _beatsLayer.contentsScale = [UIScreen mainScreen].scale;

    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);

    // draw the vertical beat bars
    UIBezierPath* path = [UIBezierPath bezierPath];
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            [path moveToPoint:CGPointMake(x, 0.0)];
            [path addLineToPoint:CGPointMake(x, self.frame.size.height)];
        }
    }
    _beatsLayer.path = path.CGPath;
    _beatsLayer.opacity = 1.0;
    _beatsLayer.strokeColor = [UIColor colorNamed:@"Gray2"].CGColor;

    [self.layer addSublayer:_beatsLayer];
}

- (void)updateNotesLayer {
    if (_previewNotesLayer) {
        [_previewNotesLayer removeFromSuperlayer];
    }
    _previewNotesLayer = [CAShapeLayer layer];
    _previewNotesLayer.contentsScale = [UIScreen mainScreen].scale;
    
    _previewNotesLayer.path = [self createPreviewPathDrawNotes:YES].CGPath;
    _previewNotesLayer.opacity = 1.0;
    _previewNotesLayer.strokeColor = [UIColor colorNamed:@"PreviewNotes"].CGColor;

    [self.layer addSublayer:_previewNotesLayer];
}

- (void)updateEventsLayer {
    if (_previewEventsLayer) {
        [_previewEventsLayer removeFromSuperlayer];
    }
    _previewEventsLayer = [CAShapeLayer layer];
    _previewEventsLayer.contentsScale = [UIScreen mainScreen].scale;
    
    _previewEventsLayer.path = [self createPreviewPathDrawNotes:NO].CGPath;
    _previewEventsLayer.opacity = 1.0;
    _previewEventsLayer.strokeColor = [UIColor colorNamed:@"PreviewEvents"].CGColor;

    [self.layer addSublayer:_previewEventsLayer];
}

- (UIBezierPath*)createPreviewPathDrawNotes:(BOOL)drawNotes {
    UIBezierPath* path = [UIBezierPath bezierPath];
    NSData* preview = self.preview;
    
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);

    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        int pixel = x * 2;
        
        if (preview != nil && pixel + 1 < preview.length) {
            uint8_t events = ((uint8_t*)preview.bytes)[pixel];
            uint8_t notes = ((uint8_t*)preview.bytes)[pixel+1];
            if (events != 0 || notes != 0) {
                // normalize the preview events count
                float n_events = MIN(((float)events / MAX_PREVIEW_EVENTS), 1.f);
                float n_notes = MIN(((float)notes / MAX_PREVIEW_EVENTS), 1.f);
                // increase the weight of the lower events counts so that they show up more easily
                n_events = pow(n_events, 1.0/1.5);
                n_notes = pow(n_notes, 1.0/1.5);

                CGFloat notes_height = self.frame.size.height - n_notes * self.frame.size.height / 2;
                if (drawNotes) {
                    [path moveToPoint:CGPointMake(x, self.frame.size.height)];
                    [path addLineToPoint:CGPointMake(x, notes_height)];
                }
                else {
                    [path moveToPoint:CGPointMake(x, notes_height - 1)];
                    [path addLineToPoint:CGPointMake(x, notes_height - 1 - n_events * (self.frame.size.height / 2 - 1))];
                }
            }
        }
    }
    
    return path;
}

@end
