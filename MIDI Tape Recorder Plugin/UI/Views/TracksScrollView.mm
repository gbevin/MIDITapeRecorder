//
//  TracksScrollView.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#import "TracksScrollView.h"

#import "TimelineMarker.h"

#include <vector>

#import "TimelineMarkerHitTest.h"

@implementation TracksScrollView

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    NSMutableArray<UIView*>* markers = [NSMutableArray array];
    for (UIView* subview in self.subviews) {
        if (!subview.hidden && [subview conformsToProtocol:@protocol(TimelineMarker)]) {
            [markers addObject:subview];
        }
    }
    NSMutableArray<UIView*>* reachable = [NSMutableArray array];

    if (markers.count > 0) {
        std::vector<TimelineMarkerCandidate> candidates;
        candidates.reserve(markers.count);

        UIView* first = markers.firstObject;
        const CGPoint local = [self convertPoint:point toView:first];
        for (UIView* marker in markers) {
            const CGRect frame = [first convertRect:marker.bounds fromView:marker];
            // a marker only takes touches over its own line, not the whole scroll view
            if (local.y < CGRectGetMinY(frame) || local.y > CGRectGetMaxY(frame)) {
                continue;
            }
            const bool flag_at_top = ((id<TimelineMarker>)marker).flagAtTop;
            candidates.push_back({ CGRectGetMidX(frame), flag_at_top });
            [reachable addObject:marker];
        }

        if (candidates.empty()) {
            return [super hitTest:point withEvent:event];
        }

        const int chosen = chooseTimelineMarker(candidates.data(), (int)candidates.size(),
                                                local.x, local.y, first.bounds.size.height);
        if (chosen >= 0) {
            return reachable[chosen];
        }
    }

    return [super hitTest:point withEvent:event];
}

@end
