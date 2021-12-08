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
    CGColor* _gray2Color;
    CGColor* _gray4Color;
    CGColor* _notesColor;
    CGColor* _eventsColor;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];
    
    if (self) {
        _gray2Color = [UIColor colorNamed:@"Gray2"].CGColor;
        _gray4Color = [UIColor colorNamed:@"Gray4"].CGColor;
        _notesColor = [UIColor colorNamed:@"PreviewNotes"].CGColor;
        _eventsColor = [UIColor colorNamed:@"PreviewEvents"].CGColor;
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);

    // fill the background
    
    CGContextSetFillColorWithColor(context, _gray4Color);
    CGContextFillRect(context, self.bounds);

    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);

    // draw the vertical beat bars
    
    CGContextBeginPath(context);
    CGContextSetStrokeColorWithColor(context, _gray2Color);
    
    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        if (x % PIXELS_PER_BEAT == 0) {
            CGContextMoveToPoint(context, x, 0.0);
            CGContextAddLineToPoint(context, x, self.frame.size.height);
        }
    }
    
    CGContextStrokePath(context);
    
    // draw the data preview
    
    [self drawPreviewData:context drawNotes:YES];
    [self drawPreviewData:context drawNotes:NO];
}

- (void)drawPreviewData:(CGContextRef)context drawNotes:(BOOL)drawNotes {
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);

    CGContextBeginPath(context);

    if (drawNotes) {
        CGContextSetStrokeColorWithColor(context, _notesColor);
    }
    else {
        CGContextSetStrokeColorWithColor(context, _eventsColor);
    }

    for (int x = x_offset; x < self.frame.size.width && x < x_offset + _tracks.frame.size.width; ++x) {
        NSData* preview = self.preview;
        
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
                    CGContextMoveToPoint(context, x, self.frame.size.height);
                    CGContextAddLineToPoint(context, x, notes_height);
                }
                else {
                    CGContextMoveToPoint(context, x, notes_height - 1);
                    CGContextAddLineToPoint(context, x, notes_height - 1 - n_events * (self.frame.size.height / 2 - 1));
                }
            }
        }
    }
    
    CGContextStrokePath(context);
}

@end
