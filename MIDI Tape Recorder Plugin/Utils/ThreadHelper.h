//
//  ThreadHelper.h
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 01/06/22.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import <Foundation/Foundation.h>

void dispatchOnMainThreadIfNecessary(dispatch_block_t block);
