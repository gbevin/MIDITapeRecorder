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

#import "MidiPreviewProvider.h"

@interface MidiTrackBeatEntry : NSObject;

@property CAShapeLayer* beatLayer;
@property CAShapeLayer* previewNotesLayer;
@property CAShapeLayer* previewEventsLayer;
@property CAShapeLayer* recordingNotesLayer;
@property CAShapeLayer* recordingEventsLayer;

@end

@implementation MidiTrackBeatEntry;
@end

@implementation MidiTrackView {
    NSMutableDictionary<NSNumber*, MidiTrackBeatEntry*>* _beatLayers;
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
    
    self.layer.backgroundColor = [UIColor colorNamed:@"Gray4"].CGColor;

    [self updateBeatLayers];
}

- (void)removePreviewLayers:(MidiTrackBeatEntry*)entry {
    if (entry.previewNotesLayer) [entry.previewNotesLayer removeFromSuperlayer];
    if (entry.previewEventsLayer) [entry.previewEventsLayer removeFromSuperlayer];
    if (entry.recordingNotesLayer) [entry.recordingNotesLayer removeFromSuperlayer];
    if (entry.recordingEventsLayer) [entry.recordingEventsLayer removeFromSuperlayer];
    entry.previewNotesLayer = nil;
    entry.previewEventsLayer = nil;
    entry.recordingNotesLayer = nil;
    entry.recordingEventsLayer = nil;
}

- (void)rebuild {
    for (MidiTrackBeatEntry* entry in _beatLayers.allValues) {
        [entry.beatLayer removeFromSuperlayer];
        [self removePreviewLayers:entry];
    }
    [_beatLayers removeAllObjects];

    _beatLayers = [NSMutableDictionary new];
}

- (void)updateBeatLayers {
    CGFloat x_offset =  MAX(0.0, _tracks.contentOffset.x - 10.0);
    CGFloat x_end = MIN(self.frame.size.width, x_offset + _tracks.frame.size.width) - 1.0;
    
    // remove all the existing layers that shouldn't be displayed anynore
    
    int begin_beat = floor(x_offset / PIXELS_PER_BEAT);
    int end_beat = floor(x_end / PIXELS_PER_BEAT);
    for (NSNumber* beat in _beatLayers.allKeys) {
        if (beat.intValue < begin_beat || beat.intValue > end_beat) {
            MidiTrackBeatEntry* entry = [_beatLayers objectForKey:beat];
            [entry.beatLayer removeFromSuperlayer];
            [self removePreviewLayers:entry];

            [_beatLayers removeObjectForKey:beat];
        }
    }
    
    // add new layers that don't exist yet and cache them
    
    for (int beat = begin_beat; beat <= end_beat; ++beat) {
        MidiTrackBeatEntry* entry = [_beatLayers objectForKey:@(beat)];
        if (entry && [_previewProvider refreshPreviewBeat:beat]) {
            [self removePreviewLayers:entry];
        }
        
        if (entry == nil || entry.previewNotesLayer == nil || entry.previewEventsLayer == nil) {
            int x = beat * PIXELS_PER_BEAT;
            
            if (entry == nil) {
                entry = [MidiTrackBeatEntry new];
            }

            // draw vertical beat bars
            if (entry.beatLayer == nil) {
                UIBezierPath* beat_path = [UIBezierPath bezierPath];
                [beat_path moveToPoint:CGPointMake(x, 0.0)];
                [beat_path addLineToPoint:CGPointMake(x, self.frame.size.height)];
                
                CAShapeLayer* beat_layer = [CAShapeLayer layer];
                beat_layer.contentsScale = [UIScreen mainScreen].scale;
                beat_layer.path = beat_path.CGPath;
                beat_layer.opacity = 1.0;
                beat_layer.strokeColor = [UIColor colorNamed:@"Gray2"].CGColor;

                [self.layer addSublayer:beat_layer];
                
                entry.beatLayer = beat_layer;
            }
            
            // draw the notes
            if (entry.previewNotesLayer == nil) {
                UIBezierPath* preview_notes_path = [UIBezierPath bezierPath];
                [self createPreviewPath:preview_notes_path beat:beat drawNotes:YES drawRecording:NO];
                
                CAShapeLayer* preview_notes_layer = [CAShapeLayer layer];
                preview_notes_layer.contentsScale = [UIScreen mainScreen].scale;
                preview_notes_layer.path = preview_notes_path.CGPath;
                preview_notes_layer.opacity = 1.0;
                preview_notes_layer.strokeColor = [UIColor colorNamed:@"PreviewNotes"].CGColor;

                [self.layer addSublayer:preview_notes_layer];

                entry.previewNotesLayer = preview_notes_layer;
            }

            // draw the event
            if (entry.previewEventsLayer == nil) {
                UIBezierPath* preview_events_path = [UIBezierPath bezierPath];
                [self createPreviewPath:preview_events_path beat:beat drawNotes:NO drawRecording:NO];
                
                CAShapeLayer* preview_events_layer = [CAShapeLayer layer];
                preview_events_layer.contentsScale = [UIScreen mainScreen].scale;
                preview_events_layer.path = preview_events_path.CGPath;
                preview_events_layer.opacity = 1.0;
                preview_events_layer.strokeColor = [UIColor colorNamed:@"PreviewEvents"].CGColor;

                [self.layer addSublayer:preview_events_layer];
                
                entry.previewEventsLayer = preview_events_layer;
            }
            
            // draw the recording notes
            if (entry.recordingNotesLayer == nil) {
                UIBezierPath* preview_notes_path = [UIBezierPath bezierPath];
                [self createPreviewPath:preview_notes_path beat:beat drawNotes:YES drawRecording:YES];
                
                CAShapeLayer* preview_notes_layer = [CAShapeLayer layer];
                preview_notes_layer.contentsScale = [UIScreen mainScreen].scale;
                preview_notes_layer.path = preview_notes_path.CGPath;
                preview_notes_layer.opacity = 1.0;
                preview_notes_layer.strokeColor = [UIColor colorNamed:@"RecordingNotes"].CGColor;

                [self.layer addSublayer:preview_notes_layer];

                entry.recordingNotesLayer = preview_notes_layer;
            }

            // draw the recording event
            if (entry.recordingEventsLayer == nil) {
                UIBezierPath* preview_events_path = [UIBezierPath bezierPath];
                [self createPreviewPath:preview_events_path beat:beat drawNotes:NO drawRecording:YES];
                
                CAShapeLayer* preview_events_layer = [CAShapeLayer layer];
                preview_events_layer.contentsScale = [UIScreen mainScreen].scale;
                preview_events_layer.path = preview_events_path.CGPath;
                preview_events_layer.opacity = 1.0;
                preview_events_layer.strokeColor = [UIColor colorNamed:@"RecordingEvents"].CGColor;

                [self.layer addSublayer:preview_events_layer];
                
                entry.recordingEventsLayer = preview_events_layer;
            }

            // remember the layers
            [_beatLayers setObject:entry forKey:@(beat)];
        }
    }
}

- (void)createPreviewPath:(UIBezierPath*)path beat:(int)beat drawNotes:(BOOL)drawNotes drawRecording:(BOOL)drawRecording {
    int x_begin = beat * PIXELS_PER_BEAT;
    int x_end = x_begin + PIXELS_PER_BEAT;
    for (int x = x_begin; x < x_end; ++x) {
        if (_previewProvider && x < [_previewProvider previewPixelCount]) {
            PreviewPixelData pixel_data =[_previewProvider previewPixelData:x];
            if ((pixel_data.dirty && drawRecording) || (!pixel_data.dirty && !drawRecording))
            if (pixel_data.notes != 0 || pixel_data.events != 0) {
                // normalize the preview events count
                float n_notes = MIN(MAX(((float)pixel_data.notes / MAX_PREVIEW_EVENTS), 0.f), 1.f);
                float n_events = MIN(MAX(((float)pixel_data.events / MAX_PREVIEW_EVENTS), 0.f), 1.f);
                // increase the weight of the lower events counts so that they show up more easily
                n_notes = pow(n_notes, 1.0/1.5);
                n_events = pow(n_events, 1.0/1.5);

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
}

@end
