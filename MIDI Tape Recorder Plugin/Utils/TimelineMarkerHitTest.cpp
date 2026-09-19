//
//  TimelineMarkerHitTest.cpp
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#include "TimelineMarkerHitTest.h"

#include <cmath>

int chooseTimelineMarker(const TimelineMarkerCandidate* candidates, int count,
                         double touchX, double touchY, double height) {
    const bool grabbed_near_top = (touchY < height / 2.0);

    int chosen = -1;
    double chosen_distance = 0.0;

    for (int i = 0; i < count; ++i) {
        const double distance = std::fabs(touchX - candidates[i].center);
        if (distance > MARKER_GRAB_RADIUS) {
            continue;
        }

        if (chosen < 0) {
            chosen = i;
            chosen_distance = distance;
            continue;
        }

        // on the same spot the end the touch is nearer decides, otherwise the
        // nearer line wins
        if (std::fabs(distance - chosen_distance) <= MARKER_SAME_PLACE) {
            if (candidates[i].flagAtTop == grabbed_near_top &&
                candidates[chosen].flagAtTop != grabbed_near_top) {
                chosen = i;
                chosen_distance = distance;
            }
        }
        else if (distance < chosen_distance) {
            chosen = i;
            chosen_distance = distance;
        }
    }

    return chosen;
}
