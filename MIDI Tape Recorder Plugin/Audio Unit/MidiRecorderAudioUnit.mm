//
//  MidiRecorderAudioUnit.mm
//  MIDI Tape Recorder Plugin
//
//  Created by Geert Bevin on 11/27/21.
//  MIDI Tape Recorder ©2021 by Geert Bevin is licensed under CC BY 4.0
//

#import "MidiRecorderAudioUnit.h"

#include <mach/mach_time.h>

#import <AVFoundation/AVFoundation.h>

#include "Constants.h"

#import "AudioUnitViewController.h"

@interface MidiRecorderAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree* parameterTree;
@property AUAudioUnitBusArray* inputBusArray;
@property AUAudioUnitBusArray* outputBusArray;

@end


@implementation MidiRecorderAudioUnit {
    AudioUnitViewController* _vc;
    AUAudioUnitPreset* _currentPreset;
}

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError**)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
    
    _kernelAdapter = [[DSPKernelAdapter alloc] init];
    
    [self setupAudioBuses];
    [self setupParameterTree];
    
    _vc = nil;
    
    return self;
}

- (void)setVC:(AudioUnitViewController*)vc {
    _vc = vc;
}

#pragma mark - AUAudioUnit Setup

- (void)setupAudioBuses {
    // Create the input and output bus arrays.
    _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeInput
                                                              busses: @[_kernelAdapter.inputBus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_kernelAdapter.outputBus]];
}

- (void)setupParameterTree {
    // Create parameter objects.
    AUParameter* playParam = [AUParameterTree createParameterWithIdentifier:@"play"
                                                                       name:@"Play"
                                                                    address:ID_PLAY
                                                                        min:0
                                                                        max:1
                                                                       unit:kAudioUnitParameterUnit_Boolean
                                                                   unitName:nil
                                                                      flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                               valueStrings:nil
                                                        dependentParameters:nil];
    
    AUParameter* recordParam = [AUParameterTree createParameterWithIdentifier:@"record"
                                                                         name:@"Record"
                                                                      address:ID_RECORD
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter* repeatParam = [AUParameterTree createParameterWithIdentifier:@"repeat"
                                                                         name:@"Repeat"
                                                                      address:ID_REPEAT
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter* rewindParam = [AUParameterTree createParameterWithIdentifier:@"rewind"
                                                                         name:@"Rewind"
                                                                      address:ID_REWIND
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter* gridParam = [AUParameterTree createParameterWithIdentifier:@"grid"
                                                                       name:@"Grid"
                                                                    address:ID_GRID
                                                                        min:0
                                                                        max:1
                                                                       unit:kAudioUnitParameterUnit_Boolean
                                                                   unitName:nil
                                                                      flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                               valueStrings:nil
                                                        dependentParameters:nil];
    
    AUParameter* chaseParam = [AUParameterTree createParameterWithIdentifier:@"chase"
                                                                        name:@"Chase"
                                                                     address:ID_CHASE
                                                                         min:0
                                                                         max:1
                                                                        unit:kAudioUnitParameterUnit_Boolean
                                                                    unitName:nil
                                                                       flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    AUParameter* punchInOutParam = [AUParameterTree createParameterWithIdentifier:@"punchInOut"
                                                                             name:@"Punch In/Out"
                                                                          address:ID_PUNCH_INOUT
                                                                              min:0
                                                                              max:1
                                                                             unit:kAudioUnitParameterUnit_Boolean
                                                                         unitName:nil
                                                                            flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                     valueStrings:nil
                                                              dependentParameters:nil];
    
    AUParameter* record1Param = [AUParameterTree createParameterWithIdentifier:@"record1"
                                                                          name:@"Rec 1"
                                                                       address:ID_RECORD_1
                                                                           min:0
                                                                           max:1
                                                                          unit:kAudioUnitParameterUnit_Boolean
                                                                      unitName:nil
                                                                         flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                  valueStrings:nil
                                                           dependentParameters:nil];
    
    AUParameter* record2Param = [AUParameterTree createParameterWithIdentifier:@"record2"
                                                                          name:@"Rec 2"
                                                                       address:ID_RECORD_2
                                                                           min:0
                                                                           max:1
                                                                          unit:kAudioUnitParameterUnit_Boolean
                                                                      unitName:nil
                                                                         flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                  valueStrings:nil
                                                           dependentParameters:nil];
    
    AUParameter* record3Param = [AUParameterTree createParameterWithIdentifier:@"record3"
                                                                          name:@"Rec 3"
                                                                       address:ID_RECORD_3
                                                                           min:0
                                                                           max:1
                                                                          unit:kAudioUnitParameterUnit_Boolean
                                                                      unitName:nil
                                                                         flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                  valueStrings:nil
                                                           dependentParameters:nil];
    
    AUParameter* record4Param = [AUParameterTree createParameterWithIdentifier:@"record4"
                                                                          name:@"Rec 4"
                                                                       address:ID_RECORD_4
                                                                           min:0
                                                                           max:1
                                                                          unit:kAudioUnitParameterUnit_Boolean
                                                                      unitName:nil
                                                                         flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                  valueStrings:nil
                                                           dependentParameters:nil];
    
    AUParameter* monitor1Param = [AUParameterTree createParameterWithIdentifier:@"monitor1"
                                                                           name:@"Mon 1"
                                                                        address:ID_MONITOR_1
                                                                            min:0
                                                                            max:1
                                                                           unit:kAudioUnitParameterUnit_Boolean
                                                                       unitName:nil
                                                                          flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                   valueStrings:nil
                                                            dependentParameters:nil];
    
    AUParameter* monitor2Param = [AUParameterTree createParameterWithIdentifier:@"monitor2"
                                                                           name:@"Mon 2"
                                                                        address:ID_MONITOR_2
                                                                            min:0
                                                                            max:1
                                                                           unit:kAudioUnitParameterUnit_Boolean
                                                                       unitName:nil
                                                                          flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                   valueStrings:nil
                                                            dependentParameters:nil];
    
    AUParameter* monitor3Param = [AUParameterTree createParameterWithIdentifier:@"monitor3"
                                                                           name:@"Mon 3"
                                                                        address:ID_MONITOR_3
                                                                            min:0
                                                                            max:1
                                                                           unit:kAudioUnitParameterUnit_Boolean
                                                                       unitName:nil
                                                                          flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                   valueStrings:nil
                                                            dependentParameters:nil];
    
    AUParameter* monitor4Param = [AUParameterTree createParameterWithIdentifier:@"monitor4"
                                                                           name:@"Mon 4"
                                                                        address:ID_MONITOR_4
                                                                            min:0
                                                                            max:1
                                                                           unit:kAudioUnitParameterUnit_Boolean
                                                                       unitName:nil
                                                                          flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                   valueStrings:nil
                                                            dependentParameters:nil];
    
    AUParameter* mute1Param = [AUParameterTree createParameterWithIdentifier:@"mute1"
                                                                        name:@"Mute 1"
                                                                     address:ID_MUTE_1
                                                                         min:0
                                                                         max:1
                                                                        unit:kAudioUnitParameterUnit_Boolean
                                                                    unitName:nil
                                                                       flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    AUParameter* mute2Param = [AUParameterTree createParameterWithIdentifier:@"mute2"
                                                                        name:@"Mute 2"
                                                                     address:ID_MUTE_2
                                                                         min:0
                                                                         max:1
                                                                        unit:kAudioUnitParameterUnit_Boolean
                                                                    unitName:nil
                                                                       flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    AUParameter* mute3Param = [AUParameterTree createParameterWithIdentifier:@"mute3"
                                                                        name:@"Mute 3"
                                                                     address:ID_MUTE_3
                                                                         min:0
                                                                         max:1
                                                                        unit:kAudioUnitParameterUnit_Boolean
                                                                    unitName:nil
                                                                       flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    AUParameter* mute4Param = [AUParameterTree createParameterWithIdentifier:@"mute4"
                                                                        name:@"Mute 4"
                                                                     address:ID_MUTE_4
                                                                         min:0
                                                                         max:1
                                                                        unit:kAudioUnitParameterUnit_Boolean
                                                                    unitName:nil
                                                                       flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    
    AUParameter* clearAllParam = [AUParameterTree createParameterWithIdentifier:@"clearAll"
                                                                           name:@"Clear All"
                                                                        address:ID_CLEAR_ALL
                                                                            min:0
                                                                            max:1
                                                                           unit:kAudioUnitParameterUnit_Boolean
                                                                       unitName:nil
                                                                          flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                   valueStrings:nil
                                                            dependentParameters:nil];
    
    AUParameter* clear1Param = [AUParameterTree createParameterWithIdentifier:@"clear1"
                                                                         name:@"Clear 1"
                                                                      address:ID_CLEAR_1
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter* clear2Param = [AUParameterTree createParameterWithIdentifier:@"clear2"
                                                                         name:@"Clear 2"
                                                                      address:ID_CLEAR_2
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter* clear3Param = [AUParameterTree createParameterWithIdentifier:@"clear3"
                                                                         name:@"Clear 3"
                                                                      address:ID_CLEAR_3
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter* clear4Param = [AUParameterTree createParameterWithIdentifier:@"clear4"
                                                                         name:@"Clear 4"
                                                                      address:ID_CLEAR_4
                                                                          min:0
                                                                          max:1
                                                                         unit:kAudioUnitParameterUnit_Boolean
                                                                     unitName:nil
                                                                        flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                 valueStrings:nil
                                                          dependentParameters:nil];

    // Initialize the parameter values.
    playParam.value = 0.0;
    recordParam.value = 0.0;
    repeatParam.value = 0.0;
    rewindParam.value = 0.0;
    gridParam.value = 0.0;
    chaseParam.value = 1.0;
    punchInOutParam.value = 0.0;
    record1Param.value = 0.0;
    record2Param.value = 0.0;
    record3Param.value = 0.0;
    record4Param.value = 0.0;
    monitor1Param.value = 0.0;
    monitor2Param.value = 0.0;
    monitor3Param.value = 0.0;
    monitor4Param.value = 0.0;
    mute1Param.value = 0.0;
    mute2Param.value = 0.0;
    mute3Param.value = 0.0;
    mute4Param.value = 0.0;
    clearAllParam.value = 0.0;
    clear1Param.value = 0.0;
    clear2Param.value = 0.0;
    clear3Param.value = 0.0;
    clear4Param.value = 0.0;

    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[
        playParam,
        recordParam,
        repeatParam,
        rewindParam,
        gridParam,
        chaseParam,
        punchInOutParam,
        record1Param,
        record2Param,
        record3Param,
        record4Param,
        monitor1Param,
        monitor2Param,
        monitor3Param,
        monitor4Param,
        mute1Param,
        mute2Param,
        mute3Param,
        mute4Param,
        clearAllParam,
        clear1Param,
        clear2Param,
        clear3Param,
        clear4Param
    ]];
}

- (void)setupParameterCallbacks:(AUParameterObserverToken)token {
    // Make a local pointer to the kernel to avoid capturing self.
    __block DSPKernelAdapter* kernelAdapter = _kernelAdapter;
    
    // implementorValueObserver is called when a parameter changes value.
    _parameterTree.implementorValueObserver = ^(AUParameter* param, AUValue value) {
        [kernelAdapter setParameter:param value:value];
    };
    
    // implementorValueProvider is called when the value needs to be refreshed.
    _parameterTree.implementorValueProvider = ^(AUParameter* param) {
        return [kernelAdapter valueForParameter:param];
    };
    
    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter* param, const AUValue* __nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        switch ((int)value) {
            case 0: return @"OFF";
            case 1: return @"ON";
        }
        return [NSString stringWithFormat:@"%d", (int)value];
    };
    
    __block AUParameterTree* param_tree = _parameterTree;
    kernelAdapter.state->hostParamChange = ^(uint64_t address, float value) {
        AUParameter* param = [param_tree parameterWithAddress:address];
        if (param) {
            [param setValue:value originator:token atHostTime:mach_absolute_time() eventType:AUParameterAutomationEventTypeValue];
        }
    };
}

#pragma mark - AUAudioUnit Overrides

- (BOOL)supportsUserPresets {
    return YES;
}

- (AUAudioUnitPreset*)currentPreset {
    return _currentPreset;
}

- (void)setCurrentPreset:(AUAudioUnitPreset*)currentPreset {
    if (nil == currentPreset) { return; }

    if (currentPreset.number >= 0) {
        // no factory presets
    }
    else {
        if (@available(iOS 13.0, *)) {
            NSError* error = nil;
            NSDictionary<NSString*, id>* document = [self presetStateFor:currentPreset error:&error];
            if (error) {
                NSLog(@"Error retrieving preset state for %@ : %@", currentPreset, error);
            }
            if (document) {
                [self setFullStateForDocument:document];
            }
        }
        else {
            // user presets are not available prior to iOS 13
        }
        _currentPreset = currentPreset;
    }
}

- (AUAudioFrameCount)maximumFramesToRender {
    return _kernelAdapter.maximumFramesToRender;
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {
    _kernelAdapter.maximumFramesToRender = maximumFramesToRender;
}

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray*)inputBusses {
    return _inputBusArray;
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray*)outputBusses {
    return _outputBusArray;
}

- (void)setMIDIOutputEventBlock:(AUMIDIOutputEventBlock)MIDIOutputEventBlock {
    _kernelAdapter.ioState->midiOutputEventBlock = MIDIOutputEventBlock;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError**)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }

    // Validate that the bus formats are compatible.
    if (!(_kernelAdapter.outputBus.format.channelCount == 2 && _kernelAdapter.inputBus.format.channelCount == 2)) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        // Notify superclass that initialization was not successful
        self.renderResourcesAllocated = NO;
        
        return NO;
    }
    
    [super allocateRenderResourcesAndReturnError:outError];
    [_kernelAdapter allocateRenderResources];
    
    _kernelAdapter.ioState->transportStateBlock = self.transportStateBlock;
    _kernelAdapter.ioState->musicalContext = self.musicalContextBlock;
    
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    [_kernelAdapter deallocateRenderResources];
    
    // Deallocate your resources.
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    return _kernelAdapter.internalRenderBlock;
}

- (NSInteger)virtualMIDICableCount {
    return 4;
}

- (NSArray<NSString*>*)MIDIOutputNames {
    return @[@"MIDI Out 1", @"MIDI Out 2", @"MIDI Out 3", @"MIDI Out 4"];
}

- (BOOL)supportsMPE {
    return YES;
}

- (NSArray<NSNumber*>*)channelCapabilities {
    return @[@2,@2];
}

- (BOOL)isMusicDeviceOrEffect {
    return YES;
}

#pragma mark - AUAudioUnit fullState
- (void)setFullState:(NSDictionary<NSString *,id>*)fullState {
    @try {
        [super setFullState:fullState];
    }
    @catch (id e) {
        NSLog(@"Exception while applying full state: %@", e);
        return;
    }
    
    if (_vc == nil) {
        return;
    }

    [_vc readFullStateFromDict:fullState];
}

- (NSDictionary<NSString *,id>*)fullState {
    if (_vc == nil) {
        return [super fullState];
    }

    NSMutableDictionary* state = [NSMutableDictionary new];
    [_vc currentFullStateToDict:state];
    [state addEntriesFromDictionary:[super fullState]];
    return state;
}

@end

