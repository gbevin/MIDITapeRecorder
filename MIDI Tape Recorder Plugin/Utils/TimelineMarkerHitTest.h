//
//  TimelineMarkerHitTest.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 9/19/26.
//  MIDI Tape Recorder ©2026 by Geert Bevin is licensed under CC BY 4.0
//

#pragma once

// how far from a marker line a touch still counts as grabbing it
constexpr double MARKER_GRAB_RADIUS = 15.0;

// two markers closer together than this are treated as sitting on the same spot
constexpr double MARKER_SAME_PLACE = 2.0;

struct TimelineMarkerCandidate {
    double center;          // the marker line, in the touch's own coordinates
    bool flagAtTop;         // the end the marker draws its flag on
};

// Picks the marker a touch belongs to, or -1 when the touch is not on one. The
// nearest line wins, so a marker is never unreachable just because another is drawn
// over it. Markers on the same spot can only be told apart by the end the touch is
// nearer, which is the end each draws its flag on.
int chooseTimelineMarker(const TimelineMarkerCandidate* candidates, int count,
                         double touchX, double touchY, double height);
