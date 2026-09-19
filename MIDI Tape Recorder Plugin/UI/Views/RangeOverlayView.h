//
//  RangeOverlayView.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

// The draggable body of a crop or punch range. It is drawn over the full height of
// the tracks, but it is only dragged on the timeline, so it only takes touches
// there: anywhere else it would swallow touches meant for the markers underneath.
@interface RangeOverlayView : UIView

@property (nonatomic) CGFloat grabHeight;

@end
