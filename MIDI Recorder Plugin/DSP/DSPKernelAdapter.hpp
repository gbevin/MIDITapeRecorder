//
//  DSPKernelAdapter.hpp
//  MIDI Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//

#import <AudioToolbox/AudioToolbox.h>

#import "AudioUnitGUIState.hpp"
#import "AudioUnitIOState.hpp"

@interface DSPKernelAdapter : NSObject

@property(nonatomic) AUAudioFrameCount maximumFramesToRender;
@property(nonatomic, readonly) AUAudioUnitBus* inputBus;
@property(nonatomic, readonly) AUAudioUnitBus* outputBus;

- (AudioUnitGUIState*)guiState;
- (AudioUnitIOState*)ioState;

- (void)rewind;
- (void)play;
- (void)stop;

- (void)setParameter:(AUParameter*)parameter value:(AUValue)value;
- (AUValue)valueForParameter:(AUParameter*)parameter;

- (void)allocateRenderResources;
- (void)deallocateRenderResources;
- (AUInternalRenderBlock)internalRenderBlock;

@end
