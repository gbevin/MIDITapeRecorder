//
//  TracksScrollView.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import <UIKit/UIKit.h>

// Holds the tracks and the markers drawn over them. Marker lines overlap constantly,
// so which one a touch belongs to is decided by how near it is, not by which happens
// to be drawn last.
@interface TracksScrollView : UIScrollView

@end
