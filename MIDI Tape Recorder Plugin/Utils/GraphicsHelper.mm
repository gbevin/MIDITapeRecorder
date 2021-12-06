//
//  GraphicsHelper.mm
//  MIDI Tape Recorder
//
//  Created by Geert Bevin on 12/2/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "GraphicsHelper.h"

CGMutablePathRef createRoundedCornerPath(CGRect rect, CGFloat cornerRadius) {
    // create a mutable path
    CGMutablePathRef path = CGPathCreateMutable();

    // get the 4 corners of the rect
    CGPoint top_left = CGPointMake(rect.origin.x, rect.origin.y);
    CGPoint top_right = CGPointMake(rect.origin.x + rect.size.width, rect.origin.y);
    CGPoint bottom_right = CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
    CGPoint bottom_left = CGPointMake(rect.origin.x, rect.origin.y + rect.size.height);

    // move to top left
    CGPathMoveToPoint(path, NULL, top_left.x + cornerRadius, top_left.y);

    // add top line
    CGPathAddLineToPoint(path, NULL, top_right.x - cornerRadius, top_right.y);

    // add top right curve
    CGPathAddQuadCurveToPoint(path, NULL, top_right.x, top_right.y, top_right.x, top_right.y + cornerRadius);

    // add right line
    CGPathAddLineToPoint(path, NULL, bottom_right.x, bottom_right.y - cornerRadius);

    // add bottom right curve
    CGPathAddQuadCurveToPoint(path, NULL, bottom_right.x, bottom_right.y, bottom_right.x - cornerRadius, bottom_right.y);

    // add bottom line
    CGPathAddLineToPoint(path, NULL, bottom_left.x + cornerRadius, bottom_left.y);

    // add bottom left curve
    CGPathAddQuadCurveToPoint(path, NULL, bottom_left.x, bottom_left.y, bottom_left.x, bottom_left.y - cornerRadius);

    // add left line
    CGPathAddLineToPoint(path, NULL, top_left.x, top_left.y + cornerRadius);

    // add top left curve
    CGPathAddQuadCurveToPoint(path, NULL, top_left.x, top_left.y, top_left.x + cornerRadius, top_left.y);

    return path;
}
