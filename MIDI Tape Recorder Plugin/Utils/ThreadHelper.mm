//
//  ThreadHelper.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 01/06/22.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "ThreadHelper.h"

void dispatchOnMainThreadIfNecessary(dispatch_block_t block)
{
    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}
