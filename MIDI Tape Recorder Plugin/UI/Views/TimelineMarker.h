//
//  TimelineMarker.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

// A draggable marker line on the tracks. The whole line is draggable, so two of them
// that land on the same spot can only be told apart by which end the grab is nearer:
// that is the end the marker draws its flag on.
@protocol TimelineMarker <NSObject>

@property (nonatomic, readonly) BOOL flagAtTop;

@end
