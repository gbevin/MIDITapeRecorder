//
//  RecorderUndoManager.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 12/17/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "RecorderUndoManager.h"

@implementation RecorderUndoManager {
    BOOL _needsGroup;
    BOOL _groupStarted;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _needsGroup = NO;
        _groupStarted = NO;
    }
    return self;
}

- (void)withUndoGroup:(void (^)())block {
    if (_needsGroup) {
        @throw [NSException exceptionWithName:@"Unsupported Group Nesting" reason:nil userInfo:nil];
    }
    
    _needsGroup = YES;
    _groupStarted = NO;

    if (block) {
        block();
    }
    
    if (_groupStarted) {
        [super endUndoGrouping];
    }
    
    _needsGroup = NO;
}

- (id)prepareWithInvocationTarget:(id)target {
    if (_needsGroup && !_groupStarted) {
        _needsGroup = NO;
        _groupStarted = YES;
        [super beginUndoGrouping];
    }
    
    return [super prepareWithInvocationTarget:target];
}

@end
